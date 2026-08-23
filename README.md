# rawsberry

A portable edge appliance that turns a camera SD card into finished JPEGs with zero manual editing. Insert card, select photos from a phone, walk away.

The goal is not to make editing faster. It is to remove the step.

## Status

Design phase complete. **No pipeline code written yet.**

The Pi 5 is provisioned and the end-to-end render path has been verified on-device — RawTherapee reads a CR2 and writes a JPEG on target hardware, with and without a profile. That is a readiness check, not a measurement; nothing yet moves the four numbers below. Phase 1, the verdict → mapper → `.pp3` loop, is the next work and has not started.

One pilot has been run outside the target architecture (a vision model emitting RawTherapee profiles directly). On three photographs the camera's own JPEG was preferred on two of them. That result is why the architecture below exists in the form it does, and it is recorded here rather than omitted.

## Architecture

```
SD reader → phone web UI → SettingsPicker → deterministic mapper → RawTherapee → JPEG → feedback log
```

Two ideas carry the design.

### Verdicts, not numbers

The model never emits parameter values. It emits a small closed vocabulary of categorical judgments about the scene. Deterministic code measures the actual RAW and computes the magnitudes.

```
setting = f(measured current state, target selected by verdict)
```

Two photographs receiving the same verdict get different numbers because they start in different places.

The reason is failure attribution. Vision models judge scenes well and calibrate quantities badly — they return plausible-sounding values, not measured ones, and they see a downscaled preview while the code has the full RAW. Splitting the two makes every failure diagnosable: wrong verdict is a prompt problem, wrong number is a mapper bug. With raw numbers from the model, bad output is undiagnosable.

### Camera-agnostic invariant

The model decides *intent*. Deterministic code measures *physics*.

Physical calibration is required — black and white levels, colour matrices, Bayer layout, baseline exposure offset. These normalise different sensors into one common representation, and omitting them makes camera identity *more* visible, not less.

Aesthetic rendering is excluded — manufacturer tone curves, look tables, hue/saturation maps, Picture Styles. These are the fingerprint.

```
RAW → sensor calibration → standardized representation → identical treatment → model
```

Camera identity is never a model input. The model is fed a standardized render, never the camera's embedded JPEG preview — a model trained on embedded previews partly learns to recognise JPEG engines.

## SettingsPicker

One interface: standardized preview plus an allowlist of features in, categorical verdicts out. Three implementations with a dependency ordering, not free alternatives.

| | Decides | Notes |
|---|---|---|
| **V1** | Heuristic decision tree | EXIF and histogram statistics. Zero cost, offline, always available. Ships as the validation-failure fallback. |
| **V2** | General vision-language model | Hosted or local — a config value, not an architectural difference. Schema-validated; invalid output falls back to V1. |
| **V3** | Trained classifier | Small frozen backbone plus a linear head on cached embeddings. Cannot exist until V2 has logged data. |

Nothing downstream knows which implementation produced the verdicts.

## Renderer

RawTherapee CLI owns demosaicing, camera colour handling, tone and colour processing, lens correction, denoising, sharpening and JPEG export. `darktable-cli` is the fallback.

These algorithms are not reimplemented. A from-scratch tone/colour/denoise stack would lose blind comparisons regardless of how good the verdicts were. RawTherapee's `.pp3` profiles are plain INI text, which the mapper writes directly.

## Reference hardware

- Raspberry Pi 5, 4GB
- USB SD card reader
- A2 microSD for working storage
- Power bank, case with active cooling
- No screen, no keyboard — the phone is the entire UI, over a browser

No accelerator. Local semantic inference ranks below power-bank operation, and the two pull against each other.

## Pi setup

### Before first boot — Raspberry Pi Imager

Raspberry Pi Imager's "Would you like to apply OS customisation settings?" dialog **defaults to No**. Clicking through it silently discards hostname, user account, SSH enable and Wi-Fi credentials, producing a Pi that boots normally and is completely unreachable. The failure presents as a network problem, which makes it slow to diagnose.

Apply customisation and set: hostname, user account, SSH enable, Wi-Fi credentials. These are pre-boot settings and cannot be scripted.

To confirm it worked, mount the boot partition and look for `custom.toml`. If it is absent, nothing was applied.

Recovery without re-flashing, on the boot partition:

- `touch ssh` — enables the SSH server
- `userconf.txt` containing `user:<hash from openssl passwd -6>` — creates the account

### Provisioning

Everything after first boot is scripted. On the Pi:

```bash
./setup.sh
```

Sets Wi-Fi regulatory domain, timezone and locale, installs `git`, `tmux` and `curl`, then installs the pinned RawTherapee build described below. Re-running is safe: the renderer step is skipped once installed, and every other step rewrites the same values.

Locale is set to `C.UTF-8` in `/etc/default/locale` deliberately: a locale using decimal commas would corrupt float values written into `.pp3` files, and `/etc/default/locale` is inherited by systemd units and non-interactive processes, which `profile.d` would not cover.

