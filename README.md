# Rawsberry

A portable edge appliance that turns a camera SD card into finished JPEGs with zero manual editing. Insert card, select photos from a phone, walk away.

The goal is not to make editing faster. It is to remove the step.

## Status

Architecture fixed; several design decisions still open (listed in `CLAUDE.md`). **No pipeline code exists yet.** Nothing in this repository runs a photo through the pipeline.

What exists:

- A provisioned Raspberry Pi 5 on which RawTherapee reads a CR2 and writes a JPEG. That is a readiness check, not a measurement.
- `neutral.pp3`, the standardized preview profile.
- `setup.sh`, which provisions the Pi.

The kill criterion — blind preference over the camera's own JPEG — has zero clean data points. No valid comparison has been run.

The only camera anything has been checked against is a Canon EOS 2000D shooting CR2. The design is camera-model agnostic; the reality so far is one body.

## What's in the repo

| Path | What |
|---|---|
| `neutral.pp3` | Standardized preview profile. A complete RawTherapee 5.13 profile dump, 512px long edge. Regenerate from the renderer, never edit by hand. |
| `setup.sh` | Provisions a fresh Pi: locale, timezone, Wi-Fi domain, pinned RawTherapee. |
| `raws/` | Input RAW files. Gitignored; you supply them. Never written to. |
| `out/` | Rendered JPEGs. Gitignored. |
| `CLAUDE.md` | Project rules and constraints for the coding agent. |
| `AGENTS.md` | Pointer to `CLAUDE.md` for agents that read that filename instead. |
| `.claude/skills/` | Agent skills specific to this project. |
| `LICENSE` | MIT. |

## Architecture

```
SD card → phone web UI → SettingsPicker → deterministic mapper → .pp3 → rawtherapee-cli → JPEG → feedback log
```

Two ideas carry the design.

### Verdicts, not numbers

The model never emits parameter values. It emits a closed vocabulary of categorical judgments about the scene, and deterministic code measures the actual RAW and computes the magnitudes:

```
setting = f(measured current state, target selected by verdict)
```

Two photographs receiving the same verdict get different numbers because they start in different places.

The targets each verdict selects are constants, calibrated offline from preference — sweep values across a development set once, fit the inverse, ship a lookup. Phase 1 runs on guessed constants to get the loop working; calibration is separate, later work and the least-examined part of the design.

The vocabulary, in full:

| Dimension | Values |
|---|---|
| `brightness` | increase · keep · decrease |
| `shadows` | lift · keep · deepen |
| `highlights` | recover · keep |
| `white_balance` | neutralize · preserve_warm · preserve_cool |
| `contrast` | increase · keep · reduce |
| `detail_preservation` | preserve · balanced · smooth |
| `saturation` | vivid · natural · muted |
| `tone_profile` | neutral · punchy · soft |

The split makes every failure diagnosable: wrong verdict is a prompt problem, wrong number is a mapper bug. The premise the design bets on, unmeasured here: vision models judge scenes well and calibrate quantities badly.

### Camera-agnostic invariant

The model decides *intent*. Deterministic code measures *physics*.

Physical calibration — black and white levels, colour matrices, Bayer layout, baseline exposure offset — is required; it normalises different sensors into one representation. Aesthetic rendering — manufacturer tone curves, look tables, hue/saturation maps, Picture Styles — is excluded; it is the fingerprint.

```
RAW → sensor calibration → standardized representation → identical treatment → model
```

Camera identity is never a model input. The model is fed a standardized render, never the camera's embedded JPEG preview.

## SettingsPicker

One interface: standardized preview plus an allowlist of features in, verdicts out. Three implementations with a dependency ordering.

| | Decides | Notes |
|---|---|---|
| **V1** | Heuristic decision tree | EXIF and histogram statistics. Zero cost, offline, always available. The fallback when anything else fails validation. |
| **V2** | General vision-language model | Hosted or local — a config value, not an architectural difference. Schema-validated; invalid output falls back to V1. |
| **V3** | Trained classifier | Small frozen backbone plus a linear head on cached embeddings. Cannot exist until V2 has logged data. |

Nothing downstream knows which implementation answered.

## Renderer

