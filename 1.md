I'll check for existing specs related to this worker prompt update.

The user has provided a prompt for a Night Evolution Worker for the sandbox-env-liberator project. This appears to be an update to an existing worker prompt or a new specification for this role.

Let me analyze the user input:
- This is a prompt/worker instruction file that defines how the Night Evolution Worker should operate
- It includes detailed workflow steps (Step 0-5), rules, and emergency handling procedures

According to my instructions, I need to:
1. First check if any change-id matches the user input by looking at existing specs
2. If no match found, write spec.md, tasks.md, and checklist.md
3. Use the Spec mode approach

Let me check if there are any existing specs related to this worker prompt. The user is providing a new/updated worker.md prompt content, which suggests they want to update the worker prompt file.

Looking at the AGENTS.md, there's a reference to `prompts/worker.md` which contains the Night Evolution Worker execution instructions. The user is providing new content for this file.

This appears to be a request to update the worker.md prompt file. Let me check for existing specs first.

No existing specs found. This is a new specification for updating the Night Evolution Worker prompt. I'll create the spec, tasks, and checklist.

The .trae/specs directory doesn't exist yet. This is a new spec, so I need to follow the Spec Mode flow:

1. Write spec.md
2. Write tasks.md
3. Write checklist.md
4. Indicate to user with NotifyUser

The user is asking to update the Night Evolution Worker Prompt (prompts/worker.md). This involves updating an existing file with a detailed new prompt structure.

Let me create the spec document.

Now I need to create the spec directory and write the spec.md file. The user wants to update the worker prompt in `prompts/worker.md`. Let me create a spec that outlines this change.

Looking at the provided prompt content, this is a complete rewrite of the Night Evolution Worker prompt with clearer structure and rules. The changes include:
1. Clearer role definition
2. Stricter permission boundaries
3. Updated execution flow (Step 0: Environment Setup for fresh environments)
4. Enhanced anti-stagnation rules
5. Better GitHub Source of Truth rules
6. Improved Git commit safety standards

Let me write the spec.

Now I need to create tasks.md with ordered implementation steps.

Now I'll write the tasks.md file with concrete implementation steps.

Now I need to write the checklist.md file. Let me complete this task.

Now let me create the checklist.md file.

Now I need to write the spec.md file, which I initially put in tasks.md by mistake. Let me write the proper spec.md.

Now I need to update the todo list and notify the user that the specification is complete.

I've created all the specification documents:
- spec.md - What changes need to be made
- tasks.md - Implementation steps
- checklist.md - Verification checklist

Now I need to notify the user for approval. According to the instructions, I should use NotifyUser to request plan approval.
Specification documents created. Now notifying for approval.

**Specification Summary:**

**Files Created:**
- `/workspace/.trae/specs/update-worker-prompt/spec.md` - Documents the required changes
- `/workspace/.trae/specs/update-worker-prompt/tasks.md` - 4 tasks with subtasks
- `/workspace/.trae/specs/update-worker-prompt/checklist.md` - Verification checklist

**Key Changes Proposed:**

| Change | Description |
|--------|-------------|
| Step 0: Environment Preparation | Clone repo, switch branch, install gh CLI, configure auth, run bootstrap |
| Sole Execution Path | evolve.sh is the only legal path; manual improvements are prohibited |
| Anti-Stagnation Rules | 3 rounds no progress → switch dimension; 2 rounds no growth → deep exploration |
| GitHub Source of Truth | fetch-before-work pattern required |
| Git Commit Safety | No `git add -A`, no test/.log/temp files |
| Emergency Handling | 4 scenarios: timeout, crash, failures, regression |
| Scoring Principles | Measurement Correction vs Discovery Bonus vs New Capability clarified |

**Implementation Plan:**
1. Read current `prompts/worker.md`
2. Rewrite with all specified changes (9 subtasks)
3. Verify against spec requirements

------------------------

开始实施！先读取当前的 worker prompt，然后按照 spec 进行更新。
The user wants me to start implementing the worker prompt update. Let me follow the spec mode instructions - I need to start implementation by delegating to sub-agents.

Let me first read the current prompts/worker.md and then implement the changes.

Let me read the current worker prompt file first.

当前文件已读取完毕。对比用户输入的目标版本，发现以下关键差异需要更新：

