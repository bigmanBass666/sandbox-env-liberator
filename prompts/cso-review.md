# CSO Review Prompt（人工发送）

> **触发方式**: 人工手动发送给 CSO agent
> **使用场景**: Worker 完成一轮或多轮新工作后，需要 CSO 审查并改进系统

---

Worker 完成了一轮或多轮新工作，请执行 CSO 审查流程：

## 1. 感知（按顺序）

- `git log worker --oneline` — 最近做了哪些 commit
- `references/polaris-score.md` — 分数变化 + **当前 Round 编号**
- `references/handoff.md` — 当前状态与 Blockers
- `references/evolution-log.md` — Worker 自述摘要（**重点读遥测盲区内的轮次**）
- `references/worklogs/` — 遥测数据：读取最新 round-N.md

### 轮差检测（并行模型关键信号）

对比 polaris-score 的 Round 与 worklog 最新编号：
```
当前 Round = 47, worklog 最新 = round-45 → 轮差 = 2（正常，Worker 在并行跑）
```
- **轮差 0**: 遥测完整，正常审查
- **轮差 1-2**: 小幅滞后（并行模型常态），evolution-log 补充覆盖盲区
- **轮差 3+**: 明显滞后，建议先快速扫过盲区内的 evolution-log 再做判断
- **轮差越大 → Worker 跑得越快 → Tooling Push 前需更谨慎**

## 2. 判断

系统是否需要改进？（范围：`prompts/` / `.agents/` / `scripts/` / `AGENTS.md` / `.trae/` / `.gitignore`）

结合遥测中的真实推理过程判断：
- Worker 的行为模式是否正常
- prompt 是否被误读或钻空子
- 规则是否有漏洞需修补
- 系统工具链是否有可改进之处

## 3. 行动

- **有改进点** → 在 `main` 上修改 → `commit` → `push`
- **无改进点** → 输出简短审查记录（含对 Worker 行为模式的观察，不应空转）

## 4. 同步

如果改了工具文件，评估是否需要 Main→Worker Tooling Push：
- **轮差小（0-2）**: 可直接同步
- **轮差大（3+）**: 建议先确认 Worker 不在执行中途，或先暂停再同步

```
git checkout worker && git pull origin main --no-rebase --no-edit
# 验证: git diff HEAD~1 -- references/ 应为空
git push origin worker && git checkout main
```

## 安全边界

- ✅ 可改：白名单文件（scripts/prompts/.agents/.trae/AGENTS.md/.gitignore）
- ❌ 禁改：Worker 数据文件（references/ 下 polaris-score/handoff/evolution-log/worklogs）
- ❌ 禁止：force push、直接编辑 evolve.sh（须委托 sub-agent）
