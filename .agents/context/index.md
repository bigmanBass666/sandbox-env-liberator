# Project Context: sandbox-env-liberator

## What
Polaris 自主进化系统，目标是彻底解放 sandbox 的所有限制。

## Why
云沙箱环境存在网络、文件系统、进程、包管理、浏览器等多方面限制，需要系统化地发现和解除这些限制。

## How
- 通过定时任务驱动的 AI agent（Worker）在夜间持续工作
- 白天由 CSO 审查 Worker 成果并改进系统架构
- Polaris 6维度评分系统驱动进化方向
- evolve.sh 10-Phase 流水线执行进化轮次

## Tech Stack
- Bash (evolve.sh, bootstrap.sh, lock scripts)
- Node.js (fix-network.js, fetch-deps.js)
- Git + GitHub (source of truth, distributed lock via Issue #1)
- MCP (Playwright, Memory, Context7, WebFetch, Schedule)

## Key Files
- `AGENTS.md` — 项目入口文档
- `references/polaris-score.md` — Polaris 评分仪表盘
- `references/handoff.md` — 轮次交接信息
- `references/evolution-log.md` — 进化历史日志
- `references/domains/` — 10域参考知识
- `prompts/worker.md` — Worker 执行指令
- `scripts/evolve.sh` — 进化引擎