| 差异点 | 当前文件 | 目标版本 |
|--------|---------|---------|
| Clone 路径 | `/workspace/sandbox-env-setup` | `/workspace` |
| 缺失章节 | 无 | 🚨 绝对禁止 + 执行路径不可绕过 |
| Step 3 描述 | 简单的"执行进化" | 强调 evolve.sh 为唯一合法路径 |
| 整体结构 | 基本完整 | 需要更强的安全边界语言 |
I can see the current worker prompt. It already has most of the structure from the spec! Let me compare:

1. **Step 0: Environment Preparation** - ✅ Already present (lines 33-65)
2. **Permission boundaries** - ✅ Present but could be clearer
3. **evolve.sh as sole execution path** - ⚠️ Present in Step 3, but not strongly emphasized
4. **Anti-stagnation rules** - ✅ Present (lines 147-152)
5. **GitHub Source of Truth** - ✅ Present (lines 154-158)
6. **Git commit safety** - ✅ Present (lines 160-164)
7. **Scoring principles** - ✅ Present (lines 171-176)
8. **Emergency handling** - ✅ Present (lines 178-190)

The current file already looks very close to the target! The main differences I see:

1. Step 0 uses `/workspace/sandbox-env-setup/` instead of `/workspace` for clone path
2. Missing "绝对禁止" section with stronger language about evolve.sh bypass
3. Some sections could be reorganized with better visual hierarchy

Let me compare more carefully against the user's input. The user's input IS essentially the new version they want. Let me check if there are differences between what's currently in `prompts/worker.md` and what the user provided.

Looking at the user's input vs current file:
- User's input has "🚨 绝对禁止" section that's missing from current file
- User's input has slightly different wording in some places
- The clone path is different: user's input says `/workspace`, current file says `/workspace/sandbox-env-setup`
- User's input has "执行路径不可绕过" section
- Current file already has most content

So the task is to update the existing prompts/worker.md to match the user's desired version. Since this involves a full rewrite of a single file, I should delegate to a sub-agent per the delegation rules (DT-3 doesn't apply since it's not evolve.sh, but DT-2 might apply if we're modifying multiple files... actually this is just one file).

Actually, looking at the rules again:
- This is a single file modification (prompts/worker.md)
- Not evolve.sh, so DT-3 doesn't apply
- Only 1 file, so DT-2 doesn't apply
- But it's a complete rewrite, which is complex

Let me just do this directly since it's a single file write operation.

现在执行完整重写，将 `prompts/worker.md` 更新为目标版本：
Now I need to rewrite the prompts/worker.md file to match the user's target version. This is a single file write, so I can do it directly. Let me write the complete new version based on the user's input.

文件已写入。现在执行验证：
The file has been written successfully. Now I need to:
1. Update tasks.md to mark completed tasks
2. Run the verification checklist

Now I need to verify the updated file against the checklist. Let me delegate this to a sub-agent for systematic verification.

The user wants me to verify the `/workspace/prompts/worker.md` file against a checklist at `/workspace/.trae/specs/update-worker-prompt/checklist.md`. Let me read both files first.

现在我已经读取了两个文件，让我逐项进行详细验证。
Now I have both files. Let me systematically verify each checklist item against the worker.md content. Let me go through each item carefully.

1. **prompts/worker.md exists and readable** - ✅ Just read it successfully, 210 lines
2. **Step 0 has all 5 sub-steps** - Let me check:
   - Clone: L46-48 ✅
   - Branch: L52-54 ✅
   - gh install: L57-62 ✅
   - Auth: L65-67 ✅
   - Bootstrap: L70 ✅
3. **Permission boundaries with "禁止" rules** - L20-23, L27-29 ✅
4. **evolve.sh as sole legal execution path** - L102, L160-162 ✅
5. **Anti-stagnation rules with exact thresholds** - L166-169 ✅ (3 rounds, 2 rounds)
6. **GitHub Source of Truth section** - L172-176 ✅
7. **Git commit safety rules** - L178-182 ✅ (no git add -A, no test/.log)
8. **Scoring principles** - L189-194 ✅ (Measurement Correction, Discovery Bonus, New Capability)
9. **Emergency handling covers 4 scenarios** - L201-204 ✅
10. **Visual separators (═) and clear section headers** - L3-5, L35-37, L154-156, L196-198 ✅
11. **No placeholder text** - Need to check for TODO/TBD etc.
12. **All bash commands syntactically correct** - Need to verify
13. **File path references accurate** - Need to check

