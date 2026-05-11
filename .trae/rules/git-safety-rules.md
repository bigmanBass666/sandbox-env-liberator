# Git Safety Rules

> 来源: fix-evolution-flywheel 实施复盘 — 问题 #6~#9
> 最后更新: 2026-05-11

## GSR-1: 禁止 git clean -fd（无确认）

**规则**: `git clean -fd` 会永久删除未跟踪的文件和目录。

**使用前必须**:
1. `git clean -fdn` — dry-run 模式预览将被删除的文件列表
2. 确认列表中没有重要文件
3. 获得用户确认（或使用 `git clean -fd --dry-run` 作为最终确认）

**禁止**: 直接执行 `git clean -fd` 而不预览

**替代方案**: 手动 `rm -rf <dir>` 可以逐个确认删除

*→ 防止: 问题 #6（domains/ 和 archive/ 被删除）*

---

## GSR-2: 禁止 git reset --hard 无备份

**规则**: 执行 `git reset --hard` 前**必须**先创建备份分支。

**正确步骤**:
```bash
# 1. 创建备份分支
git branch backup-$(date +%Y%m%d-%H%M%S)

# 2. 保存当前改动（如果有）
git diff > /tmp/my-changes-$(date +%Y%m%d-%H%M%S).patch

# 3. 然后才执行 reset
git reset --hard origin/main
```

*→ 防止: 数据丢失*

---

## GSR-3: Stash 栈深度 ≤ 2

**规则**: 同时存在的 stash 不超过 2 个。

**超过时必须**:
1. 整理（pop 或 drop）
2. 记录每个 stash 的内容描述

**stash 命名规范**: 在 stash 时附带清晰消息
```bash
git stash push -m "fix-evolve: Phase 7 D1 case 修改"
git stash push -m "acs-file-restructure: AGENTS.md + .agents/ 目录"
```

**禁止**: 创建 stash@{0} ~ stash@{4} 而不知道每个包含什么

*→ 防止: 问题 #7（5 个 stash 混淆）*

---

## GSR-4: 单次 Git 操作原子化

**规则**: 一次 git 操作只做一件事。

| 操作类型 | 禁止组合 |
|----------|----------|
| commit | 不要同时 merge/push |
| merge | 不要同时 rebase/push |
| rebase | 不要同时 add/commit |
| push | 不要同时做其他操作 |

**正确做法**: 每次交互只执行一个操作，完成后验证，再做下一个。

*→ 防止: 问题 #8（分支混乱）、#9（cherry-pick 冲突）*

---

## GSR-5: 未提交文件数 ≤ 5

**规则**: 工作区中未提交的修改文件不超过 5 个。

**超过时必须**:
1. 先 commit（哪怕是 partial commit）
2. 再继续新工作

**目的**: 减少合并时的冲突范围

*→ 防止: 大量未提交改动导致的合并灾难*

---

## GSR-6: 分支身份清晰

**规则**: 创建临时分支时**必须**记录以下信息:

| 字段 | 说明 |
|------|------|
| 来源分支 | 从哪个分支创建 |
| 目的 | 这个分支要做什么 |
| 包含内容 | 主要改动文件列表 |
| 生命周期 | 何时合并/删除 |

**禁止**: 创建无明确用途的分支（如 `temp`、`test`、`tmp-clean`）

**正确做法**:
```bash
# 创建时记录
git checkout -b fix-evolve-phase7-d1
# 用途: 修改 Phase 7 D1 case
# 包含: scripts/evolve.sh
# 生命周期: 验证后合并到 worker

git checkout -b acs-file-restructure
# 用途: 重组 .agents/ 目录结构
# 包含: AGENTS.md, .agents/, references/domains/
# 生命周期: 验证后合并到 main
```

*→ 防止: 问题 #8（temp-clean vs merge-worker 混淆）*

---

## Scenario: 需要 reset 到远程状态并重新应用改动

**情境**: 需要执行 `git reset` 来清理本地状态

**执行步骤**:
1. [ ] `git branch backup-$(date +%Y%m%d-%H%M%S)` — 创建备份分支
2. [ ] `git diff > /tmp/my-changes-$(date +%Y%m%d-%H%M%S).patch` — 保存改动到 patch
3. [ ] `git reset --hard origin/main` — 执行 reset
4. [ ] 验证: `git status` 确认工作区干净
5. [ ] 验证: `git log --oneline -3` 确认在正确位置
6. [ ] 应用 patch: `git apply /tmp/my-changes-*.patch`（如需要）
7. [ ] **禁止** 使用 `git clean -fd`

**注意**: 如果 patch 冲突，使用 `git apply --reject --whitespace=nowarn` 逐个文件解决

---

## Scenario: 处理 stash 过多

**情境**: 发现有 >2 个 stash

**执行步骤**:
1. [ ] `git stash list` — 列出所有 stash
2. [ ] `git stash show -p stash@{n}` — 查看每个 stash 的内容
3. [ ] 为每个 stash 决定: pop（应用）、drop（丢弃）、或保留
4. [ ] 合并相关 stash: `git stash pop stash@{n} && git stash push -m "合并描述"`
5. [ ] 确保最终 ≤ 2 个 stash

**决策树**:
- stash 内容需要保留? → pop + commit
- stash 内容不需要? → drop
- stash 内容稍后需要? → 保留（但最多 2 个）

---

## Scenario: 复杂 merge 操作

**情境**: 需要 merge 包含大量改动的分支

**执行步骤**:
1. [ ] `git branch backup-pre-merge-$(date +%Y%m%d)` — 创建备份
2. [ ] `git fetch origin` — 确保远程最新
3. [ ] `git merge --no-commit --no-ff origin/worker` — 开始 merge（不自动 commit）
4. [ ] 如有冲突: `git checkout --theirs <file>` 或 `git checkout --ours <file>` 选择版本
5. [ ] `git add <resolved-files>` — 标记冲突已解决
6. [ ] `git commit` — 完成 merge
7. [ ] 验证: `git log --oneline --graph -5` 确认 merge 结构正确
8. [ ] push: `git push origin main`
