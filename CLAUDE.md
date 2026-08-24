# CLAUDE.md

## Backlog

Open work lives in the Notion Backlog database, not in prose pages or repo files.

- **Before starting a task, move its card to `In progress`.** If no card exists, create one.
- **When it is finished, move it to `Done`.** Check this at the end of every task.
- Keep one card per unit of work; do not track the same work in both Notion and the repo.

## Decision log

- **Summarize.** One dense paragraph: the decision, the mechanism, the consequence.
- No housekeeping — files deleted, commits made, sections moved, work performed.

## Repo files carry current state only

This file and the README describe the project as it is now, for a reader with no history. History
lives in git and the Decision Log.

- No dates, no retractions, no "replaces", "once claimed", "per the X correction", "closed by".
- Epistemic labels about *now* stay: measured, guessed, provisional, blocked, open.
- Test per sentence: if the reader never saw an earlier version of this file, does the sentence
  still carry information? If not, delete it.
- **CLAUDE.md constrains, README explains.** Where they overlap, CLAUDE.md is canonical and README
  follows. On conflict, fix README.
- Identical in content in both: the pipeline line, the verdict schema, the scope list. When either
  file changes, diff those three against the other before committing.

## End of a session

Before wrapping up a working session or discussion, ask whether anything needs adding to the
Backlog or the Decision Log.

Before editing a factual claim in README or CLAUDE.md, check it against the Backlog cards. Every
stale claim so far entered from memory of a conversation, not from the record.

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
- **Pipeline:** Python 3.11+ orchestration. `rawpy` for RAW statistics and measurement **only** —
  never for the production render. `configparser` for `.pp3`. OpenCV is Phase 6 only.
- **State:** filesystem. No database.
- **Renderer:** RawTherapee 5.13 AppImage extracted to `/opt/rawtherapee-5.13` on desktop and Pi
  alike; `rawtherapee-cli` is on `PATH`.
- **Development camera:** Canon EOS 2000D, CR2. The only body anything has been measured on.
  "This body" anywhere in this file means the 2000D.

## Phase

**Phase 1, not started.** The architecture is fixed; the items under *Open decisions* are not.
There are zero lines of pipeline code and nothing remains before code. The next action is the bootstrap loop — V1 verdicts → mapper → generated `.pp3` →
`rawtherapee-cli` → JPEG, with **guessed** constants. Calibration is separate work and is not in
the build order.

`ai-pp3` is an existing open-source tool that has a VLM emit `.pp3` values directly — the approach
this project rejects — and serves as a comparison baseline. Its smoke test belongs to Phase 4
preparation, run right before the blind harness. It is not a gate on anything earlier.

## How code gets written (Phases 1–2)

Jorge writes the code. This is a Python learning project for the duration of Phases 1 and 2 — the
goal is the appliance *and* the fluency, and trading the second away for speed is not a trade this
project accepts.

- **Claude does not write implementation modules.** No bulk-generated files, no "here is the whole
  mapper, tweak it."
- **Claude writes the skeleton, Jorge writes the bodies.** Module layout, imports, function
  signatures, type hints, docstrings — then a single `TODO(human)` where the decision lives.
- **One `TODO(human)` in the tree at a time.** It ships with the trade-offs stated and the answer
  withheld.
- **Claude may also write** test scaffolding, `.pp3` and config plumbing, throwaway measurement
  scripts, and reviews.
- **Explain before editing.** What the change does and why, before the tool call — read-only
  commands included.
- **Reviews are line-level and hands-off.** Name the line, name the idiom or the bug, explain why it
  matters; Jorge makes the edit. Correct-but-unidiomatic still gets flagged.
- Suspended only when Jorge says so explicitly, per file or per task.

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

The standardized preview profile is a versioned file in this repo, not a description. Eval runs
are only comparable if every preview was generated identically.

The committed file is a complete RawTherapee 5.13 `-O` dump (873 lines), so every setting is
stated and no version-dependent default can leak in. It is image-independent: two CR2s with
different as-shot white balance (4336K and 4827K) produce byte-identical profiles. Regenerate it
from a `-O` dump, never by hand, whenever the pinned renderer changes.

Settings the design depends on:

