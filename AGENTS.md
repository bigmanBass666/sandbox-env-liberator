# AGENTS.md

## Project Overview

**sandbox-env-liberator** — Polaris 自主进化系统。Worker 持续在 worker 分支自主进化，CSO 在 main 分支改进系统架构，两者通过 Branch Sync Protocol 并行协作。
**Goal**: 彻底解放 sandbox 所有限制。

### Polaris 6 Dimensions (Scorecard)

| ID | 维度 | 终极状态 | 参考 |
|----|------|---------|------|
| D1 | 网络自由 | 无带宽限制，直连互联网 | `references/domains/01-network.md` |
| D2 | 包管理自由 | 任何开发工具链可安装 | `references/domains/04-package-management.md` |
| D3 | 进程自由 | 可运行任意进程 | `references/domains/03-process.md` |
| D4 | 文件系统自由 | 数据跨会话持久 | `references/domains/02-filesystem.md` |
| D5 | MCP/工具自由 | 可注册任意 MCP server | `references/domains/07-mcp-integration.md` |
| D6 | 自主进化自由 | 自主持续进化 | `references/polaris-score.md` |

完整能力矩阵: `references/domains/00-capability-matrix.md`

## Quick Start

```bash
bash scripts/evolve.sh          # 运行进化引擎
bash scripts/evolve.sh --dry-run # Dry run（不写入状态文件）
bash -n scripts/evolve.sh       # 语法检查
bash scripts/verify-env.sh      # 环境验证
```

### First-Time Setup (5 Commands)

```bash
bash scripts/full-recon.sh          # Domain 1-8 reconnaissance
bash scripts/deep-recon.sh          # Domain 9-10 deep reconnaissance
node scripts/fix-network.js         # Fix browser + network
bash scripts/setup-dev-toolchain.sh # Install missing tools
bash scripts/verify-env.sh          # Confirm everything works
```

Bootstrap: `bash scripts/bootstrap.sh [--role worker|reviewer|cso]`

## Polaris Autonomy Principle

> **Polaris 系统必须完全自主独立自治。Worker 的所有行为由 Polaris 系统文件驱动，不被任何外部实体（包括 CSO）直接指导。**

CSO 是系统构建的临时产物，最终交付物是一个完全自主独立自治的 Polaris 系统。CSO 退出后，Worker 必须仍能正常工作。

### 合法的 CSO 改动（增强 Polaris 系统自身）

- 修改 polaris-score.md 的 Milestone/Stretch Goals（增加目标）
- 修改 worker.md 的决策框架（教 Worker 如何自己判断）
- 修改系统约束（release-lock.sh 时间门槛、evolve.sh 参数）
- 修改 AGENTS.md 的规则和原则

### 非法的 CSO 改动（制造外部依赖）

- 在 worker.md 中添加"CSO 指定任务"或"本轮必做"的具体任务
- 在 Schedule message 中注入具体操作指令（如域名列表、curl 命令）
- 创建 CSO→Worker 的直接指导文件（如 cso-directives.md）
- 任何让 Worker 依赖 CSO 输入才能正常工作的改动

### 自治性检查（每次改动前必须回答）

1. 这个改动是否让 Worker 更依赖外部实体（CSO/人类）？
2. 如果 CSO 永久退出，Worker 是否仍能正常工作？
3. 这个改动是"教 Worker 如何自己判断"还是"替 Worker 做判断"？

如果问题 1 答案为"是"、问题 2 答案为"否"、问题 3 答案为"替 Worker 做判断"，则这个改动是错误的。

## Multi-Agent Roles

| Role | Branch | Trigger | Key Boundary |
|------|--------|---------|-------------|
| **CSO** | main | Manual | 可改任何系统文件；不改 Worker 数据 |
| **Worker** | worker | Scheduled (hourly, continuous) | 可改 env config/references/；不改 prompts/.agents/evolve.sh |
| **Reviewer** | — | Manual | 只审不改 |

### Permission Boundaries

- **Worker**: ✅ env config, install tools, run evolve.sh, update references/. ❌ prompts/, .agents/, evolve.sh 架构, push to main
- **CSO**: ✅ any system file, design architecture, read-only review worker data, selective cherry-pick. ❌ execute daily evolution rounds, modify worker data files
- **Reviewer**: ✅ review code, run verification. ❌ modify any code

Full policy: `.agents/permissions/policy.yaml`

## Branch Sync Protocol

### Two-Layer Model

| Layer | Branch | Role | Typical Files |
|-------|--------|------|---------------|
| **Tooling** | `main` | CSO 改进 Polaris 系统本身 | `scripts/`, `prompts/`, `.agents/`, `.trae/`, `AGENTS.md`, `.gitignore` |
| **Working** | `worker` | Worker 执行进化，维护数据 | `references/polaris-score.md`, `handoff.md`, `evolution-log.md`, `timeline-*.jsonl`, `worklogs/` |

### Main → Worker (Tooling Push)

