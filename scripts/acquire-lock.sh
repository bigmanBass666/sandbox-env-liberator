#!/bin/bash
# acquire-lock.sh — Acquire distributed lock using GitHub Issues
# Usage: bash scripts/acquire-lock.sh
set -euo pipefail

LOCK_TITLE="🔒 Evolution Worker Lock"
LOCK_LABEL="lock"
REPO_OWNER="${REPO_OWNER:-bigmanBass666}"
REPO_NAME="${REPO_NAME:-sandbox-env-liberator}"
STALE_THRESHOLD_MINUTES=30

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

check_existing_lock() {
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

get_lock_timestamp() {
    local issue_number="$1"
    local created_at
    created_at=$(gh issue view "$issue_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json createdAt \
        --jq '.createdAt' 2>/dev/null)
    echo "$created_at"
}

is_lock_stale() {
    local issue_number="$1"
    local created_at
    created_at=$(get_lock_timestamp "$issue_number")

    if [ -z "$created_at" ]; then
        return 1
    fi

    local created_epoch
    created_epoch=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    local age_minutes=$(( (now_epoch - created_epoch) / 60 ))

    [ "$age_minutes" -gt "$STALE_THRESHOLD_MINUTES" ]
}

update_lock_issue() {
    local issue_number="$1"
    local hostname="$2"
    local pid="$3"
    local worker_info="$4"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local body="## Evolution Worker Lock

**Acquired At**: ${timestamp}
**Hostname**: ${hostname}
**PID**: ${pid}
**Worker**: ${worker_info}

---
*This lock was automatically updated by the Evolution Worker to claim execution.*
"

    gh issue edit "$issue_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --body "$body" >/dev/null 2>&1

    log_info "Updated existing lock issue #${issue_number}"
    echo "$issue_number"
}

create_lock_issue() {
    local hostname="$1"
    local pid="$2"
    local worker_info="$3"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local body="## Evolution Worker Lock

**Acquired At**: ${timestamp}
**Hostname**: ${hostname}
**PID**: ${pid}
**Worker**: ${worker_info}

---
*This lock was automatically created by the Evolution Worker to claim execution.*
"

    local issue_url
    issue_url=$(gh issue create \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --title "${LOCK_TITLE}" \
        --body "$body" \
        --label "${LOCK_LABEL}" \
        2>/dev/null)

    local issue_number
    issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')
    echo "$issue_number"
}

main() {
    validate_token

    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local pid
    pid=$$
    local worker_info
    worker_info="${WORKER_ROLE:-worker}@$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    log_info "Attempting to acquire lock..."
    log_info "Hostname: ${hostname}, PID: ${pid}"

    local existing_lock
    existing_lock=$(check_existing_lock)

    if [ -n "$existing_lock" ]; then
        local lock_number
        lock_number=$(echo "$existing_lock" | grep -oE '"number":[0-9]+' | grep -oE '[0-9]+')

        if [ -n "$lock_number" ]; then
            log_info "Found existing lock issue #${lock_number}"

            if is_lock_stale "$lock_number"; then
                log_info "Lock is stale (older than ${STALE_THRESHOLD_MINUTES} minutes), updating..."
                update_lock_issue "$lock_number" "$hostname" "$pid" "$worker_info"
                exit 0
            else
                log_error "Lock is held by another worker and is not stale"
                log_error "Issue: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${lock_number}"
                exit 1
            fi
        fi
    fi

    log_info "No existing lock found, creating new one..."
    local new_issue_number
    new_issue_number=$(create_lock_issue "$hostname" "$pid" "$worker_info")

    if [ -n "$new_issue_number" ]; then
        log_info "Successfully acquired lock (issue #${new_issue_number})"
        log_info "Issue: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${new_issue_number}"
        exit 0
    else
        log_error "Failed to create lock issue"
        exit 1
    fi
}

main "$@"
