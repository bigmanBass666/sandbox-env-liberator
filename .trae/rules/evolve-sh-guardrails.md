# evolve.sh Core File Guardrails

> 来源: fix-evolution-flywheel 实施复盘
> 最后更新: 2026-05-11

## 特殊地位

`scripts/evolve.sh` 是 Polaris 自主进化系统的核心引擎（1650+ 行），具有以下特点:
- **高风险**: 任何结构性错误（嵌套、控制流配对）都可能导致脚本无法运行
- **多路径**: 包含 DRY_RUN、PLAN_ONLY、COMMITTED 等多种执行路径
- **跨 Phase 依赖**: Phase 之间的变量传递复杂

**根据委托阈值规则 DT-3: evolve.sh 的任何修改都必须委托给 sub-agent 执行。CSO 只负责规划和验证。**

---

## G1: 修改前必做调用链分析

**规则**: 在修改 evolve.sh 之前，**必须**先 grep 所有引用目标变量的位置，理解:
- 谁设置（Set）
- 谁消费（Use）
- 在哪条路径（Path: normal/DRY_RUN/PLAN_ONLY）

**执行步骤**:
```bash
# 1. 找到变量所有出现位置
grep -n "IMPROVE_SUCCESS" scripts/evolve.sh

# 2. 分类: set vs use
# 3. 确认每条路径都设置了值
# 4. 检查 DRY_RUN 路径是否跳过赋值
```

**禁止**: 直接修改而不知道变量的完整生命周期

---

## G2: 单逻辑点修改原则

**规则**: 一次 SearchReplace 只改一个逻辑点。验证通过后再改下一个。

**正确做法**:
```
修改 1: D1 case 的 else 分支 → `bash -n` → 验证通过
修改 2: D5 case 新增 → `bash -n` → 验证通过
修改 3: D6 case 新增 → `bash -n` → 验证通过
修改 4: 通用 fallback 修改 → `bash -n` → 验证通过
```

**禁止**: 同时改多处相关代码而不验证

---

## G3: Phase 边界清晰

**规则**: 每个 Phase 的输出变量列表**必须**在 Phase 开头声明默认值。

**Phase 输出变量清单**:

| Phase | 输出变量 | 默认值 | 消费者 |
|-------|----------|--------|--------|
| Phase 0.1 | BRANCH_NAME | "worker" | Phase 8 git push |
| Phase 2 | VERIFY_PASS, VERIFY_FAIL | 0 | Phase 6 Integration |
| Phase 4 | POLARIS_FOCUS_DIM, POLARIS_FOCUS_SCORE | "" | Phase 7 |
| Phase 6 | RECOMMENDED_FOCUS | "" | Phase 7 |
| Phase 7 | IMPROVE_SUCCESS, COMMIT_STATUS | false/PLAN_ONLY | Phase 8 |
| Phase 7 | CONTINUE_LOOP_COUNT | 0 | Phase 8 report |
| Phase 8 | EVOLUTION_LOGGED | true | Phase 9 |

**禁止**: 跨 Phase 隐式依赖（如假设 Phase 7 一定设置了某变量）

---

## G4: DRY_RUN 安全网

**规则**: DRY_RUN 模式**必须**跳过执行但保留所有状态变量赋值。

**DRY_RUN 路径必须设置**:
```bash
# Phase 7 开头（任何代码路径之前）
COMMIT_STATUS="${COMMIT_STATUS:-PLAN_ONLY}"
IMPROVE_SUCCESS="${IMPROVE_SUCCESS:-false}"
CONTINUE_LOOP_COUNT="${CONTINUE_LOOP_COUNT:-0}"
```

**每条路径必须一致**:
- DRY_RUN 路径: IMPROVE_SUCCESS=false, COMMIT_STATUS=PLAN_ONLY
- Normal 路径: 根据执行结果设置真实值
- 两者都必须设置相同的变量集合

---

## G5: continue-loop 特殊守护

**规则**: continue-loop（Phase 7 末尾的 while 循环）**必须**:
1. 位于 Phase 7 的 DRY_RUN if/else 块**之外**
2. 有独立的 DRY_RUN 检查
3. 在 DRY_RUN 时跳过整个循环

