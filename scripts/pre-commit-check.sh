#!/usr/bin/env bash
set -euo pipefail

FAILED=0

check_worker_md() {
    local file="prompts/worker.md"
    if ! git diff --cached --name-only | grep -q "^${file}$"; then
        return 0
    fi

    echo "[pre-commit] Checking ${file}..."

    local max_body_chars
    max_body_chars=$(sed -n '/^---$/,/^---$/p' "$file" | grep -oP '^max_body_chars:\s*\K[0-9]+' || true)
    if [ -z "$max_body_chars" ]; then
        max_body_chars=13000
        echo "  ⚠️ max_body_chars not found in frontmatter, using default 13000"
    fi

    local body_chars
    body_chars=$(awk '/<!--/,0' "$file" | wc -c)
    if [ "$body_chars" -gt "$max_body_chars" ]; then
        echo "  ❌ FAIL: Body is ${body_chars} chars, exceeds ${max_body_chars} limit"
        FAILED=1
    else
        echo "  ✅ Body chars: ${body_chars} < ${max_body_chars}"
    fi

    local hardcoded
    hardcoded=$(grep -cE '(Round [0-9]|R[0-9]{2}|Total: \*\*[0-9]+%\*\*|D[1-6]: [0-9]+%)' "$file" 2>/dev/null || echo 0)
    hardcoded=$(echo "$hardcoded" | tail -1)
    if [ "$hardcoded" -ne 0 ]; then
        echo "  ❌ FAIL: Found ${hardcoded} hardcoded data patterns (Round N/Rxx/D1:N%)"
        FAILED=1
    else
        echo "  ✅ No hardcoded data"
    fi

    local cso_dep
    cso_dep=$(grep -c 'CSO 指定任务\|CSO Designated Task\|本轮必做' "$file" 2>/dev/null || echo 0)
    cso_dep=$(echo "$cso_dep" | tail -1)
    if [ "$cso_dep" -ne 0 ]; then
        echo "  ❌ FAIL: Found ${cso_dep} CSO dependency patterns"
        FAILED=1
    else
        echo "  ✅ No CSO dependency"
    fi

    local html_comment
    html_comment=$(grep -c 'META-PROMPT' "$file" 2>/dev/null || echo 0)
    html_comment=$(echo "$html_comment" | tail -1)
    if [ "$html_comment" -eq 0 ]; then
        echo "  ❌ FAIL: HTML comment (META-PROMPT declaration) missing"
        FAILED=1
    else
        echo "  ✅ HTML comment intact"
    fi

    local test2
    test2=$(grep -c "what to do.*or.*how to decide" "$file" 2>/dev/null || echo 0)
    test2=$(echo "$test2" | tail -1)
    if [ "$test2" -eq 0 ]; then
        echo "  ❌ FAIL: TEST 2 self-check line missing from HTML comment"
        FAILED=1
    else
        echo "  ✅ TEST 2 self-check present"
    fi
}

check_schedule_setup() {
    local file="references/schedule-setup.md"
    if ! git diff --cached --name-only | grep -q "^${file}$"; then
        return 0
    fi

    echo "[pre-commit] Checking ${file}..."

    local task_injection
    task_injection=$(grep -c 'dl.google.com\|cdn-speed-survey' "$file" 2>/dev/null || echo 0)
    task_injection=$(echo "$task_injection" | tail -1)
    if [ "$task_injection" -ne 0 ]; then
        echo "  ❌ FAIL: Found ${task_injection} specific task injections (should be in polaris-score.md Stretch Goals)"
        FAILED=1
    else
        echo "  ✅ No task injection"
    fi
}

check_worker_md
check_schedule_setup

if [ "$FAILED" -ne 0 ]; then
    echo ""
    echo "❌ Pre-commit check FAILED. Fix the issues above before committing."
    echo "   Hint: Run 'awk '/<!--/,0' prompts/worker.md | wc -c' to check char count"
    exit 1
fi

exit 0
