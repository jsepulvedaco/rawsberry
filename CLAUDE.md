# CLAUDE.md

## Git

- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:
  `<type>[optional scope]: <description>`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`, `style`.
- Description in imperative mood, lowercase, no trailing period.

---

# Working context

What is being built, as opposed to the constraints below on what may not be.

## Pipeline

```
SD card → phone web UI → SettingsPicker → deterministic mapper → .pp3 → rawtherapee-cli → JPEG → feedback log
```

`SettingsPicker` is one interface — standardized preview + allowlisted features in, the frozen 8
verdicts out. V1 (heuristic tree), V2 (VLM, hosted or local), V3 (trained classifier) are
implementations of it, not layers. Nothing downstream knows which one answered.

## Stack

- **Backend:** FastAPI + async job queue. A 30-photo selection cannot be request-response.
- **Frontend:** React, phone-first, browser only. No app, no pairing, no Bluetooth.
- **Pipeline:** Python orchestration. `rawpy` for RAW statistics and measurement **only** —
  never for the production render. `configparser` for `.pp3`. OpenCV is Phase 6 only.
- **State:** filesystem. No database.

## Phase

**Phase 1, not started.** Design is done; there are zero lines of pipeline code. The next action is
the bootstrap loop — V1 verdicts → mapper → generated `.pp3` → `rawtherapee-cli` → JPEG, with
**guessed** constants. Calibration is separate work and is not in the build order.

Gating it: confirm what `InputProfile` RawTherapee actually resolves, then the `ai-pp3` smoke test.
*(RawTherapee's licence version is not a gate — subprocess invocation is not linking. `ai-pp3` is
GPL-2.0 and is read, never copied.)*

One pilot ran Aug 12–13 2026 outside this architecture and lost to the camera JPEG on two of three
photographs. That result is why the architecture has its current shape.

## Verdict schema

The contract. Do not invent values outside these vocabularies.

```json
{
  "brightness":          "increase | keep | decrease",
  "shadows":             "lift | keep | deepen",
  "highlights":          "recover | keep",
  "white_balance":       "neutralize | preserve_warm | preserve_cool",
  "contrast":            "increase | keep | reduce",
  "detail_preservation": "preserve | balanced | smooth",
  "saturation":          "vivid | natural | muted",
  "tone_profile":        "neutral | punchy | soft"
}
```

## Validation and degradation

- **Clamp every mapped value to a safe range.** Model says +3.0 EV → cap at ±1.5.
- **Malformed or missing fields → retry, then fall back to V1.** Never propagate a bad parse.
- **The system never fails to produce a JPEG.** It produces a dumber one. This is priority #4
  made executable.

## Originals are read-only

`raws/` is input. Never write, move, rename or re-encode anything in it. Output goes to `out/`.

## `neutral.pp3` is a reproducibility anchor

The standardized preview profile must be a versioned file in this repo, not a description. Eval
runs are only comparable if every preview was generated identically.

**Unclosed defects:**

- `ApplyLookTable`, `ApplyHueSatMap` and `HLRecovery` disagree between `neutral.pp3` and the render
  template — reconcile before the next pilot round.
- **`[Resize]` is absent**, so previews render full-resolution. "Fixed resize and normalization,
  identical for every camera" is specified but not implemented.
- **`ImageNum=1`** where RT's default is `0` and the field is zero-indexed. Unverified. Test:
  render with `ImageNum=0` and compare md5 — identical means harmless, different means every render
  from this template is suspect.

## V3 label strength (constrains the Phase 4 log schema, not just Phase 5)

An accept does not prove all eight verdicts were right. Accepted images give **weak pseudo-labels**;
only explicitly corrected dimensions give **strong labels**. Train with per-output masks so a
white-balance correction cannot promote seven unreviewed predictions to ground truth. Design the
log for this from day one.

---

# Project constraints

Distilled from the design note. Source of truth for *why* is the Notion page; this file is the
set of rules that constrain what gets built.

## Priorities, in order

1. **Better photos with zero editing.** Blind preference over the camera's own JPEG. Kill criterion.
2. **Portable and power-bank friendly.**
3. **Fast enough for field use.** Tens of seconds per photo, unattended batch.
4. **Reliable and boring.** Originals never touched. Fails by being dull, never by being wrong.
5. **Minimal workflow friction.** Card in → phone → select → process → JPEGs out. No sliders, no calibration rituals.
6. **Learns my taste over time.** V1 must already be useful without it.

## The four numbers

Every architectural decision must be answerable by one of these.

- **JPEG preference rate** — blind, against the camera's own output
- **Seconds per photo** — end to end
- **Watt-hours per 100 photos**
- **Catastrophic-failure rate** — output *ruined*, not merely worse

## The rejection rule

**An idea enters the build only if it moves one of the four numbers, and only after that number
has been measured.** Use the priorities to *reject* ideas, not to justify adding capabilities.

## Quality constraint

**Quality is absolute on the production render path** — any code path whose output becomes the
JPEG the user keeps (demosaic, denoise, tone, colour, sharpening, export). Chosen for quality
alone. Not traded against latency.

**Everywhere else quality is freely tradeable** — preview generation, model inference,
orchestration, storage, networking, UI.

Test: *does this output become the final JPEG?* Yes/no, not "is this within the margin?"

Two separate requirements:

- **Output quality, judged perceptually.** A path is legal if its output is equivalently good, not
  if it is bit-exact. Rejection standard is a visible structured difference — seams, banding, lost
  detail — not a hash mismatch.
- **Determinism, hard.** Same RAW + same profile + same configuration + pinned renderer build on a
  defined execution environment → same bytes. The eval harness, blind comparisons, V3's training
  previews and mapper regression tests all depend on it.

Consequence: an **always**-tiled path is legal. A path that tiles **only when allocation fails** is
illegal — output would vary with how much memory happened to be free.

Open: if the mapper is calibrated on the desktop and shipped on the Pi, those are two different
renderer builds and eval measures a proxy. Decide whether eval runs on the board *before*
calibration, not after.

## Camera-agnostic invariant

**AI decides intent. Deterministic code measures physics.**

- **Physical calibration is required** — black/white levels, colour matrices, Bayer layout,
  baseline exposure offset. These normalise sensors into one representation; omitting them makes
  camera identity *more* visible, not less.
- **Aesthetic rendering is excluded** — manufacturer tone curves, look tables, hue/saturation maps,
  Picture Styles. These are the fingerprint.

Rules:

- **Camera identity is never a model input.** An unknown camera must not be an unknown category,
  just different measured numbers.
- **The model is never fed the camera's embedded JPEG preview.** Embedded previews are for the
  phone gallery only.
- **EXIF goes to the model as an explicit allowlist, never raw EXIF.** No make, model, or lens.
  Start with physically-justifiable exposure values. ISO is suspect — noise is measured separately.
- **Applies to every processing decision, not just the learned model.** V1's heuristics count.
- Honest scope: *camera-model agnostic*, not *any camera*. The boundary is RawTherapee's format support.

## Verdict rules

The picker emits **only categorical verdicts**. Mapping functions produce every number.

```
setting = f(measured current state, target selected by verdict)
```

A categorical vocabulary does not imply a coarse output — the verdict selects a target, code
measures current, the setting is the gap.

A dimension earns a verdict only if **both** hold:

1. Deciding it requires understanding the scene.
2. The global renderer has an actuator that can express it. No actuator → forbidden.

Further:

- **One-axis rule.** All values within one verdict lie on a single ordered scale.
- **Test for actuator collision, not semantic similarity.** Correlated inputs are fine; shared
  actuators are the problem.
- Never judge noise from a preview. Noise amount is measured, never model-judged.
- Eval prunes any verdict that never changes outcomes. Add one only when a recurring failure has
  no existing control.

**Current vocabulary is the frozen 8** (`brightness`, `shadows`, `highlights`, `white_balance`,
`contrast`, `detail_preservation`, `saturation`, `tone_profile`). A reshape to intent-gates and
target-shaped values is **proposed and not adopted** — do not treat it as canon.

## Mapping layer

The riskiest component, and the one with the least attention. Bad mapping ruins output regardless
of verdict quality.

- **Must be calibratable offline.** Sweep values across the dev set once, fit the inverse, ship the
  lookup. **Per-image numerical search is disqualified** — extra render passes per photo kills
  priority #3.
- **Specify the luminance domain explicitly.** `log2(target/current)` is only valid in linear
  light. RT's rendered histograms are gamma-encoded.
- **No universal brightness target.** A night street sits low; snow sits high. Constants are
  measured from preference, not invented.
- Targets are constants to be calibrated, not guessed — but Phase 1 bootstraps with guesses to get
  the loop running.

## Renderer

- **RawTherapee CLI is the production renderer.** `darktable-cli` is the fallback. Field is closed
  to new entrants; reopen only on a measured RT failure.
- **Do not reimplement demosaic, tone, colour, or denoise.** The renderer is bought; the control
  layer is the deliverable.
- `.pp3` is an INI file — `configparser` with `optionxform = str`.
- **No fixed-function ISP on the production render.** PiSP is preview-path only, if at all.
- **`ai-pp3` is read, never imported.** GPL-2.0-only would foreclose permissive relicensing.
  Calling `rawtherapee-cli` via subprocess is not linking and constrains nothing.
- **Pin the renderer version.** Desktop and Pi must run the same RawTherapee build. Determinism is
  specified against a *pinned renderer build*; two versions means eval measures a proxy. Currently
  **5.10 desktop / 5.11 Pi — unresolved**, and `setup.sh` does a bare `apt install rawtherapee`,
  which will keep them drifting. `neutral.pp3` declares `AppVersion=5.10`; regenerate it from
  whichever version wins.

## Hardware and concurrency

- Reference: **Pi 5 4GB, no accelerator, hosted picker, V1 fallback.** The 8GB purchase question is
  **closed** — it buys 22–29%, minutes on a full card. Do not reopen without a new argument.
- Leading configuration: **1 process × 4 threads, `RgbDenoiseThreadLimit=0`.** Desktop-measured;
  the Pi decides.
- **Two operating modes, both producing byte-identical JPEGs.** Field (default, power-bank): 1×2,
  9.10 s/photo, conservative governor. Bench (mains): 1×4, 6.72 s/photo. **Justify the modes on
  peak current, not on speed** — the gap is ~1.3×, not the ~3× once claimed. If the Phase 3 power
  test shows no meaningful peak-draw difference, collapsing to one mode is the right call.
- **No hardcoded hardware configuration.** Per-process memory varies with megapixels and profile.
  Probe the first render, read actual peak RSS, size workers from the remaining budget.
- **Probe at the thread count the workers will actually use.** Denoise threads cost ~317MB each.
- **If swap moves off zero at all, the configuration failed.** Completing while thrashing an SD
  card is worse than useless.
- **Power mode is a manual toggle** (PMIC undervoltage as a safety net only) — a wrong auto-guess
  browns out the SD reader and presents as file corruption. **Memory is auto-sized** — statically
  readable and directly measurable.

## Eval harness

- **Three sets.** Development (abuse freely), sealed holdout (milestones only, never iteration),
  fresh field photos. Changing a set invalidates its prior scores.
- **Baseline is the camera's own JPEG.** Blind pairwise, random left/right, no labels.
- **Do not infer equivalence from a result near 50%.** Declare the margin in advance or report raw
  counts, sample size and interval.
- **Choose the test frame for the failure mode being tested,** and check what the file actually is
  before trusting a verdict.
- Catastrophic-failure rate needs a much larger sample than preference rate — a 1-in-50 disaster is
  invisible in a 30-photo test and fatal to an appliance nobody watches.

## Scope

**Out, permanently:** cropping, astrophotography, arbitrary external raster masks, true semantic
masking in `.pp3`.

**No Phase 7 work of any kind** until Phase 4 has shipped and real photos show failures global
processing cannot fix.

## Epistemic rules

The note's recurring failure mode is plausible reasoning stated as fact. These are corrections to
that.

- **Label measured vs guessed.** An estimate must never drift into being treated as data.
- **Off-board measurements are provisional.** The Pi decides the architecture.
- **A finding that only exists in a conversation is not a finding.** Write it down.
- **Do not convert plausible reasoning into a stated fact.** Retract explicitly when it happens.

## Open decisions — do not assume

- **White balance contract for the standardized preview.** As-shot feeds a camera interpretation to
  a camera-independent model; neutralising destroys the warmth signal the model exists to judge.
- **Verdict vocabulary reshape.** Proposed, not adopted.
- **Preview representation freeze.** V2's logs *are* V3's training set. Either freeze the preview
  before logging starts or store a stable RAW path + hash per label. Must be decided before Phase 4.
- **`ai-pp3` as Baseline A** in the Phase 4 blind comparison.
- **`ApplyHueSatMap` classification** — probably calibration, not aesthetic. Currently disabled on
  the aesthetic reading.
- **What "neutral" means — one question with four faces.** `InputProfile` is absent from
  `neutral.pp3`, so RT resolves a default (believed to be the camera-matched DCP; unverified, an
  `-O` dump settles it). Note that per-camera *calibration* applied deterministically is the
  invariant working, **not** violating it — a single fixed matrix across sensors makes camera
  identity more visible, per the Aug 13 correction. So the open question is not "remove the camera
  dependence" but "which parts of the DCP are calibration and which are aesthetic." That is the same
  question as `ApplyHueSatMap`, as `ApplyBaselineExposureOffset=true`, and as `Setting=Camera`. One
  coherent answer should settle all four. Not resolved as of Aug 21 2026.