**正确结构**:
```bash
# Phase 7 DRY_RUN 块结束后:
if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN: skipping continue-loop"
else
while true; do
    # ... loop body ...
done
fi  # ← 必须有 fi 关闭 DRY_RUN if
```

---

## G6: 控制流配对图

**Phase 7 完整结构**（用于参考）:

```
phase_start "7"
COMMIT_STATUS="${COMMIT_STATUS:-PLAN_ONLY}"     # ← 必须设置默认值
IMPROVE_SUCCESS="${IMPROVE_SUCCESS:-false}"    # ← 必须设置默认值

if [ "$DRY_RUN" = true ]; then
    # DRY_RUN 跳过消息
else
    # === 正常执行路径 ===
    if [ "$POLARIS_FOCUS_DIM" = "D1" ]; then
        if milestone match "speed|100KB"; then
            # mirror speed test
            IMPROVE_SUCCESS=...
        else
            # egress bypass exploration
            IMPROVE_SUCCESS=...
        fi
    elif [ "$POLARIS_FOCUS_DIM" = "D5" ]; then
        # MCP injection
        IMPROVE_SUCCESS=...
    elif [ "$POLARIS_FOCUS_DIM" = "D6" ]; then
        # time utilization
        IMPROVE_SUCCESS=...
    fi

    # VERIFY & COMMIT
    if [ "$IMPROVE_SUCCESS" = true ]; then
        COMMIT_STATUS="COMMITTED"
    else
        COMMIT_STATUS="SKIPPED"
    fi
fi  # ← 关闭 DRY_RUN if

phase_end "7"

# === continue-loop（在 DRY_RUN 块外部！）===
if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN: skipping continue-loop"
else
while true; do
    # ... loop body ...
done
fi  # ← 必须有 fi 关闭 DRY_RUN if
```

---

## G7: 当前已知风险点

### 已修复（已确认仍正确）

| # | 风险点 | 修复 | 状态 | 验证 |
|---|--------|------|------|------|
| 1 | DRY_RUN/while 嵌套错误 | `fi` 在 `done` 后添加 | ✅ | 语法检查通过 |
| 2 | IMPROVE_SUCCESS unbound | Phase 7 L1021 设置默认值 | ✅ | grep 确认 |
| 3 | COMMIT_STATUS unbound | Phase 7 L1020 设置默认值 | ✅ | grep 确认 |
| 4 | continue-loop DRY_RUN 检查 | L1227 独立检查 | ✅ | 语法检查通过 |

### 排查结果（2026-05-11）

| 检查项 | 结果 |
|--------|------|
| 4 个 DRY_RUN 块的 fi 配对 | ✅ 全部正确 |
| IMPROVE_SUCCESS 默认值 | ✅ L1021 设置 false |
| COMMIT_STATUS 默认值 | ✅ L1020 设置 PLAN_ONLY |
| VERIFY_PASS/FAIL 默认值 | ✅ L407-408, L422-423 |
| POLARIS_FOCUS_DIM 默认值 | ✅ L316-317, L324-325 |
| continue-loop IMPROVE_SUCCESS | ✅ 在循环体内正确设置 |
| Phase 8 write_handoff 变量 | ✅ 被调用时变量已初始化 |
| 语法检查 | ✅ `bash -n` 通过 |

---

## 修改检查表

**每次修改 evolve.sh 前**:
- [ ] 我 grep 了目标变量的所有出现位置吗？
- [ ] 我确认了变量的 set/use/path 吗？
- [ ] 我在 Phase 开头设置了必要的默认值吗？
- [ ] 我画出了控制流配对图吗？
- [ ] 我准备了具体的 old_str 和 new_str 吗？
- [ ] 编辑后我会立即 `bash -n` 验证吗？

**每次修改 evolve.sh 后**:
- [ ] `bash -n scripts/evolve.sh` 通过了吗？
- [ ] `bash scripts/evolve.sh --dry-run` 正常完成了吗？
- [ ] Phase 8 是否到达？
- [ ] 时间报告是否正常输出？
- [ ] 没有任何 "unbound variable" 错误吗？
