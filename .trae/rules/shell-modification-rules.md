# Shell Modification Safety Rules

> 来源: fix-evolution-flywheel 实施复盘 — 问题 #1~#5
> 最后更新: 2026-05-11

## Rule 1: 完整上下文读取

**规则**: 修改任何控制流结构（`if`/`while`/`for`/`case`/`function`）时，**必须先**读取从代码块开始到结束的完整范围。

**禁止行为**: 只看局部（10-20行）就插入代码。

**正确做法**:
1. 找到代码块的起始行（如 `while true; do`）和结束行（如 `done`）
2. 读取完整范围
3. 确认控制流配对关系后再编辑

*→ 防止: 问题 #1（DRY_RUN/while 嵌套错误）*

---

## Rule 2: 控制流配对验证

**规则**: 插入或修改 `if`/`while`/`for`/`case` 时，**必须先**写出当前配对关系图和目标配对关系图。

**必须确认**: 嵌套层级是**包裹**而非**交叉**

**正确做法**:
1. 画出当前结构: `if → ... → fi`
2. 画出目标结构: `if → else → while → done → fi`
3. 确认没有: `if → while → ... → if → ... → fi → done`
4. 然后才执行 SearchReplace

```
# 正确 — 包裹:
if [ "$COND" = true ]; then
    while true; do
        ...
    done
fi

# 错误 — 交叉:
if [ "$COND" = true ]; then
    while true; do
        ...
    if [ "$X" = y ]; then
        ...
    fi
    done  # ← done 在内层 fi 之后！
```

*→ 防止: 问题 #1*

---

## Rule 3: 编辑即验证（L1 门禁）

**规则**: 每次 SearchReplace 或 Write 到 .sh 文件后，**必须立即**运行 `bash -n <file>` 验证语法。

| 结果 | 处理 |
|------|------|
| exit code 0 | 继续下一步 |
| exit code ≠ 0 | **立即停止**，不允许任何其他编辑 |

**禁止**: 批量编辑后一次性验证

*→ 防止: 问题 #1、#4*

---

## Rule 4: 编辑批量上限

**规则**: 对同一文件的连续 SearchReplace 不超过 **3 次**。

**达到 3 次后必须**:
1. `bash -n <file>` — 语法门禁
2. `bash <script> --dry-run` — 功能门禁（如适用）
3. 验证通过后方可继续下一批编辑

**目的**: 如果有错误，限制在最近 3 次编辑的范围内

*→ 防止: 问题 #4、#5*

---

## Rule 5: 变量全路径初始化

**规则**: 任何在多个代码路径中被消费的变量，**必须**在函数/Phase 开头统一设置默认值。

**格式**: `VAR="${VAR:-default}"`

**新增变量时必须**:
1. grep 所有消费者位置
2. 确认每条路径都有值
3. 检查 DRY_RUN/fast 路径是否跳过了赋值

*→ 防止: 问题 #2（IMPROVE_SUCCESS unbound）、#3（COMMIT_STATUS unbound）*

---

## Rule 6: DRY_RUN/Fast 路径等价性

**规则**: 存在 DRY_RUN 或 fast 模式的脚本，**必须**确保所有输出变量在跳过执行路径时也有安全默认值。

**检查清单**:
- [ ] `COMMIT_STATUS` 在 DRY_RUN 时 = `"PLAN_ONLY"`
- [ ] `IMPROVE_SUCCESS` 在 DRY_RUN 时 = `false`
- [ ] `CONTINUE_LOOP_COUNT` 在 DRY_RUN 时 = `0`
- [ ] 每个 Phase 输出变量都有默认值

**每条代码路径的输出变量集合必须一致**

*→ 防止: 问题 #2、#3*

---

## Rule 7: 结构变更声明

**规则**: 当编辑涉及 `if`/`else`/`while`/`for`/`case`/`function` 的嵌套关系变化时，**必须**在 SearchReplace 的 old_str 中包含完整的控制流边界。

**正确做法**:
- old_str 包含从开始关键字到闭合关键字的完整范围
- new_str 明确包含 `done` 后紧跟 `fi` 作为闭合标记

```
# old_str 必须包含完整的控制流边界:
old_str='while true; do
    ELAPSED_NOW=$(( $(date +%s) - START_TIME ))
    ...
done'

new_str='if [ "$DRY_RUN" = true ]; then
    echo "skipping"
else
while true; do
    ELAPSED_NOW=$(( $(date +%s) - START_TIME ))
    ...
done
fi'
```

*→ 防止: 问题 #1*

---

## Scenario: 在 while 循环外添加条件判断

**情境**: 需要用 `if [ "$COND" = true ]; then ... fi` 包裹现有 `while true; do ... done`

**执行步骤**:
1. [ ] 读取从 `while true; do` 到 `done` 的完整区域
2. [ ] 写出嵌套图: `if → else → while → done → fi`
3. [ ] SearchReplace 的 old_str 必须包含 `while true; do` 作为起始标记
4. [ ] new_str 必须包含 `done` 后紧跟 `fi` 作为闭合标记
5. [ ] **立即** `bash -n` 验证

**检查点**:
- `fi` 的数量 = `if` 的数量
- `done` 的数量 = `while`/`for` 的数量
- 嵌套层级: `fi` 必须在对应的 `done` 之后

---

## Scenario: 新增 Phase 输出变量

**情境**: 在 Phase N 中新增一个会被后续 Phase 消费的变量

**执行步骤**:
1. [ ] 在 Phase N 开头添加 `VAR="${VAR:-default}"`
2. [ ] grep 所有引用该变量的位置（grep -n "VAR" file.sh）
3. [ ] 确认每条路径都有值
4. [ ] **特别检查** DRY_RUN/fast 路径是否跳过了赋值
5. [ ] `bash -n` 验证

**检查清单**:
- [ ] Phase N 开头有默认值
- [ ] 所有消费者路径都能访问到该变量
- [ ] DRY_RUN 路径不会跳过赋值
