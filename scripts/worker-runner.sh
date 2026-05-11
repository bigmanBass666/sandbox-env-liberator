#!/bin/bash
# worker-runner.sh — Evolution Worker Main Execution Wrapper
# 编排从环境准备到退出记录的完整执行流程
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
REFERENCES_DIR="${PROJECT_DIR}/references"

REPO_URL="https://github.com/bigmanBass666/sandbox-env-liberator.git"
REPO_LOCAL="/workspace/sandbox-env-liberator"
WORKER_BRANCH="worker"
MAIN_BRANCH="main"

GITHUB_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"

EXECUTION_TIMEOUT=1800

CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

log_phase() {
    local phase="$1"
    local message="$2"
    echo -e "${MAGENTA}[Phase ${phase}]${NC} ${CYAN}${message}${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_PERSONAL_ACCESS_TOKEN 环境变量未设置"
        return 1
    fi
    return 0
}

run_phase_1_env_prep() {
    log_phase "1" "Environment Preparation"

    if [ ! -d "$REPO_LOCAL" ]; then
        log_info "仓库不存在，克隆中..."
        if ! git clone "$REPO_URL" "$REPO_LOCAL" 2>&1; then
            log_error "克隆仓库失败"
            return 1
        fi
        log_success "仓库克隆完成"
    else
        log_info "仓库已存在，更新中..."
        cd "$REPO_LOCAL" || return 1
        git fetch origin 2>/dev/null || true
        log_success "仓库更新完成"
    fi

    log_info "切换到 ${WORKER_BRANCH} 分支"
    cd "$REPO_LOCAL" || return 1
    if ! git checkout "$WORKER_BRANCH" 2>&1; then
        log_warn "分支不存在，创建并切换"
        git checkout -b "$WORKER_BRANCH" 2>&1 || true
    fi
    git pull origin "$WORKER_BRANCH" 2>/dev/null || log_warn "无法拉取 worker 分支"

    if ! command -v gh &>/dev/null; then
        log_info "安装 gh CLI..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq gh 2>/dev/null || log_warn "gh 安装可能失败"
        fi
    fi

    if command -v gh &>/dev/null; then
        log_info "配置 GitHub 认证"
        echo "$GITHUB_TOKEN" | gh auth login --hostname github.com --with-token 2>/dev/null || log_warn "gh 认证可能已存在"
    fi

    log_info "运行 bootstrap.sh"
    if ! bash "${REPO_LOCAL}/scripts/bootstrap.sh" --role worker 2>&1; then
        log_warn "bootstrap.sh 执行出现问题"
    fi

    log_success "Phase 1 完成"
    return 0
}

run_phase_2_state_reading() {
    log_phase "2" "State Reading"

    cd "$REPO_LOCAL" || return 1

    if [ -f "${REFERENCES_DIR}/polaris-score.md" ]; then
        log_info "读取 polaris-score.md"
        POLARIS_SCORE_CONTENT=$(cat "${REFERENCES_DIR}/polaris-score.md")
        TOTAL_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -E "^Total:" | awk '{print $2}' || echo "0%")
        log_info "当前总分: ${TOTAL_SCORE}"
    else
        log_warn "polaris-score.md 不存在"
        TOTAL_SCORE="0%"
    fi

    if [ -f "${REFERENCES_DIR}/handoff.md" ]; then
        log_info "读取 handoff.md"
        HANDOFF_CONTENT=$(cat "${REFERENCES_DIR}/handoff.md")
        HANDOFF_STATUS=$(echo "$HANDOFF_CONTENT" | grep -E "^| Status" | grep -v "Field" | awk -F'|' '{print $4}' | tr -d ' ' || echo "NEW")
        HANDOFF_FOCUS=$(echo "$HANDOFF_CONTENT" | grep -E "Polaris Focus Dimension|Focus Dimension" | head -1 | awk -F':' '{print $2}' | tr -d ' ' || echo "")
        log_info "Handoff Status: ${HANDOFF_STATUS}"
        log_info "Focus Dimension: ${HANDOFF_FOCUS}"
    else
        log_warn "handoff.md 不存在，初始化为 NEW"
        HANDOFF_STATUS="NEW"
        HANDOFF_FOCUS=""
    fi

    if [ -f "${REFERENCES_DIR}/evolution-log.md" ]; then
        log_info "读取 evolution-log.md (最后 100 行)"
        EVOLUTION_LOG_TAIL=$(tail -100 "${REFERENCES_DIR}/evolution-log.md")
        LAST_ROUND=$(echo "$EVOLUTION_LOG_TAIL" | grep -E "^## Round [0-9]+" | tail -1 | sed 's/## Round //' || echo "0")
        log_info "最近轮次: Round ${LAST_ROUND}"
    else
        LAST_ROUND="0"
    fi

    log_info "读取最近提交历史"
    RECENT_COMMITS=$(git log --oneline -15 2>/dev/null || echo "无提交记录")
    log_info "最近提交:"
    echo "$RECENT_COMMITS" | head -10 | sed 's/^/    /'

    if [ -f "${REFERENCES_DIR}/polaris-score.md" ]; then
        log_info "确定最低分维度"
        D1_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D1 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")
        D2_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D2 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")
        D3_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D3 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")
        D4_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D4 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")
        D5_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D5 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")
        D6_SCORE=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| D6 " | grep -E "^[0-9]" | awk '{print $1}' | tr -d '%' || echo "100")

        LOWEST_DIM=""
        LOWEST_SCORE=100
        for dim in D1 D2 D3 D4 D5 D6; do
            eval "score=\$${dim}_SCORE"
            if [ -n "$score" ] && [ "$score" -lt "$LOWEST_SCORE" ]; then
                LOWEST_SCORE=$score
                LOWEST_DIM=$dim
            fi
        done
        log_info "最低分维度: ${LOWEST_DIM} (${LOWEST_SCORE}%)"
    else
        LOWEST_DIM="D1"
        LOWEST_SCORE=0
    fi

    log_success "Phase 2 完成"
    return 0
}

