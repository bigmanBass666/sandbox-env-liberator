---
paths:
  - "scripts/evolve.sh"
  - "scripts/bootstrap.sh"
---

# Worker Guardrails

These checks run BEFORE any commit is pushed. If any CRITICAL check fails, the commit must NOT be pushed.

## CRITICAL (must pass)

| Check | Command | Fail Action |
|-------|---------|-------------|
| Syntax valid | `bash -n scripts/evolve.sh` | Do NOT commit |
| No forbidden files | `git diff --name-only HEAD~1 \| grep -E 'test\|tmp\|\.bak\|crash\|\.log'` | Remove files, re-commit |
| Not pushing to main | `git branch --show-current` should be `worker` | Switch to worker branch |
| No prompts/ changes | `git diff --name-only HEAD~1 \| grep '^prompts/'` | Revert prompts/ changes |

## WARNING (should pass)

| Check | Command | Fail Action |
|-------|---------|-------------|
| Dry-run passes | `bash scripts/evolve.sh --dry-run` | Investigate, may still commit |
| Timeline integrity | `wc -l /tmp/sandbox-evolve/timeline.jsonl` ≥ 20 | Log warning |
| Polaris score reasonable | Single round growth ≤ +30% | Log warning, verify scoring |
| verify-env PASS count | Not regressed from previous round | Log warning |

## Scoring Guardrails

- Re-measuring known state → mark `(measurement correction)`, Delta = 0
- Discovery Bonus → max +5%
- New Capability → normal scoring, but single round max +30% per dimension
- If total Polaris score would exceed 700 in a single round → verify each dimension independently
