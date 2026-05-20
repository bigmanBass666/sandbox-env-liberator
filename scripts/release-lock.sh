#!/bin/bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ GITHUB_PERSONAL_ACCESS_TOKEN 未设置${NC}"
    exit 1
fi

LOCK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_PROJECT_DIR="${LOCK_SCRIPT_DIR}/.."
GIT_CONFIG="${LOCK_PROJECT_DIR}/.git/config"
OWNER="bigmanBass666"
REPO="sandbox-env-liberator"

if [ -f "$GIT_CONFIG" ]; then
    REMOTE_URL=$(grep -A1 '\[remote "origin"\]' "$GIT_CONFIG" 2>/dev/null | grep 'url' | sed 's/.*url.*=.*//' | xargs 2>/dev/null || true)
    if [ -n "$REMOTE_URL" ]; then
        EXTRACTED=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[/:]([^/]+)/([^/.]+)(\.git)?|\1/\2|' 2>/dev/null || true)
        if [ -n "$EXTRACTED" ] && echo "$EXTRACTED" | grep -q '/'; then
            OWNER=$(echo "$EXTRACTED" | cut -d'/' -f1)
            REPO=$(echo "$EXTRACTED" | cut -d'/' -f2)
        fi
    fi
fi

echo -e "${CYAN}🔓 分布式锁释放 - ${OWNER}/${REPO}${NC}"

HANDOFF_FILE="${LOCK_PROJECT_DIR}/handoff.md"
if [ ! -f "$HANDOFF_FILE" ]; then
    echo -e "${RED}❌ 锁未被释放 — handoff.md 不存在${NC}"
    exit 1
fi

EXHAUSTIVE_CHECK=$(grep -i "Status:.*EXHAUSTIVE" "$HANDOFF_FILE" 2>/dev/null || true)
if [ -z "$EXHAUSTIVE_CHECK" ]; then
    echo -e "${RED}❌ 锁未被释放 — handoff.md 未标记 EXHAUSTIVE。继续探索或标记 EXHAUSTIVE 后重试。${NC}"
    exit 1
fi

echo -e "${GREEN}✅ handoff.md 已标记 EXHAUSTIVE，继续释放锁${NC}"

RELEASE_RESULT=$(node -e "
const token = process.env.GITHUB_PERSONAL_ACCESS_TOKEN;
const owner = '${OWNER}';
const repo = '${REPO}';
const now = new Date().toISOString();

async function run() {
    const headers = {
        'Authorization': 'token ' + token,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'sandbox-evolve-lock'
    };

    let currentBody = '';
    try {
        const getRes = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            headers: headers,
            signal: AbortSignal.timeout(15000)
        });
        if (getRes.ok) {
            const issue = await getRes.json();
            currentBody = issue.body || '';
        }
    } catch (e) {
        // ignore, proceed with empty body
    }

    const newBody = currentBody + '\\nRELEASED_AT: ' + now + '\\nLOCK_STATUS: released';

    try {
        const updateRes = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            method: 'PATCH',
            headers: headers,
            body: JSON.stringify({
                labels: [],
                state: 'closed',
                body: newBody
            }),
            signal: AbortSignal.timeout(15000)
        });
        if (updateRes.ok) {
            console.log(JSON.stringify({status: 'released'}));
        } else if (updateRes.status === 404) {
            console.log(JSON.stringify({status: 'no_issue'}));
        } else {
            const errBody = await updateRes.text();
            console.log(JSON.stringify({status: 'error', message: 'Release failed: ' + updateRes.status + ' ' + errBody}));
        }
    } catch (e) {
        console.log(JSON.stringify({status: 'error', message: 'Network error: ' + e.message}));
    }
}

run();
" 2>/dev/null)

if [ -z "$RELEASE_RESULT" ]; then
    echo -e "${RED}❌ 锁释放失败：无响应${NC}"
    exit 1
fi

STATUS=$(echo "$RELEASE_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.status);" 2>/dev/null || echo "parse_error")

case "$STATUS" in
    released)
        echo -e "${GREEN}✅ 锁已成功释放${NC}"
        exit 0
        ;;
    no_issue)
        echo -e "${YELLOW}⚠️  Issue #1 不存在，无需释放${NC}"
        exit 0
        ;;
    error)
        MSG=$(echo "$RELEASE_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.message||'unknown error');" 2>/dev/null || echo "unknown error")
        echo -e "${RED}❌ 锁释放失败: ${MSG}${NC}"
        exit 1
        ;;
    *)
        echo -e "${RED}❌ 未知状态: ${STATUS}${NC}"
        exit 1
        ;;
esac
