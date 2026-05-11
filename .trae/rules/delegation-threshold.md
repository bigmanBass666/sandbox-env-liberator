# Delegation Threshold Rules

> 来源: fix-evolution-flywheel 实施复盘 — 问题 #4、#8、#9
> 最后更新: 2026-05-11

## 委托原则

当任务超过以下阈值时，**必须**委托给 sub-agent 执行。CSO 只负责:
- 制定修改计划
- 提供具体指令
- 验证执行结果

---

## DT-1: 多位置编辑委托

**规则**: 对同一文件修改超过 **3 处不同位置**时，**必须**委托给 sub-agent 执行。

**判断标准**:
- 同一文件中 3+ 处不同位置的 SearchReplace
- 或累计 3+ 次 SearchReplace（即使位置接近）

**例外**: 简单的单行变量修改（设置默认值、修改字符串）可以自己执行

**正确做法**:
```
# CSO 角色:
1. 制定修改计划（哪 3 处、修改什么、期望结果）
2. 准备详细的编辑指令
3. 委托给 sub-agent 执行
4. 验证 `bash -n` 和 dry-run 结果
```

*→ 防止: 问题 #4（人工批量编辑出错）*

---

## DT-2: 跨文件编辑委托

**规则**: 修改跨越 **2 个及以上文件**时，**必须**委托给 sub-agent 执行。

**判断标准**:
- 涉及 2+ 个不同文件的修改
- 或新增文件到 2+ 个不同目录

**正确做法**:
```
# CSO 角色:
1. 列出所有需要修改的文件
2. 为每个文件准备具体的修改指令
3. 委托给 sub-agent 执行
4. 验证所有文件的 `bash -n` 结果
```

*→ 防止: 文件间一致性遗漏*

---

## DT-3: evolve.sh 核心修改委托

**规则**: 修改 `scripts/evolve.sh` 时，**必须**将具体编辑委托给 sub-agent。

**原因**: evolve.sh 是 1650+ 行的核心脚本，包含:
- 10 个 Phase 的复杂控制流
- 多个 DRY_RUN/fast 路径
- 跨 Phase 的变量依赖
- Git 操作和状态管理

**风险**: 任何结构性错误（嵌套、控制流配对）都可能导致脚本无法运行

**正确做法**:
```
# CSO 角色:
1. 分析需要修改的 Phase
2. 制定修改计划（每处改什么、期望结果）
3. 写出具体的 old_str 和 new_str
4. 委托给 sub-agent 执行
5. 每次 sub-agent 编辑后验证 `bash -n`
6. 验证 dry-run 结果
```

**禁止**: CSO 自己直接在 evolve.sh 上做 SearchReplace

*→ evolve.sh 是核心脚本，风险极高*

---

## DT-4: Git 复杂操作委托

**规则**: 涉及 merge/rebase/cherry-pick 的多步 Git 操作，**必须**委托给 sub-agent 并提供清晰的指令文档。

**判断标准**:
- merge 包含冲突
- rebase 需要手动解决冲突
- cherry-pick 多个 commit
- 涉及分支重建

**正确做法**:
```
# CSO 角色:
1. 确认源分支和目标分支
2. 列出所有需要保留的 commit
3. 制定冲突解决策略（ours vs theirs）
4. 准备详细的 Git 指令
5. 委托给 sub-agent 执行
6. 验证 git log 结构正确
```

**禁止**: CSO 自己执行复杂的 git 操作

*→ 防止: 问题 #8（分支混乱）、#9（cherry-pick 冲突）*

---

## 委托决策树

```
任务需要执行吗?
    │
    ├── 是 → 任务涉及哪些文件/操作?
    │           │
    │           ├── evolve.sh 修改? → 委托给 sub-agent
    │           │
    │           ├── 2+ 个文件? → 委托给 sub-agent
    │           │
    │           ├── 3+ 处编辑（同一文件）? → 委托给 sub-agent
    │           │
    │           ├── Git merge/rebase/cherry-pick? → 委托给 sub-agent
    │           │
    │           └── 以上都不是 → 可以自己执行
    │                       但仍需遵守 L1/L2 验证门禁
    │
    └── 否 → 跳过
```

---

## 委托指令模板

当委托给 sub-agent 时，必须提供以下信息:

```markdown
## 任务描述
[简洁描述要做什么]

## 文件列表
- file1.sh: [修改内容描述]
- file2.md: [修改内容描述]

## 具体编辑指令

### file1.sh
```
old_str:
[包含完整控制流边界的 old_str]

new_str:
[期望的 new_str]
```

### file2.md
[具体修改描述]

## 验证要求
- [ ] `bash -n file1.sh` 通过
- [ ] `bash file1.sh --dry-run` 正常完成
- [ ] [其他验证项]

## 注意事项
- [任何特殊约束或警告]
```

---

## sub-agent 委托示例

**场景**: 需要修改 evolve.sh Phase 7 的 3 处 D1/D5/D6 case

**CSO 准备工作**:
1. 分析 Phase 7 当前结构
2. 制定 3 处修改计划
3. 写出每处具体的 old_str 和 new_str
4. 准备验证步骤

**委托给 sub-agent**:
```markdown
## 任务
修改 scripts/evolve.sh Phase 7，添加 D1/D5/D6 的具体改进路径

## 文件
scripts/evolve.sh

## 编辑指令

### 编辑 1: D1 else 分支
old_str:
[Phase 7 D1 case 的 else 分支代码]

new_str:
[新的 egress bypass 探索代码]

### 编辑 2: D5 case
[类似格式]

### 编辑 3: D6 case
[类似格式]

## 验证步骤
1. 编辑 1 后: `bash -n scripts/evolve.sh`
2. 编辑 2 后: `bash -n scripts/evolve.sh`
3. 编辑 3 后: `bash -n scripts/evolve.sh`
4. 全部完成后: `bash scripts/evolve.sh --dry-run`
```

**sub-agent 执行**:
1. 按顺序执行 3 处编辑
2. 每处编辑后验证 `bash -n`
3. 全部完成后运行 dry-run
4. 报告验证结果
