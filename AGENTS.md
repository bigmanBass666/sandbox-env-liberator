# AGENTS.md

## Project Overview

**sandbox-env-liberator** — Polaris 自主进化系统，目标是彻底解放 sandbox 的所有限制。

系统通过定时任务驱动的 AI agent（Night Evolution Worker）在夜间持续工作，每轮自动执行环境检测、问题诊断、改进实施、结果验证的完整闭环。白天由 CSO（首席系统官）审查夜间工作结果并改进系统架构。

## Setup Commands

- Clone: `git clone https://github.com/bigmanBass666/sandbox-env-liberator.git`
- Bootstrap: `bash scripts/bootstrap.sh [--role worker|reviewer|cso]`
- Run evolution: `bash scripts/evolve.sh`
- Dry run: `bash scripts/evolve.sh --dry-run`
- Syntax check: `bash -n scripts/evolve.sh`
- Install gh CLI: see `scripts/bootstrap.sh` for automated installation

## Architecture

```
scripts/
  evolve.sh          — 进化引擎（10 Phase 流水线）
  bootstrap.sh       — 环境初始化（--role 参数）
  acquire-lock.sh    — 分布式锁
  release-lock.sh    — 释放锁
  verify-env.sh      — 环境验证
  deep-recon.sh      — 深度侦察（网络/权限/资源）
  full-recon.sh      — 全量侦察
  diagnose.sh        — 环境诊断
  health-monitor.sh  — 健康监控
  persist-config.sh  — 配置持久化
  setup-dev-toolchain.sh — 开发工具链安装
  fetch-deps.js      — Node.js 依赖获取
  fix-network.js     — 网络修复脚本

references/
  polaris-score.md   — Polaris 评分系统（6 维度 × 100 分制）
  handoff.md         — 轮次交接信息
  evolution-log.md   — 进化历史日志
  timeline-round-N.jsonl — 每轮时间线归档

prompts/
  worker.md          — Night Evolution Worker 执行指令
  worker.card.yaml   — Worker 角色卡（YAML 格式）
  cso.card.yaml      — CSO 审查/改进角色卡
  reviewer.card.yaml — PR Reviewer 审查角色卡

.agents/rules/
  evolve-scripts.md  — scripts/ 目录守则（path-specific）
  polaris-scoring.md — 评分完整性规则（path-specific）
  prompts-protection.md — Worker 禁止修改系统文件（path-specific）
  worker-guardrails.md — Worker 自检清单（CRITICAL + WARNING）
```

## Multi-Agent Roles

| Role | Prompt File | Branch | Trigger |
|------|------------|--------|---------|
| **CSO** | `prompts/cso.card.yaml` | main | Manual |
| **Evolution Worker** | `prompts/worker.md` | night-evolve | Scheduled (hourly) |
| **PR Reviewer** | `prompts/reviewer.card.yaml` | — | Manual |

### Permission Boundaries

- **Worker**: ✅ Can modify env config, install tools, run evolve.sh. ❌ Cannot modify `prompts/`, `SKILL.md`, `evolve.sh` architecture. ❌ Cannot push to main.
- **CSO**: ✅ Can modify any system file, design architecture, review PRs. ❌ Cannot execute daily evolution rounds.
- **Reviewer**: ✅ Can review code, run verification, merge PRs. ❌ Cannot modify any code.

## Git Workflow

### 主线直推 + 并线 PR

- **CSO（交互式对话）**：直推 main — 对话即 Review，用户实时审核
- **Worker（自主运行）**：必须走 PR — 无人类在场，PR 是唯一安全门控
- **Reviewer**：审查 Worker 的 PR，确认后 merge

| Role | Branch | Commit Method | Review Gate |
|------|--------|---------------|-------------|
| CSO | main | `git push origin main` | 用户对话 = 实时 review |
| Worker | night-evolve | `gh pr create` → PR | Reviewer 人工 review |
| Reviewer | — | merge PR | — |

- **main** 是 source of truth
- CSO 直推前必须 `git fetch` + `git pull`，确保基于最新状态
- Worker 的 PR 在用户醒来后由 Reviewer 或 CSO 审查合入

## Code Style

- Bash scripts: 4-space indent, no tabs
- Variable naming: UPPER_SNAKE_CASE for globals, lower_snake_case for locals
- Error handling: `2>/dev/null || true` for non-critical operations
- All timestamps from `$(date +%s)` — never hardcode or AI-generate timestamps

## Testing

- Syntax: `bash -n scripts/evolve.sh` (must pass before any commit)
- Dry run: `bash scripts/evolve.sh --dry-run` (validates full pipeline)
- Environment: `bash scripts/verify-env.sh` (checks tool availability)

## Security

- Never commit secrets, tokens, or API keys
- Never commit test files, temp files, crash dumps, or `.log` files
- Always `git status` before `git add` — use targeted `git add <files>`, never `git add -A`
- gh CLI auth from git remote URL token — no manual token entry

## Key Rules

1. **GitHub Source of Truth**: GitHub is the single source of truth. Always `git fetch` before starting work.
2. **Anti-Stagnation**: Same dimension 3 rounds without progress → must switch dimension.
3. **Scoring Integrity**: "Re-measuring known state" is not grounds for score increase. Mark as `(measurement correction)`.
4. **Timeline Integrity**: All timestamps from `$(date +%s)`. Timeline events must be monotonically increasing.
5. **Git Workflow**: CSO 直推 main（对话即 review），Worker 必须走 PR（无人类在场）。
