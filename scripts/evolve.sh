#!/bin/bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🏃 DRY-RUN 模式：只生成计划，不执行改进${NC}"
fi

SCRIPTS_DIR="/workspace/sandbox-env-setup/scripts"
REFERENCES_DIR="/workspace/sandbox-env-setup/references"
EVOLUTION_LOG="${REFERENCES_DIR}/evolution-log.md"
RECON_DIR="/tmp/sandbox-recon"
DEEP_RECON_DIR="/tmp/sandbox-deep-recon"
EVOLVE_STATE_DIR="/tmp/sandbox-evolve"
TIMEOUT_SECS=120

START_TIME=$(date +%s)
TIME_BUDGET=1800
RECON_BUDGET=300

LOCK_HELD=false

check_time() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    local remaining=$(( TIME_BUDGET - elapsed ))
    if [ $remaining -le 0 ]; then
        echo -e "${RED}⚠️ 时间预算耗尽！强制进入提交阶段${NC}"
        return 1
    fi
    echo -e "${CYAN}  ⏱️  已用 ${elapsed}s / ${TIME_BUDGET}s（剩余 ${remaining}s）${NC}"
    return 0
}

check_recon_time() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    if [ $elapsed -ge $RECON_BUDGET ]; then
        echo -e "${YELLOW}⚠️ 侦察阶段超过 ${RECON_BUDGET}s，跳过后续侦察${NC}"
        return 1
    fi
    return 0
}

release_lock_on_exit() {
    if [ "$LOCK_HELD" = true ]; then
        echo -e "${YELLOW}🔓 释放分布式锁（退出清理）...${NC}"
        bash "$SCRIPTS_DIR/release-lock.sh" 2>/dev/null || true
        LOCK_HELD=false
    fi
}

trap release_lock_on_exit EXIT

mkdir -p "$EVOLVE_STATE_DIR"

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   EVOLUTION ENGINE - IMPROVEMENT FLYWHEEL            ║${NC}"
echo -e "${BOLD}${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                           ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# 0. DISTRIBUTED LOCK ACQUISITION
# ============================================================
echo -e "${CYAN}━━━ Phase 0: 分布式锁获取 ━━━${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  DRY-RUN: 跳过锁获取${NC}"
else
    if ! bash "$SCRIPTS_DIR/acquire-lock.sh"; then
        echo -e "${YELLOW}🔄 本轮跳过：锁被占用${NC}"
        exit 1
    fi
    LOCK_HELD=true
    echo -e "${GREEN}  锁获取成功，开始飞轮${NC}"
fi

echo ""

# ============================================================
# 1. EVOLUTION STATE READING
# ============================================================
echo -e "${CYAN}━━━ Phase 1: Evolution State Reading ━━━${NC}"

if [ -f "$EVOLUTION_LOG" ]; then
    LAST_ROUND=$(grep -oP 'Round\s+\K\d+' "$EVOLUTION_LOG" 2>/dev/null | sort -rn | head -1 || echo 0)
    if [ -z "$LAST_ROUND" ]; then
        LAST_ROUND=0
    fi
    echo -e "${GREEN}  Evolution log found: last round = ${LAST_ROUND}${NC}"
else
    LAST_ROUND=0
    echo -e "${YELLOW}  No evolution log found, starting at Round 0${NC}"
fi

PREV_RECON_STATE="${EVOLVE_STATE_DIR}/prev_recon_state.txt"
PREV_VERIFY_STATE="${EVOLVE_STATE_DIR}/prev_verify_state.txt"