run_phase_3_strategy_determination() {
    log_phase "3" "Strategy Determination"

    STRATEGY="NEW"

    if [ "$HANDOFF_STATUS" = "CONTINUE" ]; then
        log_info "Handoff Status=CONTINUE，继续同一方向"
        STRATEGY="CONTINUE"
        FOCUS_DIM="$HANDOFF_FOCUS"
    elif [ "$HANDOFF_STATUS" = "CONTINUE_SAME" ]; then
        log_info "Handoff Status=CONTINUE_SAME，继续同一维度"
        STRATEGY="CONTINUE_SAME"
        FOCUS_DIM="$HANDOFF_FOCUS"
    else
        log_info "Handoff Status=${HANDOFF_STATUS}，开始新方向"
        STRATEGY="NEW"
        FOCUS_DIM="$LOWEST_DIM"
    fi

    if [ "$STRATEGY" = "NEW" ] || [ "$STRATEGY" = "CONTINUE" ]; then
        STREAK=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| ${FOCUS_DIM} " | grep "Streak" | awk '{print $1}' || echo "0")
        if [ -n "$STREAK" ] && [ "$STREAK" -ge 3 ]; then
            log_warn "维度 ${FOCUS_DIM} 已连续 ${STREAK} 轮无进展，切换到最低分维度"
            FOCUS_DIM="$LOWEST_DIM"
            log_info "新聚焦维度: ${FOCUS_DIM}"
        fi
    fi

    export FOCUS_DIM
    export STRATEGY

    log_success "Phase 3 完成 - 策略: ${STRATEGY}, 维度: ${FOCUS_DIM}"
    return 0
}

run_phase_4_evolution_execution() {
    log_phase "4" "Evolution Execution"

    cd "$REPO_LOCAL" || return 1

    log_info "调用 evolve.sh (超时: ${EXECUTION_TIMEOUT}s)"
    log_info "聚焦维度: ${FOCUS_DIM}"

    export POLARIS_FOCUS_DIM="$FOCUS_DIM"

    START_EVOLVE=$(date +%s)

    timeout "${EXECUTION_TIMEOUT}" bash "${REPO_LOCAL}/scripts/evolve.sh" 2>&1 | tee /tmp/evolve-output.log
    EVOLVE_EXIT_CODE=${PIPESTATUS[0]}

    END_EVOLVE=$(date +%s)
    EVOLVE_DURATION=$((END_EVOLVE - START_EVOLVE))

    if [ $EVOLVE_EXIT_CODE -eq 124 ]; then
        log_error "evolve.sh 执行超时 (${EVOLVE_DURATION}s)"
        HANDOFF_STATUS="STALLED"
        return 1
    elif [ $EVOLVE_EXIT_CODE -ne 0 ]; then
        log_error "evolve.sh 执行失败 (exit code: ${EVOLVE_EXIT_CODE})"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        if [ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]; then
            log_error "连续 ${CONSECUTIVE_FAILURES} 次失败，设置 STALLED 状态"
            HANDOFF_STATUS="STALLED"
        fi
        return 1
    else
        log_success "evolve.sh 执行成功 (${EVOLVE_DURATION}s)"
        CONSECUTIVE_FAILURES=0
    fi

    log_success "Phase 4 完成"
    return 0
}

