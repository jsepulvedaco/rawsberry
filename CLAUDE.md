# CLAUDE.md

## Rules

- **Do not run any command that has not been approved.** Propose the command and wait for approval before running it.
- **Do not go outside the current working directory** (`/home/jorge/Projects/edge-raw-jpeg`) unless explicitly asked to. This includes reading, listing, searching, and writing.
  - No searching the home directory for project-related files. Ask where they are instead.

## Git

- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:
  `<type>[optional scope]: <description>`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`, `style`.
- Description in imperative mood, lowercase, no trailing period.
