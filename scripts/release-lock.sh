#!/bin/bash
# release-lock.sh — Release distributed lock by closing the GitHub Issue
# Usage: bash scripts/release-lock.sh
set -euo pipefail

LOCK_LABEL="lock"
REPO_OWNER="${REPO_OWNER:-bigmanBass666}"
REPO_NAME="${REPO_NAME:-sandbox-env-liberator}"
RELEASED_LABEL="released"

log_error() {
    echo "[ERROR] $1" >&2
}

log_info() {
    echo "[INFO] $1"
}

validate_token() {
    if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
        log_error "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is not set"
        return 1
    fi
    export GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}"
}

find_lock_issue() {
    local lock_issue
    lock_issue=$(gh issue list \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --label "${LOCK_LABEL}" \
        --state open \
        --json number,title \
        --jq '.[] | select(.title | contains("Evolution Worker Lock"))' 2>/dev/null || echo "")

    if [ -z "$lock_issue" ] || [ "$lock_issue" = "null" ]; then
        echo ""
        return 1
    fi

    echo "$lock_issue"
}

get_issue_body() {
    local issue_number="$1"
    local body
    body=$(gh issue view "$issue_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json body \
        --jq '.body' 2>/dev/null)
    echo "$body"
}

update_and_close_lock() {
    local issue_number="$1"
    local end_timestamp
    end_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local current_body
    current_body=$(get_issue_body "$issue_number")

    local new_body
    new_body="${current_body}

---

**Released At**: ${end_timestamp}
*Lock automatically released by Evolution Worker.*"

    gh issue edit "$issue_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --body "$new_body" \
        --add-label "${RELEASED_LABEL}" >/dev/null 2>&1

    gh issue close "$issue_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" >/dev/null 2>&1

    log_info "Successfully closed lock issue #${issue_number}"
    echo "$issue_number"
}

main() {
    validate_token

    log_info "Attempting to release lock..."

    local existing_lock
    existing_lock=$(find_lock_issue)

    if [ -z "$existing_lock" ]; then
        log_info "No active lock found, nothing to release"
        exit 0
    fi

    local lock_number
    lock_number=$(echo "$existing_lock" | grep -oE '"number":[0-9]+' | grep -oE '[0-9]+')

    if [ -n "$lock_number" ]; then
        log_info "Found active lock issue #${lock_number}"
        update_and_close_lock "$lock_number"
        exit 0
    else
        log_error "Failed to parse lock issue number"
        exit 1
    fi
}

main "$@"
