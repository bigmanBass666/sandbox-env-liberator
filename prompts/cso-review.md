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
- `references/worklogs/` — 遥测数据（按信号驱动选择，见下文）

### 轮差检测（并行模型关键信号）

对比 polaris-score 的 Round 与 worklog 最新编号：
```
当前 Round = 52, worklog 最新 = round-45 → 轮差 = 7（盲区：Round 46~52）
```
- **轮差 0**: 遥测完整，正常审查
- **轮差 1-2**: 小幅滞后（并行模型常态），evolution-log 补盲区
- **轮差 3+**: 明显滞后，先做 evolution-log 快速扫描锁定关键轮次

### Worklog 选择策略（两层过滤）

**不要盲目全读**。Worker 一夜可能跑 8-10 轮，遥测数据量大。按以下流程筛选：

**量级判断（先看盲区内有多少个 worklog）**

| 盲区 worklog 数量 | 策略 |
|-------------------|------|
| 0 个（轮差 0） | 读最新 1-2 个即可 |
| **1-2 个** | **全部精读，不做筛选** — 量小，直接完整消化，避免筛选成本反超读取成本 |
| **3-5 个** | **信号筛选 + 重点精读** — 使用下表 |
| **6+ 个** | **强筛选** — 只读 🔴🟢 信号轮次 + 最新 1 个基线 |

**第一层：evolution-log 轻量扫描**（盲区 ≥3 个时执行）
- 扫描盲区内每轮的摘要行（Round / 维度 / Delta / 状态 / 关键事件）
- 标记有异常信号的轮次

**第二层：信号驱动的 worklog 读取**

| 信号 | 优先级 | 读 worklog？ | 原因 |
|------|--------|-------------|------|
| 分数退步 | 🔴 高 | **必须读** | 真回归还是 measurement correction？推理链哪里出问题 |
| STALLED / INCOMPLETE / CRASHED | 🔴 高 | **必须读** | 卡在哪？为什么卡？prompt 是否需调整 |
| 分数大幅正增长（+10 以上）| 🟢 中 | **建议读** | 确认真实新能力 vs 评分宽松，发现路径是否可复制 |
| 连续同维度 ≥3 轮 | 🟡 中 | **建议读最后一轮** | 是否在无效循环？Anti-Stagnation 有无生效 |
| 首次探索某维度 | 🟢 中 | **建议读** | Worker 对该维度的初始理解是否正确 |
| 正常小幅增长（+1~+8）| ⚪ 低 | **可跳过** | evolution-log 摘要够用 |

**固定读取**: 始终读最新可用的 worklog（作为基线对比），加上所有标记为 🔴/🟢/🟡 的轮次

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