RawTherapee CLI owns demosaicing, camera colour handling, tone and colour processing, lens correction, denoising, sharpening and JPEG export. `darktable-cli` is the fallback. None of this is reimplemented; the control layer is the deliverable. RawTherapee's `.pp3` profiles are INI text, which the mapper writes directly.

### Renderer pin

Both machines run **RawTherapee 5.13** from the official upstream Linux AppImages, not from a distro package. 5.13 is the first release with an official arm64 build, so desktop and Pi run the same release — built per architecture, so not the same binary; whether the two drift outside the determinism tolerance is unmeasured. Determinism is specified against this pinned release; numbers taken on two different releases are not comparable, and changing the pin means regenerating `neutral.pp3` and discarding prior eval numbers.

Assets from `https://github.com/RawTherapee/RawTherapee/releases/tag/5.13`:

| Target | Asset | sha256 |
| --- | --- | --- |
| Pi, Linux arm64 | `RawTherapee_5.13_arm64_release.AppImage` | `9e424633272a49bb47afe4bf065604858acf9de77c4d80e0f6557024492e2b55` |
| Desktop, Linux x86_64 | `RawTherapee_5.13_x86_64_release.AppImage` | `746a3509a234804c3a5f66649006ac29ac67f193a8559d2297357949a890b097` |

`setup.sh` verifies the arm64 asset against its hash and aborts on mismatch — a working URL does not imply the pinned bytes. The desktop is installed by hand from the same release. AppImages are extracted with `--appimage-extract` because Pi OS Lite ships no `libfuse2`.

## Reference hardware

- Raspberry Pi 5, 4GB
- USB SD card reader
- A2 microSD for working storage
- Power bank, case with active cooling
- No screen, no keyboard — the phone is the entire UI, over a browser

No accelerator. Local inference ranks below power-bank operation, and the two pull against each other.

## Pi setup

Flash Raspberry Pi OS Lite (64-bit) with hostname, user, SSH and Wi-Fi set in the Imager's customisation dialog — those are pre-boot settings and cannot be scripted. Then, on the Pi:

```bash
./setup.sh
```

Safe to re-run. Locale is forced to `C.UTF-8` in `/etc/default/locale`: a decimal-comma locale would corrupt float values written into `.pp3` files, and that file is inherited by systemd units where `profile.d` is not.

The Pi pulls this repo with a read-only deploy key. Development happens on the desktop; the Pi never pushes.

## Evaluation

**Baseline is the camera's own JPEG.** Shoot RAW+JPEG; every output is compared blind, pairwise, random left/right, no labels, against what the camera produced.

**Three sets** — a development set to abuse while tuning, a sealed holdout touched only at milestones, and fresh field photos.

**Four numbers:**

| Metric | Measures |
|---|---|
| JPEG preference rate | Blind, against the camera's own output |
| Seconds per photo | End to end |
| Watt-hours per 100 photos | Whether it is genuinely power-bank friendly |
| Catastrophic-failure rate | How often an output is *ruined*, not merely worse |

The appliance should fail by being boring, never by being wrong.

## Build phases

1. **Phase 1** — verdicts → mapper → generated `.pp3` → RawTherapee → JPEG, on the desktop. *Next; not started.*
2. **Phase 2** — FastAPI, gallery, async job queue.
3. **Phase 3** — deploy to the Pi. Benchmark latency, concurrency, power, thermals.
4. **Phase 4** — V2 picker: API call, schema validation, fallback, accept/reject logging.
5. **Phase 5** — V3: train the classifier on logged data, evaluate against V2.
6. **Phase 6** — exposure bracketing and fusion.
7. **Phase 7** — semantic local adjustment. Speculative, unbuilt.

Out of scope, permanently: cropping, astrophotography, arbitrary external raster masks, true semantic masking in `.pp3`. RawTherapee cannot take an external mask, and its own colour-range selection is judged too unreliable to run unattended (unmeasured). Phase 7 semantic local adjustment, if it happens, is designed to run outside the renderer: segmentation on the preview, compositing of RawTherapee's output downstream.

## Requirements

- RawTherapee 5.13 (`rawtherapee-cli`), pinned as above
- Python 3.11+, for the pipeline once it exists

## License

MIT. See [LICENSE](LICENSE).

RawTherapee is invoked as a subprocess, which is not linking, so its license places no constraint on this repository.
