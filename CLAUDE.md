@AGENTS.md

## Claude Code Specific

- Use plan mode for changes to `scripts/evolve.sh` architecture
- Always run `bash -n scripts/evolve.sh` after editing evolve.sh
- Never use `git add -A` — always specify files explicitly
- When editing evolve.sh, include ≥3 lines of context in SearchReplace operations
- Never replace a single-line function call without surrounding structure
