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
| Prompt body size OK | `awk '/<!--/,0' prompts/worker.md \| wc -c` < 15000 | Trim before commit |
| No hardcoded ops in prompt | `grep -cE '(Round [0-9]|R[0-9]{2}|Total: \*\*[0-9]+%\*\*|D[1-6]: [0-9]+%)' prompts/worker.md` = 0 | Remove hardcoded data, use polaris-score.md refs instead |
| No concrete next-steps in prompt | `grep -Pn '(?<!必须先运行)(?<!重新运行)(?<!手动执行)(安装|配置|启动) +(nginx|docker|elasticsearch|CDN|cron|restic|seccomp)' prompts/worker.md` = 0 | Replace with decision framework, move specifics to polaris-score.md |
| HTML comment intact | `grep -c 'FILE NATURE DECLARATION\|META-PROMPT' prompts/worker.md` ≥ 1 | Restore comment block before commit |
| TEST 2 in comment | `grep -c "what to do.*or.*how to decide" prompts/worker.md` ≥ 1 | Restore TEST 2 self-check line |

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
