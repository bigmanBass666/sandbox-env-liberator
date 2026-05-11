# ADR-0001: GitHub as Source of Truth

## Status
Accepted

## Context
Polaris 系统由 CSO（架构师）和 Worker（执行者）两个角色协作维护。
Worker 运行在隔离环境中，每次会话都是全新的。
本地文件系统可能过期或被覆盖。

## Decision
GitHub 仓库是唯一真相源（Single Source of Truth）。
- 所有状态文件（polaris-score.md, handoff.md, evolution-log.md）以 Git 追踪
- Worker 开始工作前必须 `git fetch origin && git pull`
- 本地修改必须在同一轮内 commit + push
- CSO 通过 merge worker→main 同步改进成果

## Consequences
**正面**:
- 多 Worker 实例不会互相覆盖数据
- 完整的变更历史可追溯
- 数据丢失可从 GitHub 恢复

**负面**:
- 需要 GitHub token 才能 push
- 网络依赖（无网络时只能本地工作）
- merge 冲突需要人工处理
