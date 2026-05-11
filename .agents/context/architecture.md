# Architecture Decisions & Patterns

## Multi-Agent Architecture

### Three Roles
| Role | Branch | Commit Method | Review Gate |
|------|--------|---------------|-------------|
| CSO | main | `git push origin main` | 用户对话 = 实时 review |
| Worker | worker | git push origin worker | CSO read-only data review, selective adopt |
| Reviewer | none | — | Read-only verification |

### Dual-Track Operations
- 🔄 Continuous: Worker 持续在 worker 分支运行（每小时触发，全天候）
- 🔄 Concurrent: CSO 随时在 main 分支进行系统改进（手动触发）
- ⚡ Sync Point: CSO 按需执行 Main→Worker Tooling Push（需暂停 Worker）
- 📋 Review: CSO 只读审查 Worker 数据文件，选择性采纳到 main（不 auto-sync）

## Polaris Scoring System

6 dimensions × 100 points:
- D1: 网络自由 (Network)
- D2: 包管理自由 (Package Management)
- D3: 进程自由 (Process)
- D4: 文件系统自由 (Filesystem)
- D5: MCP/工具自由 (MCP & Tools)
- D6: 自主进化自由 (Autonomous Evolution)

Lowest-scoring dimension = primary improvement target.
3 consecutive rounds without progress → forced domain rotation.

## evolve.sh 10-Phase Pipeline

1. Lock+Env → 2. GitHub Sync → 3. Recon → 4. DeltaAnalysis → 5. Hypotheses → 6. Experiments → 7. AntiStagnation → 8. Integration → 9. Reflection → 10. RecordCommit+ReleaseLock

## GitHub Distributed Lock

Uses GitHub Issue #1 as distributed lock:
- Lock free: Closed, no `evolving` label
- Lock acquired: Open, `evolving` label, body has timestamp
- Lock timeout (>60min): Force release

## Key Design Decisions

1. **GitHub as Source of Truth**: Local filesystem is just a cache. Always `git fetch` before work.
2. **State Files, Not Task Inheritance**: New sessions read current state (polaris-score + handoff + evolution-log), not historical tasks.
3. **对话即 Review**: CSO + user dialogue = real-time review, no PR needed for CSO.
4. **Dual-Track Parallelism**: CSO 和 Worker 在各自分支上并行工作，通过 Branch Sync Protocol（白名单选择性同步）交互。Worker 数据文件永远不自动合并到 main。
5. **Anti-Stagnation**: Same dimension 3 rounds without progress → must switch dimension.

## Dual-Track Safety Rules

| 操作类型 | 需要暂停 Worker | 原因 |
|----------|-----------------|------|
| CSO 改工具文件 (scripts/prompts/.agents) | ❌ 不需要 | 下轮自动生效 |
| CSO 改 AGENTS.md / .gitignore | ❌ 不需要 | 下轮自动生效 |
| Main→Worker Tooling Push 同步 | ⚠️ 需要 | git 操作期间分支状态变化 |
| CSO 审查 Worker 数据文件 | ✅ 建议等待 | 避免读到半写状态 |
| CSO cherry-pick Worker 能力到 main | ✅ 建议等待 | 确保数据一致性 |
