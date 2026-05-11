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
- Environment verify: `bash scripts/verify-env.sh`
- Install gh CLI: see `scripts/bootstrap.sh` for automated installation

## Quick Start (5 Commands)

```bash
bash scripts/full-recon.sh          # Domain 1-8 reconnaissance
bash scripts/deep-recon.sh          # Domain 9-10 deep reconnaissance
node scripts/fix-network.js         # Fix browser + network
bash scripts/setup-dev-toolchain.sh # Install missing tools
bash scripts/verify-env.sh          # Confirm everything works
```

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
  schedule-setup.md  — 定时任务配置参考
  timeline-round-N.jsonl — 每轮时间线归档
  domains/           — 10域参考知识（详见下方域摘要表）
    00-capability-matrix.md  — 能力矩阵总览
    01-network.md ~ 10-security-isolation.md — 各域详细知识
    troubleshooting.md       — 跨域故障排除
  archive/           — 归档文档
    meta-prompt-v2.md — Meta Prompt v2（已归档）

prompts/
  worker.md          — Night Evolution Worker 执行指令（Schedule 任务使用）

.agents/
  acs.yaml           — ACS 项目清单
  agents/            — 角色定义（ACS 格式）
    worker.md        — Worker 角色定义
    cso.md           — CSO 角色定义
    reviewer.md      — Reviewer 角色定义
  permissions/
    policy.yaml      — 统一权限策略
  context/           — 项目上下文（渐进式披露 Tier 2）
    index.md         — 项目概览
    architecture.md  — 架构决策与模式
  rules/             — 路径特定规则
    evolve-scripts.md  — scripts/ 目录守则
    polaris-scoring.md — 评分完整性规则
    prompts-protection.md — Worker 禁止修改系统文件
    worker-guardrails.md — Worker 自检清单
```

## Multi-Agent Roles

| Role | Definition | Branch | Trigger |
|------|-----------|--------|---------|
| **CSO** | `.agents/agents/cso.md` | main | Manual |
| **Evolution Worker** | `.agents/agents/worker.md` + `prompts/worker.md` | worker | Scheduled (hourly) |
| **PR Reviewer** | `.agents/agents/reviewer.md` | — | Manual |

### Permission Boundaries

- **Worker**: ✅ Can modify env config, install tools, run evolve.sh, update references/. ❌ Cannot modify `prompts/`, `.agents/`, `evolve.sh` architecture. ❌ Cannot push to main. Works on `worker` branch.
- **CSO**: ✅ Can modify any system file, design architecture, merge worker → main. ❌ Cannot execute daily evolution rounds.
- **Reviewer**: ✅ Can review code, run verification. ❌ Cannot modify any code.

Full permission policy: `.agents/permissions/policy.yaml`

## Git Workflow

| Role | Branch | Commit Method | Review Gate |
|------|--------|---------------|-------------|
| CSO | main | `git push origin main` | 用户对话 = 实时 review |
| Worker | worker | `git push origin worker` | CSO merge worker → main |

- **main** 是 source of truth
- CSO 直推前必须 `git fetch` + `git pull`
- CSO 在合适时机 merge worker → main
- 详见 `.agents/context/architecture.md`

## Domain Summary (Polaris 6 Dimensions)

| ID | 维度 | 终极状态 | 参考文档 |
|----|------|---------|---------|
| D1 | **网络自由** | 无带宽限制，直连互联网 | `references/domains/01-network.md` |
| D2 | **包管理自由** | 任何开发工具链可安装 | `references/domains/04-package-management.md` |
| D3 | **进程自由** | 可运行任意进程 | `references/domains/03-process.md` |
| D4 | **文件系统自由** | 数据跨会话持久 | `references/domains/02-filesystem.md` |
| D5 | **MCP/工具自由** | 可注册任意 MCP server | `references/domains/07-mcp-integration.md` |
| D6 | **自主进化自由** | 自主持续进化 | `references/polaris-score.md` |

完整能力矩阵: `references/domains/00-capability-matrix.md`

## Code Style

- Bash scripts: 4-space indent, no tabs
- Variable naming: UPPER_SNAKE_CASE for globals, lower_snake_case for locals
- Error handling: `2>/dev/null || true` for non-critical operations
- All timestamps from `$(date +%s)` — never hardcode or AI-generate timestamps

## Testing

- Syntax: `bash -n scripts/evolve.sh` (must pass before any commit)
- Dry run: `bash scripts/evolve.sh --dry-run` (validates full pipeline)
- Environment: `bash scripts/verify-env.sh` (checks tool availability)
- Recon: `bash scripts/full-recon.sh` (Domain 1-8), `bash scripts/deep-recon.sh` (Domain 9-10)
- No unit test framework — all testing is integration-level via verify-env.sh and dry-run
- Do not mock environment — tests must pass in the actual sandbox

## External Dependencies

- **GitHub** (source of truth): `GITHUB_PERSONAL_ACCESS_TOKEN` required for distributed lock and push
- **Node.js v18+**: Required for fix-network.js, fetch-deps.js, Playwright
- **Bash 4+**: Required for evolve.sh (uses associative arrays)
- **gh CLI**: Installed by bootstrap.sh, used for lock management
- **MCP servers**: Playwright, Memory, Context7, WebFetch, Schedule — managed by platform
- **HTTP proxy**: `127.0.0.1:18080` — all outbound traffic routed through egress sidecar

## Security

- Never commit secrets, tokens, or API keys
- Never commit test files, temp files, crash dumps, or `.log` files
- Always `git status` before `git add` — use targeted `git add <files>`, never `git add -A`
- gh CLI auth from git remote URL token — no manual token entry
- This system does NOT: install kernel modules, bypass auth, access resources outside sandbox permissions, provide Docker-in-Docker

## Key Rules

1. **GitHub Source of Truth**: GitHub is the single source of truth. Always `git fetch` before starting work.
2. **Anti-Stagnation**: Same dimension 3 rounds without progress → must switch dimension.
3. **Scoring Integrity**: "Re-measuring known state" is not grounds for score increase. Mark as `(measurement correction)`.
4. **Timeline Integrity**: All timestamps from `$(date +%s)`. Timeline events must be monotonically increasing.
5. **Git Workflow**: CSO 直推 main（对话即 review），Worker 直推 worker 分支，CSO 适时 merge。