### Renderer pin

Both machines run **RawTherapee 5.13**, installed from the official upstream **Linux** AppImage rather than from apt. 5.13 is the first release with an official arm64 Linux build, so the Linux desktop and the Pi can run the same upstream binary; `apt install rawtherapee` gave 5.10 on the desktop and 5.11 on the Pi and would have kept drifting.

This matters because determinism is specified against a *pinned renderer build*. Two versions means the eval harness measures a proxy, and numbers taken on one build are not comparable with numbers taken on the other.

Both assets below are Linux-only builds, from `https://github.com/RawTherapee/RawTherapee/releases/tag/5.13`:

| Target | Asset | sha256 |
| --- | --- | --- |
| Pi, Linux arm64 | `RawTherapee_5.13_arm64_release.AppImage` | `9e424633272a49bb47afe4bf065604858acf9de77c4d80e0f6557024492e2b55` |
| Desktop, Linux x86_64 | `RawTherapee_5.13_x86_64_release.AppImage` | `746a3509a234804c3a5f66649006ac29ac67f193a8559d2297357949a890b097` |

`setup.sh` fetches the arm64 asset and verifies it against the hash above before installing, aborting if they differ. The desktop side is currently installed by hand from the same release.

A release asset can be rebuilt and re-uploaded under the same tag, so a working URL does not imply the pinned bytes — that is what the checksum catches. If it ever fails, compare the reported hash against the checksum published on the release page. If they differ, the download was corrupt; re-run. If they match, upstream replaced the asset: do not simply update the constant, because different bytes mean a different renderer, and `neutral.pp3` must be regenerated with every prior eval number treated as no longer comparable.

AppImages are extracted with `--appimage-extract` rather than run through FUSE, since Pi OS Lite ships no `libfuse2`.

### GitHub access

The Pi pulls from GitHub using a **repo-scoped deploy key**, not an account SSH key. A deploy key grants access to this repository only — if the Pi is lost or compromised, the blast radius is one repo, and it can be revoked from the repo's own settings page.

Generate on the Pi:

```bash
ssh-keygen -t ed25519 -C "raspberrypi"
cat ~/.ssh/id_ed25519.pub
```

Add at: repo → Settings → Deploy keys → Add deploy key. Leave "Allow write access" unchecked — the Pi only pulls.

Clone:

```bash
git clone git@github.com:jsepulvedaco/rawsberry.git
```

Deploy step is `git pull`. Development happens on the laptop; the Pi never pushes.

Note: a deploy key is valid for one repository only. A second repo needs its own key.

## Evaluation

The instrument that makes iteration possible. Without it, every change is "feels better, I think."

**Baseline is the camera's own JPEG.** Shoot RAW+JPEG; every output is compared against what the camera produced.

**Blind pairwise comparison**, random left/right order, no labels.

**Three sets, not one** — a development set to abuse while tuning, a sealed holdout touched only at milestones, and fresh field photos. One set used for every decision becomes an adaptive-holdout problem and stops meaning anything.

**Four numbers:**

| Metric | Measures |
|---|---|
| JPEG preference rate | Blind, against the camera's own output |
| Seconds per photo | End to end |
| Watt-hours per 100 photos | Whether it is genuinely power-bank friendly |
| Catastrophic-failure rate | How often an output is *ruined*, not merely worse |

The appliance should fail by being boring, never by being wrong.

## Measured

RawTherapee 5.10, 8 distinct 24MP CR2 files, max-quality profile (AMaZE, directional pyramid denoising, capture sharpening, CA correction).

| Configuration | s/photo | Peak memory |
|---|---|---|
| 1 process × 4 threads | 6.72 | 2.09 GB |
| 2 processes × 2 threads | 5.49 | 3.58 GB |

**These are desktop numbers, not Pi numbers.** They rank configurations; they do not predict the board. 2×2 does not fit in 4GB alongside the OS and web UI. Thread count does not change output bytes, which is what keeps evaluation runs reproducible.

## Build phases

1. **Phase 1** — verdicts → mapper → generated `.pp3` → RawTherapee → JPEG, on the desktop. *In progress.*
2. **Phase 2** — FastAPI, gallery, async job queue.
3. **Phase 3** — deploy to the Pi. Benchmark latency, concurrency, power, thermals.
4. **Phase 4** — V2 picker: API call, schema validation, fallback, accept/reject logging.
5. **Phase 5** — V3: train the classifier on logged data, evaluate against V2.
6. **Phase 6** — exposure bracketing and fusion.
7. **Phase 7** — semantic local adjustment. Speculative, unbuilt.

Explicitly out of scope: cropping, astrophotography, arbitrary masking.

## Requirements

- RawTherapee 5.10+ (`rawtherapee-cli`)
- Python 3.11+
- `exiftool`

## License

MIT. See [LICENSE](LICENSE).

RawTherapee is invoked as a subprocess, which is not linking, so its license places no constraint on this repository.