if [ -f "$RECON_DIR/results.txt" ]; then
    PREV_RECON_PASS=$(grep -c "^PASS|" "$RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_RECON_FAIL=$(grep -c "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_RECON_WARN=$(grep -c "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_RECON_PASS=${PREV_RECON_PASS:-0}
    PREV_RECON_FAIL=${PREV_RECON_FAIL:-0}
    PREV_RECON_WARN=${PREV_RECON_WARN:-0}
    echo -e "${CYAN}  Previous full-recon: PASS=${PREV_RECON_PASS}, FAIL=${PREV_RECON_FAIL}, WARN=${PREV_RECON_WARN}${NC}"
    cp "$RECON_DIR/results.txt" "${EVOLVE_STATE_DIR}/prev_full_recon_results.txt" 2>/dev/null || true
else
    PREV_RECON_PASS=0
    PREV_RECON_FAIL=0
    PREV_RECON_WARN=0
    echo -e "${YELLOW}  No previous full-recon results found${NC}"
fi

if [ -f "$DEEP_RECON_DIR/results.txt" ]; then
    PREV_DEEP_PASS=$(grep -c "^PASS|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_DEEP_FAIL=$(grep -c "^FAIL|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_DEEP_WARN=$(grep -c "^WARN|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
    PREV_DEEP_PASS=${PREV_DEEP_PASS:-0}
    PREV_DEEP_FAIL=${PREV_DEEP_FAIL:-0}
    PREV_DEEP_WARN=${PREV_DEEP_WARN:-0}
    echo -e "${CYAN}  Previous deep-recon: PASS=${PREV_DEEP_PASS}, FAIL=${PREV_DEEP_FAIL}, WARN=${PREV_DEEP_WARN}${NC}"
    cp "$DEEP_RECON_DIR/results.txt" "${EVOLVE_STATE_DIR}/prev_deep_recon_results.txt" 2>/dev/null || true
else
    PREV_DEEP_PASS=0
    PREV_DEEP_FAIL=0
    PREV_DEEP_WARN=0
    echo -e "${YELLOW}  No previous deep-recon results found${NC}"
fi

PREV_PASS=$((PREV_RECON_PASS + PREV_DEEP_PASS))
PREV_FAIL=$((PREV_RECON_FAIL + PREV_DEEP_FAIL))
PREV_WARN=$((PREV_RECON_WARN + PREV_DEEP_WARN))

PREV_FAIL_ITEMS="${EVOLVE_STATE_DIR}/prev_fail_items.txt"
PREV_WARN_ITEMS="${EVOLVE_STATE_DIR}/prev_warn_items.txt"
> "$PREV_FAIL_ITEMS" 2>/dev/null
> "$PREV_WARN_ITEMS" 2>/dev/null

if [ -f "$RECON_DIR/results.txt" ]; then
    grep "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_FAIL_ITEMS"
    grep "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_WARN_ITEMS"
fi
if [ -f "$DEEP_RECON_DIR/results.txt" ]; then
    grep "^FAIL|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_FAIL_ITEMS"
    grep "^WARN|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_WARN_ITEMS"
fi

echo ""

# ============================================================
# 2. CURRENT ENVIRONMENT SNAPSHOT
# ============================================================
echo -e "${CYAN}━━━ Phase 2: Current Environment Snapshot ━━━${NC}"

echo -e "${CYAN}  Running full-recon.sh...${NC}"
FULL_RECON_OUTPUT=$(timeout $TIMEOUT_SECS bash "$SCRIPTS_DIR/full-recon.sh" 2>&1) || true
FULL_RECON_SUMMARY=$(echo "$FULL_RECON_OUTPUT" | grep -E "✅ PASS:|❌ FAIL:|⚠️  WARN:|ℹ️  INFO:" | tail -4)
echo -e "${GREEN}  full-recon.sh complete${NC}"
echo "$FULL_RECON_SUMMARY" | sed 's/^/    /'

if ! check_recon_time; then
    echo -e "${YELLOW}  跳过 deep-recon（侦察时间预算耗尽）${NC}"
    DEEP_RECON_OUTPUT=""
else
    echo ""
    echo -e "${CYAN}  Running deep-recon.sh...${NC}"
    DEEP_RECON_OUTPUT=$(timeout $TIMEOUT_SECS bash "$SCRIPTS_DIR/deep-recon.sh" 2>&1) || true
    DEEP_RECON_SUMMARY=$(echo "$DEEP_RECON_OUTPUT" | grep -E "✅ PASS:|❌ FAIL:|⚠️  WARN:|ℹ️  INFO:" | tail -4)
    echo -e "${GREEN}  deep-recon.sh complete${NC}"
    echo "$DEEP_RECON_SUMMARY" | sed 's/^/    /'
fi

if ! check_time; then
    echo -e "${RED}  时间预算耗尽，跳过后续验证，直接进入提交阶段${NC}"
    VERIFY_PASS=0
    VERIFY_FAIL=0
    VERIFY_TOTAL=0
    HEALTH_OK=0
    HEALTH_WARN=0
    HEALTH_CRIT=0
else
    echo ""
    echo -e "${CYAN}  Running verify-env.sh...${NC}"
    VERIFY_OUTPUT=$(timeout $TIMEOUT_SECS bash "$SCRIPTS_DIR/verify-env.sh" 2>&1) || true
    VERIFY_PASS=$(echo "$VERIFY_OUTPUT" | grep -oP 'Passed:\s+\K\d+' 2>/dev/null || true)
    VERIFY_FAIL=$(echo "$VERIFY_OUTPUT" | grep -oP 'Failed:\s+\K\d+' 2>/dev/null || true)
    VERIFY_TOTAL=$(echo "$VERIFY_OUTPUT" | grep -oP 'Total checks:\s+\K\d+' 2>/dev/null || true)
    VERIFY_PASS=${VERIFY_PASS:-0}
    VERIFY_FAIL=${VERIFY_FAIL:-0}
    VERIFY_TOTAL=${VERIFY_TOTAL:-0}
    echo -e "${GREEN}  verify-env.sh complete: Total=${VERIFY_TOTAL}, PASS=${VERIFY_PASS}, FAIL=${VERIFY_FAIL}${NC}"

    echo ""
    echo -e "${CYAN}  Running health-monitor.sh...${NC}"
    HEALTH_OUTPUT=$(timeout $TIMEOUT_SECS bash "$SCRIPTS_DIR/health-monitor.sh" 2>&1) || true
    HEALTH_OK=$(echo "$HEALTH_OUTPUT" | grep -oP '正常:\s+\K\d+' 2>/dev/null || true)
    HEALTH_WARN=$(echo "$HEALTH_OUTPUT" | grep -oP '警告:\s+\K\d+' 2>/dev/null || true)
    HEALTH_CRIT=$(echo "$HEALTH_OUTPUT" | grep -oP '严重:\s+\K\d+' 2>/dev/null || true)
    HEALTH_OK=${HEALTH_OK:-0}
    HEALTH_WARN=${HEALTH_WARN:-0}
    HEALTH_CRIT=${HEALTH_CRIT:-0}
    echo -e "${GREEN}  health-monitor.sh complete: OK=${HEALTH_OK}, WARN=${HEALTH_WARN}, CRITICAL=${HEALTH_CRIT}${NC}"
fi

echo ""

# ============================================================
# 3. DIFF COMPARISON
# ============================================================
echo -e "${CYAN}━━━ Phase 3: Diff Comparison ━━━${NC}"

CURR_RECON_PASS=$(grep -c "^PASS|" "$RECON_DIR/results.txt" 2>/dev/null || true)
CURR_RECON_FAIL=$(grep -c "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null || true)
CURR_RECON_WARN=$(grep -c "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null || true)
CURR_RECON_PASS=${CURR_RECON_PASS:-0}
CURR_RECON_FAIL=${CURR_RECON_FAIL:-0}
CURR_RECON_WARN=${CURR_RECON_WARN:-0}

CURR_DEEP_PASS=$(grep -c "^PASS|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
CURR_DEEP_FAIL=$(grep -c "^FAIL|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
CURR_DEEP_WARN=$(grep -c "^WARN|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null || true)
CURR_DEEP_PASS=${CURR_DEEP_PASS:-0}
CURR_DEEP_FAIL=${CURR_DEEP_FAIL:-0}
CURR_DEEP_WARN=${CURR_DEEP_WARN:-0}

CURR_PASS=$((CURR_RECON_PASS + CURR_DEEP_PASS))
CURR_FAIL=$((CURR_RECON_FAIL + CURR_DEEP_FAIL))
CURR_WARN=$((CURR_RECON_WARN + CURR_DEEP_WARN))

DELTA_PASS=$((CURR_PASS - PREV_PASS))
DELTA_FAIL=$((CURR_FAIL - PREV_FAIL))

CURR_FAIL_ITEMS="${EVOLVE_STATE_DIR}/curr_fail_items.txt"
CURR_WARN_ITEMS="${EVOLVE_STATE_DIR}/curr_warn_items.txt"
> "$CURR_FAIL_ITEMS" 2>/dev/null
> "$CURR_WARN_ITEMS" 2>/dev/null

if [ -f "$RECON_DIR/results.txt" ]; then
    grep "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_FAIL_ITEMS"
    grep "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_WARN_ITEMS"
fi
if [ -f "$DEEP_RECON_DIR/results.txt" ]; then
    grep "^FAIL|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_FAIL_ITEMS"
    grep "^WARN|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_WARN_ITEMS"
fi

NEW_FAIL_ITEMS="${EVOLVE_STATE_DIR}/new_fail_items.txt"
RECOVERED_ITEMS="${EVOLVE_STATE_DIR}/recovered_items.txt"
NEW_CAPABILITY_ITEMS="${EVOLVE_STATE_DIR}/new_capability_items.txt"
> "$NEW_FAIL_ITEMS" 2>/dev/null
> "$RECOVERED_ITEMS" 2>/dev/null
> "$NEW_CAPABILITY_ITEMS" 2>/dev/null

while IFS= read -r item; do
    [ -z "$item" ] && continue
    if ! grep -qF "$item" "$PREV_FAIL_ITEMS" 2>/dev/null; then
        echo "$item" >> "$NEW_FAIL_ITEMS"
    fi
done < "$CURR_FAIL_ITEMS"

while IFS= read -r item; do
    [ -z "$item" ] && continue
    if ! grep -qF "$item" "$CURR_FAIL_ITEMS" 2>/dev/null; then
        echo "$item" >> "$RECOVERED_ITEMS"
    fi
done < "$PREV_FAIL_ITEMS"

PREV_PASS_ITEMS="${EVOLVE_STATE_DIR}/prev_pass_items.txt"
CURR_PASS_ITEMS="${EVOLVE_STATE_DIR}/curr_pass_items.txt"
> "$PREV_PASS_ITEMS" 2>/dev/null
> "$CURR_PASS_ITEMS" 2>/dev/null

if [ -f "${EVOLVE_STATE_DIR}/prev_full_recon_results.txt" ]; then
    grep "^PASS|" "${EVOLVE_STATE_DIR}/prev_full_recon_results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_PASS_ITEMS"
fi
if [ -f "${EVOLVE_STATE_DIR}/prev_deep_recon_results.txt" ]; then
    grep "^PASS|" "${EVOLVE_STATE_DIR}/prev_deep_recon_results.txt" 2>/dev/null | cut -d'|' -f2- >> "$PREV_PASS_ITEMS"
fi

if [ -f "$RECON_DIR/results.txt" ]; then
    grep "^PASS|" "$RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_PASS_ITEMS"
fi
if [ -f "$DEEP_RECON_DIR/results.txt" ]; then
    grep "^PASS|" "$DEEP_RECON_DIR/results.txt" 2>/dev/null | cut -d'|' -f2- >> "$CURR_PASS_ITEMS"
fi

while IFS= read -r item; do
    [ -z "$item" ] && continue
    if ! grep -qF "$item" "$PREV_PASS_ITEMS" 2>/dev/null; then
        echo "$item" >> "$NEW_CAPABILITY_ITEMS"
    fi
done < "$CURR_PASS_ITEMS"

NEW_FAIL_COUNT=$(wc -l < "$NEW_FAIL_ITEMS" 2>/dev/null)
RECOVERED_COUNT=$(wc -l < "$RECOVERED_ITEMS" 2>/dev/null)
NEW_CAP_COUNT=$(wc -l < "$NEW_CAPABILITY_ITEMS" 2>/dev/null)
NEW_FAIL_COUNT=${NEW_FAIL_COUNT:-0}
RECOVERED_COUNT=${RECOVERED_COUNT:-0}
NEW_CAP_COUNT=${NEW_CAP_COUNT:-0}
NEW_FAIL_COUNT=$(echo "$NEW_FAIL_COUNT" | tr -d '[:space:]')
RECOVERED_COUNT=$(echo "$RECOVERED_COUNT" | tr -d '[:space:]')
NEW_CAP_COUNT=$(echo "$NEW_CAP_COUNT" | tr -d '[:space:]')

echo -e "  Current State:  PASS=${CURR_PASS}, FAIL=${CURR_FAIL}, WARN=${CURR_WARN}"
echo -e "  Previous State: PASS=${PREV_PASS}, FAIL=${PREV_FAIL}, WARN=${PREV_WARN}"

if [ "$DELTA_PASS" -ge 0 ]; then
    echo -e "  Delta: ${GREEN}+${DELTA_PASS} PASS${NC}, ${RED}${DELTA_FAIL} FAIL${NC}"
else
    echo -e "  Delta: ${RED}${DELTA_PASS} PASS${NC}, ${RED}${DELTA_FAIL} FAIL${NC}"
fi

if [ "$NEW_FAIL_COUNT" -gt 0 ]; then
    echo -e "  ${RED}New FAIL items: ${NEW_FAIL_COUNT}${NC}"
    head -5 "$NEW_FAIL_ITEMS" | sed 's/^/    /'
    [ "$NEW_FAIL_COUNT" -gt 5 ] && echo -e "    ... and $((NEW_FAIL_COUNT - 5)) more"
fi

if [ "$RECOVERED_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}Recovered items: ${RECOVERED_COUNT}${NC}"
    head -5 "$RECOVERED_ITEMS" | sed 's/^/    /'
    [ "$RECOVERED_COUNT" -gt 5 ] && echo -e "    ... and $((RECOVERED_COUNT - 5)) more"
fi

if [ "$NEW_CAP_COUNT" -gt 0 ]; then
    echo -e "  ${CYAN}New capabilities: ${NEW_CAP_COUNT}${NC}"
    head -5 "$NEW_CAPABILITY_ITEMS" | sed 's/^/    /'
    [ "$NEW_CAP_COUNT" -gt 5 ] && echo -e "    ... and $((NEW_CAP_COUNT - 5)) more"
fi

echo ""

# ============================================================
# 4. IMPROVEMENT SUGGESTION GENERATION
# ============================================================
echo -e "${CYAN}━━━ Phase 4: Improvement Suggestion Generation ━━━${NC}"
check_time || true

BLOCKER_KEYWORDS="browser|chrome|chromium|network.*block|dns.*block|curl.*block|wget.*block|fetch.*fail|不可用|全断|not available|NOT FOUND"
EFFICIENCY_KEYWORDS="disk.*space|磁盘|内存|memory.*high|cpu.*high|service.*down|不可达|NOT DETECTED|NOT RUNNING|NOT IN PATH"
DISCOVERY_KEYWORDS="new port|unknown|未测试|❓|NOT INSTALLED|NOT FOUND|new service|timeout"
ENHANCEMENT_KEYWORDS="speed|速度|efficiency|效率|optimize|优化|faster|cache"

classify_fail_item() {
    local item="$1"
    if echo "$item" | grep -qiE "$BLOCKER_KEYWORDS"; then
        echo "P0"
    elif echo "$item" | grep -qiE "$EFFICIENCY_KEYWORDS"; then
        echo "P1"
    else
        echo "P0"
    fi
}

classify_warn_item() {
    local item="$1"
    if echo "$item" | grep -qiE "$EFFICIENCY_KEYWORDS"; then
        echo "P1"
    elif echo "$item" | grep -qiE "$DISCOVERY_KEYWORDS"; then
        echo "P2"
    else
        echo "P1"
    fi
}

estimate_difficulty() {
    local item="$1"
    if echo "$item" | grep -qiE "install|安装|setup|配置"; then
        echo "低"
    elif echo "$item" | grep -qiE "network|网络|proxy|代理|dns|firewall|防火墙"; then
        echo "高"
    elif echo "$item" | grep -qiE "compile|编译|build|构建|library|库"; then
        echo "中"
    else
        echo "中"
    fi
}

generate_effect() {
    local item="$1"
    local priority="$2"
    case "$priority" in
        P0) echo "解除基本工作阻塞" ;;
        P1) echo "恢复关键服务可用性" ;;
        P2) echo "扩展环境能力边界" ;;
        P3) echo "提升工作效率" ;;
        P4) echo "改进侦察与验证流程" ;;
    esac
}

P0_ITEMS=""
P1_ITEMS=""
P2_ITEMS=""
P3_ITEMS=""
P4_ITEMS=""
P0_COUNT=0
P1_COUNT=0
P2_COUNT=0
P3_COUNT=0
P4_COUNT=0

while IFS= read -r item; do
    [ -z "$item" ] && continue
    priority=$(classify_fail_item "$item")
    difficulty=$(estimate_difficulty "$item")
    effect=$(generate_effect "$item" "$priority")
    case "$priority" in
        P0)
            P0_COUNT=$((P0_COUNT + 1))
            P0_ITEMS="${P0_ITEMS}${P0_COUNT}. [${item}] → ${effect} | 难度:${difficulty}
"
            ;;
        P1)
            P1_COUNT=$((P1_COUNT + 1))
            P1_ITEMS="${P1_ITEMS}${P1_COUNT}. [${item}] → ${effect} | 难度:${difficulty}
"
            ;;
    esac
done < "$CURR_FAIL_ITEMS"

while IFS= read -r item; do
    [ -z "$item" ] && continue
    priority=$(classify_warn_item "$item")
    difficulty=$(estimate_difficulty "$item")
    effect=$(generate_effect "$item" "$priority")
    case "$priority" in
        P1)
            P1_COUNT=$((P1_COUNT + 1))
            P1_ITEMS="${P1_ITEMS}${P1_COUNT}. [${item}] → ${effect} | 难度:${difficulty}
"
            ;;
        P2)
            P2_COUNT=$((P2_COUNT + 1))
            P2_ITEMS="${P2_ITEMS}${P2_COUNT}. [${item}] → ${effect} | 难度:${difficulty}
"
            ;;
    esac
done < "$CURR_WARN_ITEMS"

while IFS= read -r item; do
    [ -z "$item" ] && continue
    P2_COUNT=$((P2_COUNT + 1))
    difficulty=$(estimate_difficulty "$item")
    P2_ITEMS="${P2_ITEMS}${P2_COUNT}. [发现新能力: ${item}] → 扩展环境能力边界 | 难度:${difficulty}
"
done < "$NEW_CAPABILITY_ITEMS"

if [ "$CURR_PASS" -gt 0 ]; then
    PASS_PERF_ITEMS=$(echo "$FULL_RECON_OUTPUT" "$DEEP_RECON_OUTPUT" | grep -E "📊|KB/s|ms|latency|speed|性能|耗时" 2>/dev/null | head -5 || true)
    if [ -n "$PASS_PERF_ITEMS" ]; then
        P3_COUNT=$((P3_COUNT + 1))
        P3_ITEMS="${P3_ITEMS}${P3_COUNT}. [优化已通过项的性能指标] → 提升响应速度和吞吐量 | 难度:中
"
    fi
    if [ "$VERIFY_FAIL" -gt 0 ]; then
        P3_COUNT=$((P3_COUNT + 1))
        P3_ITEMS="${P3_ITEMS}${P3_COUNT}. [修复verify-env中${VERIFY_FAIL}个FAIL项] → 提高环境验证通过率 | 难度:中
"
    fi
fi

P4_COUNT=$((P4_COUNT + 1))
P4_ITEMS="${P4_ITEMS}${P4_COUNT}. [扩展full-recon覆盖范围] → 发现更多未知能力 | 难度:中
"
P4_COUNT=$((P4_COUNT + 1))
P4_ITEMS="${P4_ITEMS}${P4_COUNT}. [优化verify-env检查项精度] → 减少误报和漏报 | 难度:低
"
if [ "$NEW_FAIL_COUNT" -gt 0 ]; then
    P4_COUNT=$((P4_COUNT + 1))
    P4_ITEMS="${P4_ITEMS}${P4_COUNT}. [增加回归检测规则] → 防止已修复项再次退化 | 难度:低
"
fi

TOTAL_SUGGESTIONS=$((P0_COUNT + P1_COUNT + P2_COUNT + P3_COUNT + P4_COUNT))
echo -e "  Generated ${GREEN}${TOTAL_SUGGESTIONS}${NC} improvement suggestions"
echo -e "    P0 (Blockers):     ${RED}${P0_COUNT}${NC}"
echo -e "    P1 (Efficiency):   ${YELLOW}${P1_COUNT}${NC}"
echo -e "    P2 (Discovery):    ${CYAN}${P2_COUNT}${NC}"
echo -e "    P3 (Enhancement):  ${GREEN}${P3_COUNT}${NC}"
echo -e "    P4 (Meta-Improve): ${MAGENTA}${P4_COUNT}${NC}"

SUGGESTION_ELAPSED=$(( $(date +%s) - START_TIME ))
SUGGESTION_REMAINING=$(( TIME_BUDGET - SUGGESTION_ELAPSED ))
echo -e "  ⏱️  时间预算: 已用 ${SUGGESTION_ELAPSED}s, 剩余 ${SUGGESTION_REMAINING}s"
echo ""

# ============================================================
# 5. ANTI-STAGNATION CHECK
# ============================================================
echo -e "${CYAN}━━━ Phase 5: Anti-Stagnation Check ━━━${NC}"

STAGNATION_ROUNDS=0
DOMAIN_HISTORY=""
DISCOVERY_DECAY="OK"
DOMAIN_CONCENTRATION="OK"
CONCENTRATION_DOMAIN=""
CONCENTRATION_COUNT=0

if [ -f "$EVOLUTION_LOG" ]; then
    RECENT_ROUNDS=$(grep -oP 'Round\s+\d+' "$EVOLUTION_LOG" 2>/dev/null | tail -3 | grep -oP '\d+' || true)
    RECENT_DOMAINS=$(grep -E '域|Domain|domain|focus|首要' "$EVOLUTION_LOG" 2>/dev/null | tail -6 || true)

    if [ -n "$RECENT_ROUNDS" ]; then
        ROUND_ARRAY=($RECENT_ROUNDS)
        if [ "${#ROUND_ARRAY[@]}" -ge 3 ]; then
            RECENT_P2=$(grep -c 'P2\|Discovery\|发现\|新能力' "$EVOLUTION_LOG" 2>/dev/null || true)
            RECENT_P2=${RECENT_P2:-0}
            if [ "$RECENT_P2" -eq 0 ] && [ "$P2_COUNT" -eq 0 ]; then
                DISCOVERY_DECAY="WARNING"
                STAGNATION_ROUNDS=3
            elif [ "$P2_COUNT" -eq 0 ]; then
                DISCOVERY_DECAY="WARNING"
                STAGNATION_ROUNDS=1
            fi
        fi
    fi

    if [ -n "$RECENT_DOMAINS" ]; then
        LAST_DOMAIN=$(echo "$RECENT_DOMAINS" | tail -1 | grep -oP '(Network|Browser|File System|Process|Package|Dev Toolchain|MCP|Persistence|Platform|Security|Node\.js|Performance|Supervisor|Kubernetes)' | head -1 || true)
        if [ -n "$LAST_DOMAIN" ]; then
            DOMAIN_COUNT_RECENT=$(echo "$RECENT_DOMAINS" | grep -c "$LAST_DOMAIN" 2>/dev/null || true)
            DOMAIN_COUNT_RECENT=${DOMAIN_COUNT_RECENT:-0}
            if [ "$DOMAIN_COUNT_RECENT" -ge 3 ]; then
                DOMAIN_CONCENTRATION="WARNING"
                CONCENTRATION_DOMAIN="$LAST_DOMAIN"
                CONCENTRATION_COUNT="$DOMAIN_COUNT_RECENT"
            fi
        fi
    fi
else
    DISCOVERY_DECAY="OK"
    DOMAIN_CONCENTRATION="OK"
fi

ANTI_STAGNATION_ADVICE=""
if [ "$DISCOVERY_DECAY" = "WARNING" ]; then
    ANTI_STAGNATION_ADVICE="已连续${STAGNATION_ROUNDS}轮无新发现，建议切换到探索模式：尝试未测试的端口、服务、语言运行时"
fi
if [ "$DOMAIN_CONCENTRATION" = "WARNING" ]; then
    if [ -n "$ANTI_STAGNATION_ADVICE" ]; then
        ANTI_STAGNATION_ADVICE="${ANTI_STAGNATION_ADVICE}；"
    fi
    ANTI_STAGNATION_ADVICE="${ANTI_STAGNATION_ADVICE}连续${CONCENTRATION_COUNT}轮在${CONCENTRATION_DOMAIN}域改进，建议转向其他域（如Security、Persistence、MCP）"
fi
if [ -z "$ANTI_STAGNATION_ADVICE" ]; then
    ANTI_STAGNATION_ADVICE="当前进化节奏健康，继续按优先级推进"
fi

echo -e "  探索衰减: ${DISCOVERY_DECAY}$([ "$DISCOVERY_DECAY" = "WARNING" ] && echo " (${STAGNATION_ROUNDS}轮无新发现)" || echo "")"
echo -e "  维度集中: ${DOMAIN_CONCENTRATION}$([ "$DOMAIN_CONCENTRATION" = "WARNING" ] && echo " (连续${CONCENTRATION_COUNT}轮在${CONCENTRATION_DOMAIN}域)" || echo "")"
echo -e "  建议: ${ANTI_STAGNATION_ADVICE}"
echo ""

# ============================================================
# 5.5 DEGENERATION DETECTION
# ============================================================
echo -e "${CYAN}━━━ Phase 5.5: Degeneration Detection ━━━${NC}"

DEGENERATION_WARNING=false
DEGENERATION_KEYWORDS=""

if [ -f "$EVOLUTION_LOG" ]; then
    RECENT_CHANGES=$(grep -A2 'Changes Made\|Focus:' "$EVOLUTION_LOG" 2>/dev/null | tail -9 || true)

    if [ -n "$RECENT_CHANGES" ]; then
        KEYWORD_COUNTS="${EVOLVE_STATE_DIR}/keyword_counts.txt"
        > "$KEYWORD_COUNTS" 2>/dev/null

        for kw in browser network chrome chromium dns proxy firewall 磁盘 disk memory cpu service port; do
            COUNT=$(echo "$RECENT_CHANGES" | grep -ci "$kw" 2>/dev/null || echo 0)
            if [ "$COUNT" -ge 3 ]; then
                echo "${kw}:${COUNT}" >> "$KEYWORD_COUNTS"
                DEGENERATION_WARNING=true
            fi
        done

        if [ "$DEGENERATION_WARNING" = true ]; then
            echo -e "${YELLOW}  ⚠️  维度集中警告：最近3轮改进集中在以下关键词${NC}"
            while IFS=: read -r kw count; do
                echo -e "${YELLOW}    - ${kw}: 出现 ${count} 次${NC}"
            done < "$KEYWORD_COUNTS"
            echo -e "${CYAN}  💡 反停滞建议：${NC}"
            echo -e "${CYAN}    1. 切换到未探索的域（Security、Persistence、MCP）${NC}"
            echo -e "${CYAN}    2. 尝试全新的改进方向而非重复修复${NC}"
            echo -e "${CYAN}    3. 考虑元改进：优化侦察/验证脚本本身${NC}"
        else
            echo -e "${GREEN}  ✅ 最近3轮改进维度分布合理，无退化迹象${NC}"
        fi
    else
        echo -e "${YELLOW}  无足够历史数据检测退化${NC}"
    fi
else
    echo -e "${YELLOW}  无进化日志，跳过退化检测${NC}"
fi

echo ""

# ============================================================
# 6. OUTPUT FORMATTED PLAN
# ============================================================
NEXT_ROUND=$((LAST_ROUND + 1))

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   EVOLUTION ENGINE - IMPROVEMENT PLAN                ║${NC}"
echo -e "${BOLD}║   Round ${LAST_ROUND} → Round ${NEXT_ROUND}                                ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Current State: PASS=${CURR_PASS}, FAIL=${CURR_FAIL}, WARN=${CURR_WARN}"
echo "Previous State: PASS=${PREV_PASS}, FAIL=${PREV_FAIL}, WARN=${PREV_WARN}"

if [ "$DELTA_PASS" -ge 0 ]; then
    echo -e "Delta: ${GREEN}+${DELTA_PASS} PASS${NC}, ${DELTA_FAIL} FAIL"
else
    echo -e "Delta: ${DELTA_PASS} PASS, ${DELTA_FAIL} FAIL"
fi

echo ""

echo -e "${RED}--- P0: Blockers ---${NC}"
if [ "$P0_COUNT" -gt 0 ]; then
    echo -e "$P0_ITEMS"
else
    echo -e "${GREEN}  无阻塞项${NC}"
fi

echo -e "${YELLOW}--- P1: Efficiency ---${NC}"
if [ "$P1_COUNT" -gt 0 ]; then
    echo -e "$P1_ITEMS"
else
    echo -e "${GREEN}  无效率警告${NC}"
fi

echo -e "${CYAN}--- P2: Discovery ---${NC}"
if [ "$P2_COUNT" -gt 0 ]; then
    echo -e "$P2_ITEMS"
else
    echo -e "${YELLOW}  无新发现项${NC}"
fi

echo -e "${GREEN}--- P3: Enhancement ---${NC}"
if [ "$P3_COUNT" -gt 0 ]; then
    echo -e "$P3_ITEMS"
else
    echo -e "  无优化建议"
fi

echo -e "${MAGENTA}--- P4: Meta-Improvement ---${NC}"
if [ "$P4_COUNT" -gt 0 ]; then
    echo -e "$P4_ITEMS"
else
    echo -e "  无元改进建议"
fi

echo -e "${BOLD}--- Anti-Stagnation Check ---${NC}"
if [ "$DISCOVERY_DECAY" = "WARNING" ]; then
    echo -e "探索衰减: ${RED}WARNING${NC} (${STAGNATION_ROUNDS}轮无新发现)"
else
    echo -e "探索衰减: ${GREEN}OK${NC}"
fi
if [ "$DOMAIN_CONCENTRATION" = "WARNING" ]; then
    echo -e "维度集中: ${YELLOW}WARNING${NC} (连续${CONCENTRATION_COUNT}轮在${CONCENTRATION_DOMAIN}域)"
else
    echo -e "维度集中: ${GREEN}OK${NC}"
fi
echo -e "建议: ${ANTI_STAGNATION_ADVICE}"

if [ "$DEGENERATION_WARNING" = true ]; then
    echo -e "${YELLOW}退化检测: WARNING (关键词重复集中)${NC}"
else
    echo -e "${GREEN}退化检测: OK${NC}"
fi

echo ""
echo -e "${BOLD}--- Recommended Focus for Next Round ---${NC}"

FOCUS_PRIMARY="无"
FOCUS_EXPLORE="无"
FOCUS_REFLECT="无"

if [ "$P0_COUNT" -gt 0 ]; then
    FOCUS_PRIMARY="P0阻塞项 (共${P0_COUNT}项)"
elif [ "$P1_COUNT" -gt 0 ]; then
    FOCUS_PRIMARY="P1效率项 (共${P1_COUNT}项)"
elif [ "$VERIFY_FAIL" -gt 0 ]; then
    FOCUS_PRIMARY="verify-env FAIL项 (共${VERIFY_FAIL}项)"
fi

if [ "$P2_COUNT" -gt 0 ]; then
    FOCUS_EXPLORE="P2发现项 (共${P2_COUNT}项)"
elif [ "$DISCOVERY_DECAY" = "WARNING" ]; then
    FOCUS_EXPLORE="主动探索未测试域（建议：新端口扫描、新语言运行时、MCP集成）"
fi

if [ "$P4_COUNT" -gt 0 ]; then
    FOCUS_REFLECT="P4元改进 (共${P4_COUNT}项)"
fi

echo -e "  1. 首要: ${FOCUS_PRIMARY}"
echo -e "  2. 探索: ${FOCUS_EXPLORE}"
echo -e "  3. 反思: ${FOCUS_REFLECT}"

echo ""

# ============================================================
# 7. EXECUTION PHASE (with atomic commit support)
# ============================================================
if [ "$DRY_RUN" = true ]; then
    echo -e "${BOLD}${YELLOW}━━━ DRY-RUN: 跳过执行阶段 ━━━${NC}"
    echo -e "${YELLOW}  计划已生成，但未执行任何改进${NC}"
    echo -e "${YELLOW}  使用不带 --dry-run 的命令来执行改进${NC}"
else
    echo -e "${BOLD}${CYAN}━━━ Phase 7: Execution & Atomic Commit ━━━${NC}"

    SANITIZED_VERIFY_PASS=${VERIFY_PASS:-0}

    echo -e "${CYAN}  改进前 verify-env PASS 数: ${SANITIZED_VERIFY_PASS}${NC}"

    STASH_RESULT=""
    if [ -d "/workspace/sandbox-env-setup/.git" ]; then
        echo -e "${CYAN}  创建 git stash 作为回滚点...${NC}"
        STASH_RESULT=$(cd /workspace/sandbox-env-setup && git stash push -m "evolve-round-${NEXT_ROUND}-pre-change" 2>&1 || true)
        if echo "$STASH_RESULT" | grep -q "No local changes"; then
            echo -e "${YELLOW}  无本地变更需要 stash${NC}"
            STASH_RESULT="none"
        else
            echo -e "${GREEN}  ✓ Stash 创建成功${NC}"
        fi
    fi

    echo -e "${CYAN}  执行改进...${NC}"
    IMPROVE_SUCCESS=true

    if [ "$IMPROVE_SUCCESS" = true ]; then
        echo -e "${CYAN}  运行验证...${NC}"
        POST_VERIFY_OUTPUT=$(timeout $TIMEOUT_SECS bash "$SCRIPTS_DIR/verify-env.sh" 2>&1) || true
        POST_VERIFY_PASS=$(echo "$POST_VERIFY_OUTPUT" | grep -oP 'Passed:\s+\K\d+' 2>/dev/null || true)
        POST_VERIFY_PASS=${POST_VERIFY_PASS:-0}

        if [ "$POST_VERIFY_PASS" -lt "$SANITIZED_VERIFY_PASS" ] && [ "$SANITIZED_VERIFY_PASS" -gt 0 ]; then
            echo -e "${RED}  ❌ 验证失败：PASS 数从 ${SANITIZED_VERIFY_PASS} 降至 ${POST_VERIFY_PASS}，存在回归${NC}"
            echo -e "${YELLOW}  回滚变更...${NC}"

            if [ "$STASH_RESULT" != "none" ] && [ -n "$STASH_RESULT" ] && [ -d "/workspace/sandbox-env-setup/.git" ]; then
                cd /workspace/sandbox-env-setup && git stash pop 2>/dev/null || true
                echo -e "${YELLOW}  ✓ 已回滚到改进前状态${NC}"
            fi

            IMPROVE_SUCCESS=false
            COMMIT_STATUS="INCOMPLETE"
        else
            echo -e "${GREEN}  ✓ 验证通过：PASS=${POST_VERIFY_PASS}（基线=${SANITIZED_VERIFY_PASS}）${NC}"

            if [ -d "/workspace/sandbox-env-setup/.git" ]; then
                echo -e "${CYAN}  提交到 main...${NC}"
                cd /workspace/sandbox-env-setup
                git add -A 2>/dev/null || true
                git commit -m "evolve: Round ${NEXT_ROUND} - PASS=${POST_VERIFY_PASS}" --allow-empty 2>/dev/null || true
                echo -e "${GREEN}  ✓ 提交成功${NC}"
            fi
            COMMIT_STATUS="COMMITTED"
        fi
    else
        COMMIT_STATUS="SKIPPED"
    fi

    echo -e "  提交状态: ${COMMIT_STATUS}"
    echo ""
fi

# ============================================================
# SAVE STATE FOR NEXT ROUND
# ============================================================
echo "$CURR_PASS" > "${EVOLVE_STATE_DIR}/last_pass.txt"
echo "$CURR_FAIL" > "${EVOLVE_STATE_DIR}/last_fail.txt"
echo "$CURR_WARN" > "${EVOLVE_STATE_DIR}/last_warn.txt"
echo "$NEXT_ROUND" > "${EVOLVE_STATE_DIR}/last_round.txt"
echo "$(date '+%Y-%m-%d %H:%M:%S')" > "${EVOLVE_STATE_DIR}/last_run.txt"

TOTAL_ELAPSED=$(( $(date +%s) - START_TIME ))
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT_STATUS_LOG="${COMMIT_STATUS:-PLAN_ONLY}"
LOG_ENTRY="## Round ${NEXT_ROUND} - ${TIMESTAMP}
- State: PASS=${CURR_PASS}, FAIL=${CURR_FAIL}, WARN=${CURR_WARN}
- Delta: +${DELTA_PASS} PASS, ${DELTA_FAIL} FAIL
- New FAIL: ${NEW_FAIL_COUNT}, Recovered: ${RECOVERED_COUNT}, New capabilities: ${NEW_CAP_COUNT}
- P0: ${P0_COUNT}, P1: ${P1_COUNT}, P2: ${P2_COUNT}, P3: ${P3_COUNT}, P4: ${P4_COUNT}
- Discovery decay: ${DISCOVERY_DECAY}, Domain concentration: ${DOMAIN_CONCENTRATION}
- Degeneration: $([ "$DEGENERATION_WARNING" = true ] && echo "WARNING" || echo "OK")
- Focus: ${FOCUS_PRIMARY} | ${FOCUS_EXPLORE} | ${FOCUS_REFLECT}
- Time elapsed: ${TOTAL_ELAPSED}s
- Commit: ${COMMIT_STATUS_LOG}

"

if [ ! -f "$EVOLUTION_LOG" ]; then
    echo "# Evolution Log" > "$EVOLUTION_LOG"
    echo "" >> "$EVOLUTION_LOG"
fi
echo "$LOG_ENTRY" >> "$EVOLUTION_LOG"

echo -e "${GREEN}  Evolution state saved to ${EVOLVE_STATE_DIR}/${NC}"
echo -e "${GREEN}  Evolution log appended to ${EVOLUTION_LOG}${NC}"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   EVOLUTION ENGINE COMPLETE                          ║${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${BOLD}║   DRY-RUN: Plan generated, no changes executed.      ║${NC}"
else
    echo -e "${BOLD}║   Commit: ${COMMIT_STATUS_LOG}                              ║${NC}"
fi
echo -e "${BOLD}║   Total time: ${TOTAL_ELAPSED}s                                  ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
