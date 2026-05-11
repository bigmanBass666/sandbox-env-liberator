# ADR-0002: Multi-Agent Roles (CSO/Worker/Reviewer)

## Status
Accepted

## Context
sandbox-env-liberator 项目使用多 Agent 协作模式。
需要明确每个角色的职责边界，避免越权操作。

## Decision
定义三个角色及其职责边界：

| 角色 | 默认分支 | 核心职责 | 禁止行为 |
|------|----------|---------|---------|
| **CSO** | main | Spec 制定、规则设计、系统改进、架构决策 | 直接修改 Worker 状态文件 |
| **Worker** | worker | 执行 evolve.sh、探索改进、更新状态文件 | 修改 prompts/、修改 .agents/、push 到 main |
| **Reviewer** | main | 代码审查、质量把控 | 直接修改代码 |

关键规则：
- CSO 不直接操作 Worker 的 polaris-score.md / handoff.md
- Worker 不绕过 evolve.sh 手动执行改进
- 所有 evolve.sh 修改通过 sub-agent 委托执行

## Consequences
**正面**:
- 职责清晰，避免冲突
- Guardrails 可针对不同角色定制
- 变更可审计

**负面**:
- 协作流程增加沟通成本
- 需要明确的委托协议