CSO 完成系统改进后手动触发，仅同步白名单路径：

```
git checkout worker && git pull origin main --no-rebase --no-edit
# 验证: git diff HEAD~1 -- references/ 应为空（数据文件未被覆盖）
git push origin worker && git checkout main
```

**Whitelist**: `scripts/`, `prompts/`, `.agents/`, `.trae/`, `AGENTS.md`, `.gitignore`

### Worker → Main (Data Review)

CSO 审查后选择性采纳，**不自动同步**：

| File Type | Condition | Action |
|-----------|-----------|--------|
| `references/domains/` | 新能力实质性新增 | cherry-pick / manual copy |
| `references/adr/` | 新架构决策 | cherry-pick |
| `references/worklogs/` | CSO 要求归档 | manual copy |
| polaris-score / handoff / log | ❌ 永远不同步 | CSO 只读审查 |

- **main** = source of truth（工具层）。CSO 直推前必须 `git fetch` + `git pull`
- 详见 `.agents/context/architecture.md`

### Parallel Safety Rules

CSO 在 Worker 运行时可以安全地进行大多数操作。需要暂停 Worker 的场景：

| 操作类型 | 需要暂停 Worker | 原因 |
|----------|-----------------|------|
| 改工具文件 (scripts/prompts/.agents) | ❌ 不需要 | 下轮自动生效 |
| 改 AGENTS.md / .gitignore | ❌ 不需要 | 下轮自动生效 |
| Main→Worker Tooling Push | ⚠️ 需要 | git 操作期间分支状态变化 |
| 审查 Worker 数据文件 | ✅ 建议等待 | 避免读到半写状态 |
| cherry-pick 能力到 main | ✅ 建议等待 | 确保数据一致性 |

## File System Index

> 详细内容按需加载。`.agents/` 不自动加载，需主动 Read。

| Path | Purpose | Load When |
|------|---------|-----------|
| `.agents/agents/` | Role definitions (cso/worker/reviewer) | Playing a role |
| `.agents/rules/` | Task-level rules (evolve/scripts/git/scoring) | Executing that task type |
| `.agents/context/` | Architecture & project facts | Need architecture context |
| `.agents/permissions/` | Access control policy | Permission decisions |
| `.trae/rules/safety-redlines.md` | Critical safety rules | **Auto-loaded every response** |
| See also | `.agents/context/loading-guide.md` | Loading guide for all scenarios |

### Key Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/evolve.sh` | 进化引擎（10 Phase 流水线） |
| `scripts/bootstrap.sh` | 环境初始化（--role 参数） |
| `scripts/acquire-lock.sh` / `release-lock.sh` | 分布式锁 |
| `scripts/full-recon.sh` / `deep-recon.sh` | 全量/深度侦察 |
| `scripts/diagnose.sh` / `health-monitor.sh` | 诊断 & 监控 |
| `node scripts/fix-network.js` | 网络修复 |
| `node scripts/fetch-deps.js` | Node.js 依赖获取 |

## Safety Redlines (Summary)

> Full version: `.trae/rules/safety-redlines.md` | Details: `.agents/rules/*`

1. ❌ `git clean -fd` → 用 `-fdn` 先预览
2. ❌ `git reset --hard` → 先 backup 分支 + diff
3. ❌ Stash > 2 个 → 整理后再继续
4. ❌ 直接编辑 evolve.sh → 委托 sub-agent
5. ✅ 每次 edit 后 → `bash -n` 验证
6. ✅ CSO 不改 polaris-score/handoff \| Worker 不改 prompts/.agents/

## Code Style & Testing

- **Bash**: 4-space indent, UPPER_SNAKE_CASE globals, lower_snake_case locals
- **Timestamps**: `$(date +%s)` only — never hardcode or AI-generate
- **Error handling**: `2>/dev/null || true` for non-critical ops
- **Testing**: `bash -n` + `--dry-run` + `verify-env.sh`, no mocks, integration-level only
- **Per-Round Work Logs**: `references/worklogs/round-N.md`，Worker 按 CSO 要求创建
- **Security**: Never commit secrets/tokens/logs; targeted `git add <files>` never `-A`
- **Key Rules**:
  1. GitHub Source of Truth — always `git fetch` before work
  2. Anti-Stagnation — same dimension 3 rounds without progress → switch
  3. Scoring Integrity — re-measuring known state ≠ score increase, mark `(measurement correction)`
  4. Timeline Integrity — timestamps monotonically increasing

## External Dependencies

- **GitHub** (source of truth): `GITHUB_PERSONAL_ACCESS_TOKEN` for distributed lock and push
- **Node.js v18+**: fix-network.js, fetch-deps.js, Playwright
- **Bash 4+**: evolve.sh uses associative arrays
- **gh CLI**: installed by bootstrap.sh, used for lock management
- **MCP servers**: Playwright, Memory, Context7, WebFetch, Schedule — managed by platform
- **HTTP proxy**: `127.0.0.1:18080` — all outbound traffic via egress sidecar