run_phase_5_continuous_improvement() {
    log_phase "5" "Continuous Improvement"

    log_info "自检：检查是否有其他可改进的空间"

    if [ -f /tmp/evolve-output.log ]; then
        LAST_PHASE=$(grep -E "^Phase [0-9]" /tmp/evolve-output.log | tail -1 || echo "")
        log_info "evolve.sh 最后阶段: ${LAST_PHASE}"
    fi

    if [ -f "${REFERENCES_DIR}/polaris-score.md" ]; then
        CURRENT_TOTAL=$(grep "^Total:" "${REFERENCES_DIR}/polaris-score.md" | awk '{print $2}' || echo "0%")
        log_info "当前总分: ${CURRENT_TOTAL}"
    fi

    log_info "检查低分维度是否有遗漏的改进点"

    if [ -f "${REFERENCES_DIR}/polaris-score.md" ]; then
        for dim in D1 D2 D3 D4 D5 D6; do
            eval "score=\$${dim}_SCORE"
            if [ -n "$score" ] && [ "$score" -lt 60 ]; then
                DIM_NAME=$(echo "$POLARIS_SCORE_CONTENT" | grep -A1 "| ${dim} " | grep -v "^-" | grep -v "|" | grep -v "^$" | head -1 | awk -F'|' '{print $3}' | tr -d ' ' || echo "$dim")
                log_info "  ${dim} (${DIM_NAME}): ${score}% - 有改进空间"
            fi
        done
    fi

    log_info "Phase 5 自检完成 - 如需额外改进，考虑在下一轮执行"
    return 0
}

run_phase_6_exit_recording() {
    log_phase "6" "Exit Recording"

    cd "$REPO_LOCAL" || return 1

    CURRENT_ROUND=$((LAST_ROUND + 1))
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [ ! -f "${REFERENCES_DIR}/handoff.md" ]; then
        log_warn "创建 handoff.md"
        cat > "${REFERENCES_DIR}/handoff.md" << EOF
# Handoff Record

> Generated by worker-runner.sh Round ${CURRENT_ROUND} at ${TIMESTAMP}

## Session Info

| Field | Value |
|-------|-------|
| Round | ${CURRENT_ROUND} |
| Ended At | ${TIMESTAMP} |
| Status | ${HANDOFF_STATUS:-COMPLETE} |
| Polaris Focus Dimension | ${FOCUS_DIM} |
| Strategy | ${STRATEGY} |

## What's Left Undone

- [ ] 待补充

## Environment Notes

Round ran at ${TIMESTAMP}. Worker execution completed.
EOF
    fi

    log_info "Git 添加特定文件"
    git add "${REFERENCES_DIR}/polaris-score.md" 2>/dev/null || true
    git add "${REFERENCES_DIR}/handoff.md" 2>/dev/null || true
    git add "${REFERENCES_DIR}/evolution-log.md" 2>/dev/null || true

    if git diff --cached --quiet; then
        log_info "没有变更需要提交"
    else
        COMMIT_MSG="Worker Round ${CURRENT_ROUND}: ${FOCUS_DIM} focus, ${STRATEGY} strategy"
        if [ -n "${HANDOFF_STATUS}" ] && [ "${HANDOFF_STATUS}" != "COMPLETE" ]; then
            COMMIT_MSG="${COMMIT_MSG} [${HANDOFF_STATUS}]"
        fi

        log_info "Git 提交: ${COMMIT_MSG}"
        git commit -m "${COMMIT_MSG}" 2>&1 || log_warn "Git 提交失败"

        log_info "推送到 ${WORKER_BRANCH} 分支"
        git push origin "${WORKER_BRANCH}" 2>&1 || log_warn "Git 推送失败"
    fi

    log_success "Phase 6 完成"
    return 0
}

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       Evolution Worker Runner v1.0              ║"
    echo "║       主执行包装脚本                             ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    if ! check_token; then
        log_error "Token 检查失败，无法继续"
        exit 1
    fi

    HANDOFF_STATUS="${HANDOFF_STATUS:-NEW}"
    FOCUS_DIM="${FOCUS_DIM:-D1}"
    STRATEGY="NEW"

    if ! run_phase_1_env_prep; then
        HANDOFF_STATUS="INCOMPLETE"
        run_phase_6_exit_recording
        exit 1
    fi

    if ! run_phase_2_state_reading; then
        HANDOFF_STATUS="INCOMPLETE"
        run_phase_6_exit_recording
        exit 1
    fi

    if ! run_phase_3_strategy_determination; then
        HANDOFF_STATUS="INCOMPLETE"
        run_phase_6_exit_recording
        exit 1
    fi

    if ! run_phase_4_evolution_execution; then
        log_error "Evolution execution failed"
        run_phase_5_continuous_improvement
        run_phase_6_exit_recording
        exit 1
    fi

    if ! run_phase_5_continuous_improvement; then
        log_warn "Continuous improvement check had issues"
    fi

    if ! run_phase_6_exit_recording; then
        log_error "Exit recording failed"
        exit 1
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       Worker Runner 完成                         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    exit 0
}

main "$@"
