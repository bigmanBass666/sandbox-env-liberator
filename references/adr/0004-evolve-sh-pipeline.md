# ADR-0004: Evolve.sh Pipeline Design

## Status
Accepted

## Context
需要一个自动化引擎来驱动持续改进。
手动执行容易出错且不一致。

## Decision
采用 10 Phase 流水线设计（evolve.sh）：

| Phase | 功能 | 输出 |
|-------|------|------|
| 0 | 环境准备 + 分布式锁 | LOCK_HELD |
| 1 | 环境快照 | VERIFY_PASS/FAIL |
| 2 | Polaris 分析 | POLARIS_FOCUS_DIM |
| 3 | 深度侦察 | RECON_DATA |
| 4 | 改进策略选择 | RECOMMENDED_FOCUS |
| 5 | 安全检查 | SAFE_TO_PROCEED |
| 6 | 集成验证 | INTEGRATION_PASS |
| 7 | 改进执行 | IMPROVE_SUCCESS |
| 8 | 状态写入 | EVOLUTION_LOGGED |
| 9 | 清理 + 释放锁 | CLEAN_EXIT |

关键机制：
- DRY_RUN 模式跳过实际执行但保留状态赋值
- continue-loop 在 Phase 7 后提供额外改进机会
- Anti-Stagnation Streak 强制维度旋转

## Consequences
**正面**:
- 自动化程度高，减少人为失误
- 时间预算控制（PHASE_TIMEOUT）
- 完整的审计日志

**负面**:
- 单文件 1650+ 行，维护成本高
- 复杂的控制流（DRY_RUN/fast/normal 多路径）
- Phase 间变量依赖隐式