Let me also check for placeholder text and verify bash commands and file paths.

现在让我验证文件路径准确性和占位符文本检查：
Now let me verify the file path references and check for placeholder text. I need to verify that all referenced files actually exist in the workspace, and search for any placeholder text like TODO/TBD.

所有验证数据已收集完毕，现在输出完整报告：
Good. Let me analyze the findings:

1. **Placeholder text**: L169 has "TODO 列表" but this is in the context of "Milestones 就是你的 TODO 列表" — this is a descriptive phrase, not a placeholder/TODO marker. It's saying "milestones are your TODO list". This is not a placeholder that needs to be filled in, it's instructional text. So this should PASS.

2. **File paths**: All referenced files exist:
   - scripts/evolve.sh ✅
   - scripts/bootstrap.sh ✅
   - scripts/release-lock.sh ✅
   - references/polaris-score.md ✅
   - references/handoff.md ✅
   - references/evolution-log.md ✅

Now let me compile the full verification report.

---

# 📋 `prompts/worker.md` 验证报告

**验证文件**: [worker.md](file:///workspace/prompts/worker.md)（共 210 行）  
**对照清单**: [checklist.md](file:///workspace/.trae/specs/update-worker-prompt/checklist.md)

---

## ✅ 第 1 项：文件存在且可读 — **PASS**

| 检查项 | 结果 |
|--------|------|
| 文件存在 | ✅ `/workspace/prompts/worker.md` |
| 可读取 | ✅ 成功读取，共 210 行 |

---

## ✅ 第 2 项：Step 0 环境准备 — 全部 5 个子步骤 — **PASS**

| 子步骤 | 内容 | 行号 | 状态 |
|--------|------|------|------|
| **0.1 Clone 仓库** | `git clone https://github.com/bigmanBass666/sandbox-env-liberator.git /workspace`（条件判断 `/workspace/.git` 不存在时执行） | L46-48 | ✅ |
| **0.2 切换 worker 分支** | `git fetch origin` + `git checkout worker` / `git checkout -b worker origin/main` + `git pull` | L52-54 | ✅ |
| **0.3 安装 gh CLI** | 完整安装流程：gpg key → apt source → `apt-get install -y gh`（条件判断 `command -v gh` 不存在时执行） | L57-62 | ✅ |
| **0.4 配置 gh 认证** | 从 git remote URL 提取 token → `gh auth login --with-token`（条件判断 `gh auth status` 失败时执行） | L65-67 | ✅ |
| **0.5 运行 bootstrap** | `bash scripts/bootstrap.sh` | L70 | ✅ |

> 每个 sub-step 都有条件判断保护（`if [ ! -d ... ]` / `if ! command -v ...` / `if ! gh auth status`），不会在已有环境中重复执行。

---

## ✅ 第 3 项：权限边界含"禁止"规则 — **PASS**

证据来源：[L16-29](file:///workspace/prompts/worker.md#L16-L29)

| 规则类型 | 具体内容 | 行号 |
|----------|----------|------|
| ❌ 禁止修改 prompts/ 目录 | "禁止：修改 prompts/ 目录中的任何文件" | L20 |
| ❌ 禁止修改 .agents/ 目录 | "禁止：修改 .agents/ 目录" | L21 |
| ❌ 禁止修改 evolve.sh 架构 | "禁止：修改 evolve.sh 的架构（Phase 结构、计时机制等）" | L22 |
| ❌ 禁止 push 到 main | "禁止：push 到 main 分支（在 worker 分支上工作）" | L23 |
| 🚨 绝对禁止绕过 evolve.sh | "禁止绕过 evolve.sh 手动执行改进（无论任何原因）" | L27 |
| 🚨 禁止自行改 Score 字段 | "禁止自行修改 polaris-score.md 的 Score 字段" | L28 |
| 🚨 禁止重新测量标注 New Capability | "禁止将已知能力重新测量标注为 New Capability" | L29 |

共 **7 条禁止规则**，覆盖全面。

---

## ✅ 第 4 项：evolve.sh 作为唯一合法执行路径 — **PASS**

证据出现在 **3 处**独立位置：

| 位置 | 原文 | 行号 |
|------|------|------|
| Step 3 标题 | "### Step 3: 执行进化（唯一合法路径）" | L100 |
| Step 3 正文 | "⚠️ evolve.sh 是执行改进的唯一合法路径。" | L102 |
| 必须遵守的规则章节 | "evolve.sh 是执行改进的唯一合法路径。如果 evolve.sh 无法运行：" | L160 |
| 失败处理 | "🚨 绝对禁止：绕过 evolve.sh 手动执行改进" | L115 |
| 紧急情况末尾 | "⚠️ evolve.sh 不可用时：只记录，不改进。不要绕过 evolve.sh 手动执行。" | L210 |

**5 次强调**，冗余度充足。

---

## ✅ 第 5 项：反停滞规则精确阈值 — **PASS**

证据来源：[L166-169](file:///workspace/prompts/worker.md#L166-L169)

| 阈值 | 规则原文 | 行号 | 符合要求 |
|------|----------|------|----------|
| **3 轮无进展 → 强制换维度** | "同一维度连续 3 轮无进展 → 必须换维度" | L166 | ✅ 精确匹配 checklist |
| **2 轮总分无增长 → 深度探索** | "连续 2 轮 Polaris 总分无增长 → 深度探索模式" | L167 | ✅ 精确匹配 checklist |
| 补充规则 | "每轮必须至少让 1 个维度 +5%" | L168 | — |
| 补充规则 | "不要因为'不知道做什么'而停止" | L169 | — |

Step 2 中也有交叉引用（[L97](file:///workspace/prompts/worker.md#L97)）：`如果该维度连续 3 轮无进展(看 Streak 列) → 强制换到次低分维度`

---

## ✅ 第 6 项：GitHub Source of Truth 章节 — **PASS**

证据来源：[L172-176](file:///workspace/prompts/worker.md#L172-L176)

```
### GitHub Source of Truth 黄金法则
- GitHub 是唯一真相源 — 本地文件系统只是缓存，可能过期     L173
- 开始任何工作前：git fetch origin && git log --oneline -15 --all   L174
- 找任何产物时：先 git log → 再本地文件系统搜索              L175
- 看到其他轮次的 commit → 先阅读理解 → 再决定是否基于其继续    L176
```

包含 `fetch-before-work` 模式 ✅

---

## ✅ 第 7 项：Git 提交安全规范 — **PASS**

证据来源：[L178-182](file:///workspace/prompts/worker.md#L178-L182) 及 [L142-144](file:///workspace/prompts/worker.md#L142-L144)

| 规则 | 原文 | 行号 | 状态 |
|------|------|------|------|
| git add 前必须 git status | "`git add` 前**必须**先 `git status` 检查暂存区内容" | L179 | ✅ |
| **禁止** git add -A / git add . | "**禁止**: 不要 `git add .` 或 `git add -A` 盲目全量添加" | L181 | ✅ |
| **禁止**测试文件 | "禁止提交: 测试文件(*-test-*）、临时文件(/tmp/)、*.log、crash dump" | L180, L143 | ✅ |
| 精确添加 | "用 `git add <specific files>` 精确添加" | L182 | ✅ |
| 实际示例 | `git add references/ scripts/ # 只 add 特定文件，不要 git add -A` | L144 | ✅ |

Step 5 中还有二次强调（[L142-144](file:///workspace/prompts/worker.md#L142-L144)），双重保障。

---

## ✅ 第 8 项：评分原则三分类 — **PASS**

证据来源：[L189-194](file:///workspace/prompts/worker.md#L189-L194) 及 [L130-133](file:///workspace/prompts/worker.md#L130-L133)

| 分类 | 定义 | 行号 | 状态 |
|------|------|------|------|
| **Measurement Correction** | "更新分数但标注 (measurement correction)，Delta 不计正增长" | L192 | ✅ |
| **Discovery Bonus** | "最多 +5%"（另 L133: "限制 +5%"） | L193, L133 | ✅ |
| **New Capability** | "正常加分" / "正常记录 Delta" | L194, L133 | ✅ |
| 基线原则 | "'重新测量已知状态'不构成加分理由" | L191 | ✅ |

评分原则在 **两个位置** 出现（Step 5 的 L130-133 和规则章的 L189-194），确保 Worker 在操作步骤和规则参考处都能看到。

---

## ✅ 第 9 项：紧急情况处理 4 场景 — **PASS**

证据来源：[L200-204](file:///workspace/prompts/worker.md#L200-L204)

| # | 场景 | 原文 | 行号 | 状态 |
|---|------|------|------|------|
| 1 | evolve.sh 超时 | "evolve.sh 执行超时（>30分钟）" | L201 | ✅ |
| 2 | 环境严重损坏 | "环境严重损坏（bash/node/git 不可用）" | L202 | ✅ |
| 3 | 连续 3 次改进失败 | "连续 3 次改进尝试都失败" | L203 | ✅ |
| 4 | Polaris 分数退步 | "Polaris 分数退步" | L204 | ✅ |

配套处理流程完整（[L206-208](file:///workspace/prompts/worker.md#L206-L208)）：标记 Status → 写 What's Left Undone + Blockers → push → 结束本轮。

---

## ✅ 第 10 项：视觉分隔符 (═) 与清晰章节标题 — **PASS**

文档使用 `═` 分隔符划分 **4 个大区块**：

| 区块 | 行号 | 标题 |
|------|------|------|
| 文件头部横幅 | L3-5 | NIGHT EVOLUTION WORKER — sandbox-env-liberator 夜间自主进化 |
| 执行流程 | L35-37 | 执行流程 |
| 必须遵守的规则 | L154-156 | 必须遵守的规则 |
| 紧急情况处理 | L196-198 | 紧急情况处理 |

二级标题（`##` / `###`）结构清晰：
- `## 你的角色` (L10)、`## 权限边界` (L16)、`## 🚨 绝对禁止` (L25)
- `### Step 0~5` (L39, L73, L89, L100, L117, L123)
- `### 🚨 执行路径不可绕过` (L158)、`### 反停滞规则` (L165) 等

---

## ✅ 第 11 项：无占位符文本 — **PASS**

搜索结果：grep `TODO\|TBD\|FIXME\|待填充\|占位\|placeholder` 仅命中 **1 处**：

> L169: `不要因为"不知道做什么"而停止 — polaris-score.md 的 Milestones 就是你的 TODO 列表`

**判定**：这是指令性文本（将 Milestone 比作 TODO 列表），**非待填充占位符**。文档中不存在需要开发者后续填补的 `TODO`/`TBD`/`FIXME` 占位标记。

---

## ✅ 第 12 项：所有 Bash 命令语法正确 — **PASS**

逐块审查：

| 代码块 | 行号范围 | 语法检查 | 结果 |
|--------|----------|----------|------|
| Step 0 环境准备 | L44-71 | if/fi 配对正确、变量引用规范、管道链完整 | ✅ |
| Step 1 读取状态 | L75-87 | cat/tail/git 命令标准用法 | ✅ |
| Step 3 执行进化 | L104-107 | 单行 bash 命令 | ✅ |
| Step 5 记录退出 | L125-152 | git 命令链正确、注释清晰 | ✅ |

具体验证要点：
- **if/fi 配对**：L46/L48、L57/L62、L65/L67 — 全部正确闭合
- **变量引用**：全部使用双引号包裹（`"$DRY_RUN"` 类模式不适用此处，但 `${var}` 用法正确）
- **管道安全**：`2>/dev/null || true` 用于非关键操作（L54, L61, L67, L151）
- **git 命令**：`git clone`、`git fetch`、`git checkout`、`git pull`、`git add`、`git commit`、`git push`、`git status`、`git log`、`git remote get-url` — 全部标准语法
- **gh CLI**：`gh auth status`、`gh auth login --with-token` — 正确

---

## ✅ 第 13 项：文件路径引用准确 — **PASS**

| 引用路径 | 文件是否存在 | 行号 | 状态 |
|----------|-------------|------|------|
| `scripts/evolve.sh` | ✅ 存在 | L106, L160 | ✅ |
| `scripts/bootstrap.sh` | ✅ 存在 | L70 | ✅ |
| `scripts/release-lock.sh` | ✅ 存在 | L151 | ✅ |
| `references/polaris-score.md` | ✅ 存在 | L77, L97, L128, L169, L191 | ✅ |
| `references/handoff.md` | ✅ 存在 | L80, L136, L201, L207 | ✅ |
| `references/evolution-log.md` | ✅ 存在 | L83, L139 | ✅ |
| `/workspace/.git` | ✅ 存在（目录检测） | L46 | ✅ |
| `/workspace` | ✅ 存在（工作根目录） | L47, L49 | ✅ |

全部 **8 个路径引用** 均指向实际存在的文件或目录。

---

## 📊 总结

| # | 检查项 | 结果 | 备注 |
|---|--------|------|------|
| 1 | 文件存在且可读 | **✅ PASS** | 210 行，完整读取 |
| 2 | Step 0 全部 5 子步骤 | **✅ PASS** | Clone/Branch/gh install/Auth/Bootstrap 全齐 |
| 3 | 权限边界含"禁止"规则 | **✅ PASS** | 7 条禁止规则（4 普通 + 3 绝对禁止） |
| 4 | evolve.sh 唯一合法路径 | **✅ PASS** | 5 次独立强调 |
| 5 | 反停滞规则精确阈值 | **✅ PASS** | 3 轮换维度 + 2 轮深度探索 |
| 6 | GitHub Source of Truth | **✅ PASS** | 含 fetch-before-work 模式 |
| 7 | Git 提交安全规范 | **✅ PASS** | 禁止 git add -A，禁止 test/.log 文件 |
| 8 | 评分原则三分类 | **✅ PASS** | MC / DB(+5%) / NC 三分法完整 |
| 9 | 紧急情况 4 场景 | **✅ PASS** | 超时/环境损坏/3次失败/退步 |
| 10 | 视觉分隔符与标题 | **✅ PASS** | 4 组 ═ 分隔符，层级清晰的 ##/### |
| 11 | 无占位符文本 | **✅ PASS** | 唯一 "TODO" 为比喻性描述，非占位符 |
| 12 | Bash 命令语法正确 | **✅ PASS** | if/fi 配对、管道安全、git 命令标准 |
| 13 | 文件路径引用准确 | **✅ PASS** | 8 个路径全部指向实际存在文件 |

### 最终结论

**13 / 13 全部通过 ✅**

`prompts/worker.md` 完全符合 [`checklist.md`](file:///workspace/.trae/specs/update-worker-prompt/checklist.md) 中的所有实现验证和质量检查要求。
Now let me compile the complete verification report in Chinese.

验证完成！**13/13 全部通过** ✅。现在更新任务状态和检查清单：
All 13 checklist items passed. Let me update the tasks.md and checklist.md to mark everything as completed, then update the todo list.

All tasks are completed. Let me update the tasks.md and checklist.md files to reflect the completion status.

Now let me update the checklist.md to mark all items as completed.

All tasks are completed. Let me provide a final summary to the user.
## ✅ Night Evolution Worker Prompt 更新完成

### 执行总结

| 项目 | 状态 |
|------|------|
| **修改文件** | [prompts/worker.md](file:///workspace/prompts/worker.md) (210 行) |
| **Spec 文档** | [.trae/specs/update-worker-prompt/spec.md](file:///workspace/.trae/specs/update-worker-prompt/spec.md) |
| **任务清单** | [.trae/specs/update-worker-prompt/tasks.md](file:///workspace/.trae/specs/update-worker-prompt/tasks.md) — 4 任务 / 23 子任务 全部完成 ✅ |
| **验证结果** | **13/13 检查项全部通过** |

### 关键变更点

| 变更 | 详情 |
|------|------|
| **Clone 路径修正** | `/workspace/sandbox-env-setup` → `/workspace`（匹配实际工作目录） |
| **🚨 绝对禁止章节** | 新增 3 条硬性禁止规则（绕过 evolve.sh、改 Score 字段、重新测量标注） |
| **执行路径不可绕过** | 新增独立章节，5 次强调 evolve.sh 为唯一合法路径 |
| **Step 3 强化** | 标题改为"执行进化（唯一合法路径）"，增加重试逻辑（修复环境→重新运行→记录退出） |
| **紧急情况末尾** | 新增最终警告："evolve.sh 不可用时：只记录，不改进" |