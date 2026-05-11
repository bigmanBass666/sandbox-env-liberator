# Safety Redlines

> 这些是每次操作前**必须检查**的绝对红线。详细规则见 `.agents/rules/` 对应文件。

## Git 安全

### GSR-1: 禁止 git clean -fd（无预览）
**禁止**: 直接执行 `git clean -fd`（会永久删除未跟踪文件/目录）
**正确**: 先 `git clean -fdn` 预览列表，确认无重要文件后再执行
**替代**: 手动 `rm -rf <dir>` 逐个确认删除

### GSR-2: 禁止 git reset --hard 无备份
**禁止**: 无备份直接 `git reset --hard`
**正确**: 先 `git branch backup-$(date +%Y%m%d-%H%M%S)` + `git diff > /tmp/changes.patch`

### GSR-3: Stash 栈深度 ≤ 2
**禁止**: 创建 >2 个 stash 而不整理
**正确**: 超过时 pop/drop 整理，stash 时附带清晰消息（`git stash push -m "描述"`）

### GSR-4: 单次 Git 操作原子化
**禁止**: 一次操作组合多种动作（如 commit+merge、rebase+add）
**正确**: 每次只做一件事，完成验证后再做下一个

### GSR-5: 未提交文件数 ≤ 5
**禁止**: 工作区堆积 >5 个未提交修改
**正确**: 先 partial commit，再继续新工作（减少合并冲突范围）

### GSR-6: 分支身份清晰
**禁止**: 创建无明确用途的分支（如 temp/test/tmp-clean）
**正确**: 记录来源分支、目的、包含内容、生命周期

## evolve.sh 守卫

### ESG-1: 修改必须委托 sub-agent
**禁止**: CSO 直接在 evolve.sh 上做 SearchReplace
**原因**: evolve.sh 是 1650+ 行核心脚本，含 10 Phase 复杂控制流 + DRY_RUN/fast 多路径
**正确**: CSO 制定计划 → 写出 old_str/new_str → 委托 sub-agent 执行 → 验证 bash-n + dry-run

### ESG-2: 编辑后必须 bash -n
**禁止**: 批量编辑后一次性验证
**正确**: 每次 SearchReplace 后立即运行 `bash -n scripts/evolve.sh`
**门禁**: exit code ≠ 0 时**立即停止**，不允许任何其他编辑

### ESG-3: 编辑批量上限 = 3 次
**规则**: 对同一文件的连续 SearchReplace 不超过 3 次
**达到上限时**: 必须先 `bash -n` + `--dry-run` 验证通过后方可继续下一批

### ESG-4: 单逻辑点修改原则
**禁止**: 同时改多处相关代码而不验证
**正确**: 改一处 → `bash -n` → 通过 → 再改下一处

### ESG-5: 变量全路径初始化
**规则**: 跨路径消费的变量必须在 Phase 开头设置默认值：`VAR="${VAR:-default}"`
**检查**: grep 所有消费者位置 → 确认每条路径都有值 → 特别检查 DRY_RUN 是否跳过赋值

### ESG-6: DRY_RUN 路径等价性
**规则**: DRY_RUN 模式跳过执行但保留所有状态变量赋值
**必须确保**: COMMIT_STATUS=PLAN_ONLY, IMPROVE_SUCCESS=false, CONTINUE_LOOP_COUNT=0
**核心**: 每条代码路径的输出变量集合必须一致

### ESG-7: 控制流结构变更必须完整边界
**规则**: 修改 if/while/for/case 嵌套关系时，old_str 必须包含从开始关键字到闭合关键字的完整范围
**验证**: fi 数量 = if 数量；done 数量 = while/for 数量；嵌套层级为包裹而非交叉

## 委托阈值

### DT-1: 同文件 ≥3 处编辑 → 委托
**规则**: 对同一文件修改超过 3 处不同位置时必须委托 sub-agent
**例外**: 简单单行变量修改可自行执行

### DT-2: 跨 ≥2 个文件 → 委托
**规则**: 修改跨越 2 个及以上文件时必须委托 sub-agent

### DT-3: Git 复杂操作 → 委托
**规则**: merge/rebase/cherry-pick 等多步 Git 操作必须委托 sub-agent 并提供清晰指令文档

## Shell 修改安全

### SMR-1: 控制流修改需完整上下文
**禁止**: 只看局部（10-20 行）就插入代码到 if/while/for/case 内
**正确**: 读取从代码块开始到结束的完整范围，确认配对关系后再编辑

## 角色边界

### RB-1: Worker 不修改系统文件
**禁止**: Worker 修改 prompts/、.agents/、evolve.sh 架构
**Worker 可改**: env config, install tools, run evolve.sh, update references/
**Worker 不可做**: push to main

### RB-2: CSO 不直接执行日常进化轮次
**CSO 负责**: 架构设计、系统文件修改、merge worker→main、审查夜间结果

## 认知管理

### CLM-1: 同段代码读取 ≤ 3 次
**禁止**: 第 4 次读取同一段代码（±20 行范围）而不记录结论
**正确**: 第 1 次取关键行号 → 第 2 次确认边界 → 第 3 次画结构图 → 仍未理解则记录结论并求助

### CLM-2: 同题卡住 ≤ 5 分钟
**规则**: 同一问题超 5 分钟未解决时必须三选一：
(a) 向用户提问（架构决策/需求不清）
(b) 选方案并记录假设继续前进（技术路线不确定）
(c) 放弃该子任务（超出能力范围）

### CLM-3: 输出「事实→判断→行动」格式
**禁止**: 自言自语式推理（"让我再看看...嗯...不对..."）
**正确**: 分析结论写为简短的"事实 → 判断 → 行动"格式
