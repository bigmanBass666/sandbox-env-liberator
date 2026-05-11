# .trae/rules — AI 工作规则索引

> 本目录包含所有强制执行的代码修改安全协议
> 整理自: fix-evolution-flywheel 实施复盘 (2026-05-11)
> **适用对象**: 所有 AI Agent

## 规则文件

| 文件 | 规则数 | 适用范围 |
|------|--------|----------|
| [shell-modification-rules.md](shell-modification-rules.md) | 7 条规则 | 所有 Shell 脚本修改 |
| [git-safety-rules.md](git-safety-rules.md) | 6 条规则 | 所有 Git 操作 |
| [cognitive-load-management.md](cognitive-load-management.md) | 4 条规则 | 复杂任务决策 |
| [delegation-threshold.md](delegation-threshold.md) | 4 条规则 | sub-agent 委托 |
| [evolve-sh-guardrails.md](evolve-sh-guardrails.md) | 7 条规则 | evolve.sh 特殊守护 |

---

## 三级验证门禁（强制执行）

| 门禁 | 时机 | 命令 | 未通过后果 |
|------|------|------|------------|
| **L1** | 每次 .sh 编辑后 | `bash -n <file>` | **禁止继续任何编辑** |
| **L2** | 每 3 次编辑或 Task 完成 | `bash -n` + `--dry-run` | **禁止开始下一个 Task** |
| **L3** | 所有 Task 完成 | 完整 dry-run | **禁止 git commit** |

---

## 决策规则

### 规则 1: Shell 脚本修改

**IF** 修改任何 .sh 文件 **THEN**:
1. 立即运行 `bash -n <file>`
2. **IF** exit code ≠ 0 **THEN** 停止并修复

**IF** 修改涉及 `if`/`while`/`for`/`case` 嵌套 **THEN**:
1. 读取完整代码块
2. 画出配对关系图
3. 确认后执行编辑

### 规则 2: Git 操作

**IF** 执行 `git clean -fd` **THEN**: ❌ 禁止！用 `git clean -fdn` 预览

**IF** 执行 `git reset --hard` **THEN**:
1. 先 `git branch backup-<date>`
2. `git diff > /tmp/changes.patch`
3. 然后执行 reset

**IF** stash 数量 > 2 **THEN**: 整理到 ≤ 2 个

### 规则 3: 认知负载

**IF** 同一问题卡住 > 5 分钟 **THEN**:
- (a) 问用户
- (b) 选方案 + 记录假设
- (c) 放弃该子任务

**IF** 同一代码段读取 > 3 次 **THEN**: 记录结论并继续

### 规则 4: 委托阈值

**IF** 满足任一条件 **THEN** 委托给 sub-agent:
- evolve.sh 修改
- 2+ 个文件修改
- 3+ 处编辑（同文件）
- Git merge/rebase/cherry-pick

---

## 问题对照表

| 问题代码 | 描述 | 规则 |
|----------|------|------|
| P0-1 | DRY_RUN/while 嵌套语法错误 | Rule 1, 2, 3 |
| P0-2 | IMPROVE_SUCCESS unbound | Rule 5, 6 |
| P0-3 | COMMIT_STATUS unbound | Rule 5, 6 |
| P1-4 | 连续多次编辑无语法检查 | L1 门禁 |
| P1-5 | 无增量验证 | L2 门禁 |
| P2-6 | git clean 删除文件 | GSR-1 |
| P2-7 | stash 栈过深 | GSR-3 |
| P2-8 | 临时分支迷失 | GSR-6 |
| P2-9 | cherry-pick 冲突 | GSR-4 |
| P3-10 | 重复读取代码 | CLM-3 |
| P3-11 | 循环思考 | CLM-2 |
| P3-12 | 输出误读 | CLM-4 |

---

## 规则优先级

1. **L1/L2/L3 门禁** — 禁止违反
2. **委托阈值** — 超过必须委托
3. **Git 安全** — 危险命令禁止
4. **Shell 修改** — 推荐实践
5. **认知管理** — 效率优化
