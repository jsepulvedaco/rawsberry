---
name: decision-log-entry
description: Write or review an entry for the rawsberry Decision Log page in Notion. Use this whenever the user asks to log a decision, add something to the log page, record what was decided, or asks whether something belongs in the log — and always before appending anything to the Decision Log yourself, including at the end of a working session. Also use when auditing existing entries for diary creep.
---

# Decision Log entries

The Decision Log records **decisions and their consequences**. It is not a diary, not a
changelog, and not a record of work performed.

Page: `3c0aa212-3598-8174-8a33-eece71c1da82`
Append with `notion-update-page`, `command: insert_content`, `position: {"type": "end"}`.
Newest last. The log is append-only — do not rewrite existing entries unless explicitly asked.

## First, decide whether it belongs

Most work produces no log entry. Ask: **six months from now, would someone reading this need it
to understand why the project is the way it is?**

Belongs:
- A decision, and what it rules out.
- A **retraction or correction** of something the log previously asserted. These are the highest
  value entries on the page — they are the record of the project's reasoning being wrong and
  getting fixed.
- A finding that changes what is possible or forecloses an option.
- A measurement that settles an open question.

Does not belong:
- Commits made, files deleted, sections moved, tickets created, pages reorganised.
- Provisioning and setup narration — that is README material.
- Defects and open work — those are Backlog cards. Link the decision, not the task list.
- "What we did today" in any form.

If it is genuinely worth recording but is operational rather than architectural, say so and put
it in the README or a Backlog card instead. Offer that alternative rather than logging it anyway.

## Format

```
**<Mon DD YYYY> — <headline that states the decision itself>.** <one dense paragraph>
```

The headline must carry the decision, not the topic. `— renderer pinned to RawTherapee 5.13 on
both machines, enforced by checksum` tells you the outcome. `— renderer version discussion` does
not.

The paragraph covers three things, in this order:

1. **The decision** — what was chosen.
2. **The mechanism** — how it is enforced, and why that specific mechanism rather than an
   obvious cheaper one. This is usually the part that stops the decision being re-litigated.
3. **The consequence** — what is now invalid, blocked, unblocked, or no longer comparable.

Use bold inline labels (`**Consequences:**`, `**Retracted:**`, `**Unverified:**`) to break up a
long paragraph, matching the existing entries. Do not use headings or bullet lists — the page is
a run of paragraphs.

## Propagation — required before the entry is posted

Every stale claim this project has accumulated came from a decision being recorded where the
conversation happened and nowhere else. The log entry is the one place every decision passes
through, so the check belongs here.

Before posting, name every place the old claim currently lives: `CLAUDE.md`, `README.md`, the
project root page, other Notion pages, other Backlog cards. Search for it rather than recalling
it — the claim is usually phrased differently in each place.

Then, in the same session:

- **Repo files** — make the edit. A decision that leaves `CLAUDE.md` contradicting the log is not
  finished.
- **Notion prose pages** — make the edit, stating only what is now true. No dated correction, no
  strikethrough, no "revised" marker. That is what the log entry is for.
- **Anything you cannot reach** — a Backlog card naming the file and the exact claim to fix.

Two writers reach this project: sessions with the repo, and the Claude app with Notion only. The
app cannot edit the repo, so a card is its only channel to it. When a decision arrives from that
side, expect the repo half to be undone.

Do not list the propagation in the entry itself — that is housekeeping. It is a precondition for
posting, not content.

## Length

One paragraph. Write it, then cut.

If it will not fit in one paragraph, one of three things is true and each has its own fix:
- It is two decisions → write two entries.
- It contains diary → cut that part.
- It is restating reasoning the reader can reconstruct → cut it.

Length is a real cost here, not a style preference. The page is read into context repeatedly and
the project has already split the note once to control that. A long entry taxes every future
read.

## Epistemic rules

These come from the project's own standing rules and the log's recurring failure mode, which is
plausible reasoning stated as fact.

- **Label measured versus guessed.** If a number was estimated, say so. An estimate must never
  drift into being treated as data.
- **Off-board measurements are provisional.** Desktop numbers do not decide the architecture.
- **Retract explicitly.** If the entry corrects an earlier claim, name the claim and say it is
  retracted. Do not quietly write the new version.
- Do not restate the user's own feedback back to them as if it were a specification.

## Example

**Good** — decision, mechanism, consequence, no narration:

> **Aug 23 2026 — renderer pinned to RawTherapee 5.13 on both machines, enforced by checksum.**
> 5.13 is the first release with an official arm64 build, so desktop and Pi run the same upstream
> AppImage instead of two distro builds that were never going to converge. `setup.sh` no longer
> apt-installs RawTherapee; it fetches the GitHub release asset, verifies a recorded sha256 and
> aborts on mismatch — a release asset can be re-uploaded under the same tag, so the version names
> the request and the hash names what arrived. Verified on the board: `rawtherapee-cli` reports
> 5.13, apt's 5.11 removed.

**Cut from that same entry before it was posted**, as illustrations of what does not belong:

> ~~**Housekeeping:** `Engineering practices` deleted from the parent page, now three Backlog
> cards; `TODO.md` deleted from the repo, commit `790c5c1`.~~

Activity, not decision. Nobody needs it later.

> ~~Commit `f57f2e1`. **Consequences:** `neutral.pp3` still declares `AppVersion=5.10` and must be
> regenerated.~~

The commit hash is traceable from git. The `neutral.pp3` regeneration is already a Backlog card —
the log should not duplicate the task tracker.

## Before posting

Show the drafted entry to the user and get confirmation before appending. Entries are hard to
unpick once the page is read into other contexts, and the user is the one who knows whether a
decision is actually settled.
