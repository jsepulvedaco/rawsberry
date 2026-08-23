# Pending

Source: Notion → *Open questions and pending amendments* → "Aug 22 2026 — parked and pending".

## CI — adopt when Phase 1 runs once

GitHub Actions on arm64 runners. Three jobs:

- Python lint and tests
- RawTherapee render smoke test on committed sample RAWs
- web build

Mapper gets unit tests and golden `.pp3` comparisons. No network calls in CI.
Copilot review on, with `.github/copilot-instructions.md` sharing content with `CLAUDE.md`.

**Blocker — sample RAWs.** The smoke test needs RAWs committed to the repo, but `.gitignore`
excludes `*.CR2` and the files are ~25MB each. Decide one: commit a single small RAW as a
deliberate exception, use Git LFS, or drop that job until Phase 1.

**Not startable yet.** No Python and no web code exist, so two of the three jobs have nothing
to run against.

## Changelog and versioning

- `CHANGELOG.md`, hand-written.
- Git tags with semantic versioning. `0.1.0` is the first laptop render; `1.0.0` is the kill
  criterion passed.
- Stamp a preview profile version number into every logged record.

**Depends on** the preview profile version stamp, which needs `neutral.pp3` regenerated — blocked
on pinning RawTherapee 5.10 (desktop) vs 5.11 (Pi).
