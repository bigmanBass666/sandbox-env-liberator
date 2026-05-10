---
paths:
  - "scripts/**"
---

# Evolve Script Rules

- Always run `bash -n scripts/evolve.sh` after any edit
- SearchReplace: include ≥3 lines of context, never replace a single-line function call
- Phase timing uses scalar globals (`PHASE_START_0` etc.) — do not convert back to associative arrays in `$(( ))` context
- `PHASE_NAMES` is `declare -A` — must use associative array syntax
- Timeline JSONL writes use `>>` append with `2>/dev/null || true` — never remove this fallback
- Phase 8 pushes to branch (not main) — never change to `git push origin main`
- `TIMELINE_FILE` archive must happen after `print_time_report` (end of script), not in Phase 8
