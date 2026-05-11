# Loading Guide — 渐进式披露策略

> 本文件定义了在不同任务场景下应加载 `.agents/` 中的哪些文件。
> 平台自动加载 `AGENTS.md` + `.trae/rules/safety-redlines.md`（~232 行）。
> 其余内容按以下场景**主动读取**。

## 加载层级

```
Tier 0 (Auto-Loaded)     AGENTS.md + safety-redlines.md    ~232 行  ← 每次回复
Tier 1 (Role-Triggered)   .agents/agents/{role}.md          ~60 行   ← 扮演角色时
Tier 2 (Task-Triggered)   .agents/rules/*.md                 ~80 行   ← 执行对应任务
Tier 3 (Context-Triggered) .agents/context/*.md               ~75 行   → 需要上下文时
```

## 场景矩阵

### 场景 A: 执行 evolve.sh 修改

| 触发条件 | 加载文件 | 原因 |
|----------|----------|------|
| 需要修改 evolve.sh | `.agents/rules/evolve-scripts.md` | Phase 结构约束 |
| 需要修改 Phase 7 | `.agents/rules/worker-guardrails.md` + `.agents/rules/polaris-scoring.md` | Worker 自检清单 |
| 涉及多位置编辑 | `.trae/rules/safety-redlines.md` (ESG-1) | 委托阈值判断 |

### 场景 B: Git 操作

| 触发条件 | 加载文件 | 原因 |
|----------|----------|------|
| merge/rebase/cherry-pick | `.trae/rules/safety-redlines.md` (GSR 全部) | Git 安全红线 |
| 常规 commit/push | 无需额外加载 | safety-redlines 已覆盖 |
| 处理 stash 过多 | `.agents/permissions/policy.yaml` | 权限策略参考 |

### 场景 C: 扮演特定角色

| 角色 | 必须加载 | 可选加载 |
|------|----------|----------|
| **CSO** | `.agents/agents/cso.md` | `.agents/context/architecture.md` |
| **Worker** | `.agents/agents/worker.md` + `prompts/worker.md` | `.agents/rules/prompts-protection.md` |
| **Reviewer** | `.agents/agents/reviewer.md` | — |

### 场景 D: 架构决策 / 系统设计

| 触发条件 | 加载文件 | 原因 |
|----------|----------|------|
| 设计新功能/新 spec | `.agents/context/architecture.md` | 架构决策与模式 |
| 理解项目全貌 | `.agents/context/index.md` | 项目概览 |
| 判断文件归属 | `.agents/permissions/policy.yaml` | 权限边界 |
| 评分相关操作 | `.agents/rules/polaris-scoring.md` | 评分完整性规则 |

### 场景 E: 审查 Worker 工作成果

| 触发条件 | 加载文件 | 原因 |
|----------|----------|------|
| 审查 worker commit | `.agents/agents/worker.md` (理解 Worker 边界) | 不越权修改 |
| 对比分支差异 | `.trae/rules/safety-redlines.md` (RB-1) | CSO 不改数据 |
| 决定是否合并 | `.agents/context/architecture.md` (Git Workflow 段) | 合并策略 |

## 快速查找表

| 我需要... | 读这个文件 |
|-----------|-----------|
| 「我能改哪些文件？」 | `.agents/permissions/policy.yaml` |
| 「这个任务该委托吗？」 | `.trae/rules/safety-redlines.md` (DT/ESG 部分) |
| 「Worker 的权限边界？」 | `.agents/agents/worker.md` |
| 「evolve.sh 的 Phase 结构？」 | `.agents/rules/evolve-scripts.md` |
| 「怎么评分才合规？」 | `.agents/rules/polaris-scoring.md` |
| 「卡住了怎么办？」 | `.trae/rules/safety-redlines.md` (CLM 部分) |
