# Architecture Decisions & Patterns

## Multi-Agent Architecture

### Three Roles
| Role | Branch | Commit Method | Review Gate |
|------|--------|---------------|-------------|
| CSO | main | `git push origin main` | 用户对话 = 实时 review |
| Worker | worker | `git push origin worker` | CSO merge worker → main |
| Reviewer | none | — | Read-only verification |

### Three Scenarios
- ☀️ Daytime: CSO pushes main + Worker pushes worker in parallel
- 🌙 Night: Worker autonomous on worker branch via scheduled tasks
- 🌅 Morning: CSO reviews Worker's worker branch commits and merges

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
4. **Worker Branch Isolation**: Worker never touches main, CSO merges when ready.
5. **Anti-Stagnation**: Same dimension 3 rounds without progress → must switch dimension.