- `[Resize]` enabled, `LongEdge=512`, Lanczos. Previews are 512px on the long edge. Measured on
  the desktop: at this size repeat renders are byte-identical even multi-threaded, so the
  model-input path is fully deterministic — stronger than the production tolerance below.
- `ImageNum=0`. The field is zero-indexed.
- `InputProfile=(cameraICC)`, written explicitly. RawTherapee ships no DCP or input ICC for the
  Canon 2000D, so the four `[Color Management]` DCP switches (`ApplyLookTable`,
  `ApplyHueSatMap`, `ApplyBaselineExposureOffset`, `Setting=Camera`) are inert on this body.

**Open, Phase 1:** the mapper generates the production `.pp3` from a base profile, and that base
may legitimately differ from `neutral.pp3` on `ApplyLookTable`, `ApplyHueSatMap` and
`HLRecovery`. Direction is a decision inside the bootstrap loop, not a mechanical match. The first
two are inert on this body — set them by principle. `HLRecovery` likely diverges on purpose: off in
the preview so clipping stays visible for the `highlights` verdict, on in production.

## V3 label strength (constrains the Phase 4 log schema, not just Phase 5)

An accept does not prove all eight verdicts were right. Accepted images give **weak pseudo-labels**;
only explicitly corrected dimensions give **strong labels**. Train with per-output masks so a
white-balance correction cannot promote seven unreviewed predictions to ground truth. Design the
log for this from day one.

---

# Project constraints

Distilled from the design page in Notion, which is the source of truth for *why*. This file is the
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
- **Determinism, to a measured tolerance.** Same RAW + same profile + same configuration + pinned
  renderer build → output within tolerance: **under 0.01% of pixels differing, none by more than
  8/255**. Measured on the desktop with `neutral.pp3`, all cores: 0.0006% and 6/255; the tolerance
  is that with headroom, not the measurement itself. Multi-threaded RawTherapee is not
  byte-identical but sits inside it, so all cores stay enabled; do not force `OMP_NUM_THREADS=1`.
  Provisional until re-measured with denoise and sharpening enabled, and on the Pi.

Consequence: an **always**-tiled path is legal. A path that tiles **only when allocation fails** is
illegal — output would vary with how much memory happened to be free.

Open, pending measurement: desktop and Pi run the same release built for different architectures.
Cross-machine drift is unmeasured. Decision rule: if Pi output lands outside the tolerance of
desktop output, eval runs on the board *before* calibration; otherwise desktop eval stands.

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
- **`ai-pp3` is read, never imported.** It is GPL-2.0-only, which would foreclose permissive
  relicensing. Calling `rawtherapee-cli` via subprocess is not linking and constrains nothing.
- **Pinned renderer: RawTherapee 5.13 official AppImage, desktop and Pi.** Determinism is
  specified against a *pinned renderer build*; two versions means eval measures a proxy. `setup.sh`
  fetches by URL + sha256. Changing the pin invalidates every prior eval number and requires
  regenerating `neutral.pp3`.

## Hardware and concurrency

- Reference: **Pi 5 4GB, no accelerator, hosted picker, V1 fallback.** 8GB buys minutes on a full
  card, nothing architectural; do not revisit without a new argument.
- Leading configuration: **1 process × 4 threads, `RgbDenoiseThreadLimit=0`.** Desktop-measured;
  the Pi decides.
- **Two operating modes, both producing JPEGs within the determinism tolerance.** Field (default,
  power-bank): 1×2, conservative governor. Bench (mains): 1×4. **Justify the modes on peak
  current, not on speed** — the speed gap is small. If the Phase 3 power test shows no meaningful
  peak-draw difference, collapse to one mode.
- **No hardcoded hardware configuration.** Per-process memory varies with megapixels and profile.
  Probe the first render, read actual peak RSS, size workers from the remaining budget.
- **Probe at the thread count the workers will actually use.** Each denoise thread costs hundreds
  of MB.
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

This project's recurring failure mode is plausible reasoning stated as fact.

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
- **Which parts of the DCP are calibration and which are aesthetic.** One question behind four
  switches: `ApplyLookTable`, `ApplyHueSatMap` (probably calibration; currently disabled on the
  aesthetic reading), `ApplyBaselineExposureOffset`, `Setting=Camera`. Answer it once, for all four.
  All four are inert on this body, which has no DCP — decide it on a camera RawTherapee actually
  profiles, with something to measure.
