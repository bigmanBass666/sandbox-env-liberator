#!/bin/bash
# bootstrap.sh — Fresh environment one-command initialization
# Idempotent: safe to run multiple times on any environment state
# Usage: bash scripts/bootstrap.sh
set -euo pipefail

REPO_URL="https://github.com/bigmanBass666/sandbox-env-liberator.git"
PROJECT_DIR="/workspace/sandbox-env-setup"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

STEP=0
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

log_step() {
    STEP=$((STEP + 1))
    echo -e "${CYAN}[Step ${STEP}] $1${NC}"
}
log_pass() { echo -e "  ${GREEN}✅ $1${NC}"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; WARN_COUNT=$((WARN_COUNT + 1)); }
log_fail() { echo -e "  ${RED}❌ $1${NC}"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   sandbox-env-liberator Bootstrap v1.0      ║"
echo "║   Initializing environment from scratch     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

log_step "Check GITHUB_PERSONAL_ACCESS_TOKEN"
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    log_fail "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is NOT set"
    echo ""
    echo -e "${RED}CRITICAL: Cannot proceed without GitHub token.${NC}"
    echo "The distributed lock mechanism requires this token."
    echo "Set it in your environment or Schedule configuration:"
    echo "  export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_xxxxxxxxxxxx'"
    exit 1
else
    log_pass "GITHUB_PERSONAL_ACCESS_TOKEN is set (${#GITHUB_PERSONAL_ACCESS_TOKEN} chars)"
fi

log_step "Check prerequisites"
MISSING=""
for cmd in git curl node npm bash; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    log_warn "Missing prerequisites:$MISSING — attempting to install..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq git curl nodejs npm 2>/dev/null || true
    fi
    for cmd in $MISSING; do
        if command -v "$cmd" &>/dev/null; then
            log_pass "Installed: $cmd"
        else
            log_fail "Still missing: $cmd (cannot auto-install)"
        fi
    done
else
    log_pass "All prerequisites present: git, curl, node, npm, bash"
fi

log_step "Ensure git repository exists"
if [ -d "$PROJECT_DIR" ]; then
    if cd "$PROJECT_DIR" && git rev-parse --is-inside-work-tree &>/dev/null; then
        log_pass "Repository exists at $PROJECT_DIR (pulling latest...)"
        git pull origin main 2>/dev/null || log_warn "git pull failed (may be offline or up-to-date)"
        ROUND_NUM=$(grep -oP 'R\d+' "$PROJECT_DIR/references/polaris-score.md" 2>/dev/null | grep -oP '\d+' | sort -n | tail -1 || echo "0")
        NEXT_ROUND=$((ROUND_NUM + 1))
        BRANCH_NAME="evolve/round-${NEXT_ROUND}"
        cd "$PROJECT_DIR" && git checkout -b "$BRANCH_NAME" 2>/dev/null || true
        if git branch --show-current | grep -q "evolve/round"; then
            log_pass "Working branch: $(git branch --show-current)"
        fi
        echo ""
        echo -e "${CYAN}  📋 最近 5 条 commits（其他 session 可能提交了新内容）：${NC}"
        git log --oneline -5 2>/dev/null | while IFS= read -r line; do
            echo -e "    ${CYAN}${line}${NC}"
        done || true
    else
        log_warn "$PROJECT_DIR exists but is not a git repo — removing and re-cloning"
        rm -rf "$PROJECT_DIR"
        git clone "$REPO_URL" "$PROJECT_DIR"
        log_pass "Repository cloned to $PROJECT_DIR"
    fi
else
    log_pass "Cloning repository to $PROJECT_DIR ..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    log_pass "Repository cloned to $PROJECT_DIR"
fi
cd "$PROJECT_DIR"

log_step "Run persist-config.sh (mirrors + env vars)"
if [ -f scripts/persist-config.sh ]; then
    bash scripts/persist-config.sh 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qi "✅\|pass\|configured\|success"; then
            log_pass "persist: $(echo "$line" | sed 's/^[[:space:]]*//')"
        elif echo "$line" | grep -qi "⚠️\|warn\|skip"; then
            log_warn "persist: $(echo "$line" | sed 's/^[[:space:]]*//')"
        else
            echo "  $line"
        fi
    done || log_warn "persist-config.sh had some issues (non-critical)"
else
    log_fail "scripts/persist-config.sh not found!"
fi

log_step "Install essential npm packages"
NODE_PATH_GLOBAL="$(npm root -g 2>/dev/null || echo "")"
export NODE_PATH="${NODE_PATH}:${NODE_PATH_GLOBAL}"
ESSENTIAL_PKGS="playwright"
for pkg in $ESSENTIAL_PKGS; do
    if npm list -g "$pkg" &>/dev/null 2>&1; then
        log_pass "npm global: $pkg already installed"
    else
        log_warn "Installing npm global package: $pkg ..."
        npm install -g "$pkg" 2>/dev/null && log_pass "npm global: $pkg installed" || log_fail "npm global: $pkg install failed"
    fi
done

log_step "Run verify-env.sh baseline"
if [ -f scripts/verify-env.sh ]; then
    BASELINE_OUTPUT=$(bash scripts/verify-env.sh 2>&1 || true)
    BASELINE_PASS=$(echo "$BASELINE_OUTPUT" | grep -c "PASS" || echo "0")
    BASELINE_FAIL=$(echo "$BASELINE_OUTPUT" | grep -c "FAIL" || echo "0")
    BASELINE_WARN=$(echo "$BASELINE_OUTPUT" | grep -c "WARN" || echo "0")
    log_pass "verify-env baseline: PASS=$BASELINE_PASS FAIL=$BASELINE_FAIL WARN=$BASELINE_WARN"
else
    log_warn "verify-env.sh not found — skipping baseline"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Bootstrap Complete                  ║"
echo "╠══════════════════════════════════════════════╣"
printf "║  %-20s %s%-20s ║\n" "✅ Passed:" "$GREEN" "$PASS_COUNT$NC"
printf "║  %-20s %s%-20s ║\n" "⚠️  Warnings:" "$YELLOW" "$WARN_COUNT$NC"
printf "║  %-20s %s%-20s ║\n" "❌ Failed:" "$RED" "$FAIL_COUNT$NC"
echo "╚══════════════════════════════════════════════╝"
echo ""

if [ "$FAIL_COUNT" -gt 2 ]; then
    echo -e "${YELLOW}⚠️  Multiple failures detected. Review above before proceeding.${NC}"
    exit 2
fi

exit 0
