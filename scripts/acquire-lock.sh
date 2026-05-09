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

GIT_CONFIG="/workspace/sandbox-env-setup/.git/config"
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

echo -e "${CYAN}🔐 分布式锁获取 - ${OWNER}/${REPO}${NC}"

LOCK_RESULT=$(node -e "
const token = process.env.GITHUB_PERSONAL_ACCESS_TOKEN;
const owner = '${OWNER}';
const repo = '${REPO}';
const session = process.env.HOSTNAME || 'unknown-session';
const now = new Date().toISOString();

async function run() {
    const headers = {
        'Authorization': 'token ' + token,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'sandbox-evolve-lock'
    };

    let issue;
    try {
        const res = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            headers: headers,
            signal: AbortSignal.timeout(15000)
        });
        if (res.status === 404) {
            issue = null;
        } else if (res.ok) {
            issue = await res.json();
        } else {
            const body = await res.text();
            console.log(JSON.stringify({status: 'error', message: 'API error: ' + res.status + ' ' + body}));
            return;
        }
    } catch (e) {
        console.log(JSON.stringify({status: 'error', message: 'Network error: ' + e.message}));
        return;
    }

    if (issue && issue.state === 'open') {
        const labels = (issue.labels || []).map(function(l) { return typeof l === 'string' ? l : l.name; });
        if (labels.includes('evolving')) {
            const body = issue.body || '';
            const lockTimeMatch = body.match(/LOCK_ACQUIRED_AT:\s*(\S+)/);
            if (lockTimeMatch) {
                const lockTime = new Date(lockTimeMatch[1]);
                const elapsed = (Date.now() - lockTime.getTime()) / 60000;
                if (elapsed > 60) {
                    console.log(JSON.stringify({status: 'timeout', elapsed: Math.round(elapsed), lockTime: lockTimeMatch[1]}));
                    return;
                }
            }
            console.log(JSON.stringify({status: 'locked', body: body}));
            return;
        }
    }

    if (!issue) {
        try {
            const createRes = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues', {
                method: 'POST',
                headers: headers,
                body: JSON.stringify({
                    title: '🔒 Distributed Lock',
                    body: 'LOCK_ACQUIRED_AT: ' + now + '\\nLOCK_SESSION: ' + session + '\\nLOCK_STATUS: acquired',
                    labels: ['evolving'],
                    state: 'open'
                }),
                signal: AbortSignal.timeout(15000)
            });
            if (createRes.ok) {
                console.log(JSON.stringify({status: 'acquired', created: true}));
            } else {
                const errBody = await createRes.text();
                console.log(JSON.stringify({status: 'error', message: 'Create issue failed: ' + createRes.status + ' ' + errBody}));
            }
        } catch (e) {
            console.log(JSON.stringify({status: 'error', message: 'Network error on create: ' + e.message}));
        }
        return;
    }

    try {
        const updateRes = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            method: 'PATCH',
            headers: headers,
            body: JSON.stringify({
                body: 'LOCK_ACQUIRED_AT: ' + now + '\\nLOCK_SESSION: ' + session + '\\nLOCK_STATUS: acquired',
                labels: ['evolving'],
                state: 'open'
            }),
            signal: AbortSignal.timeout(15000)
        });
        if (updateRes.ok) {
            console.log(JSON.stringify({status: 'acquired', created: false}));
        } else {
            const errBody = await updateRes.text();
            console.log(JSON.stringify({status: 'error', message: 'Update issue failed: ' + updateRes.status + ' ' + errBody}));
        }
    } catch (e) {
        console.log(JSON.stringify({status: 'error', message: 'Network error on update: ' + e.message}));
    }
}

run();
" 2>/dev/null)

if [ -z "$LOCK_RESULT" ]; then
    echo -e "${RED}❌ 锁检查失败：无响应${NC}"
    exit 1
fi

STATUS=$(echo "$LOCK_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.status);" 2>/dev/null || echo "parse_error")

case "$STATUS" in
    locked)
        LOCK_BODY=$(echo "$LOCK_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.body||'');" 2>/dev/null || true)
        echo -e "${RED}❌ 锁已被占用${NC}"
        echo -e "${YELLOW}   持有者信息:${NC}"
        echo "$LOCK_BODY" | sed 's/^/     /'
        exit 1
        ;;
    timeout)
        ELAPSED=$(echo "$LOCK_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(String(j.elapsed||0));" 2>/dev/null || echo "0")
        echo -e "${YELLOW}⚠️  锁已超时（持有 ${ELAPSED} 分钟），强制释放...${NC}"

        FORCE_RESULT=$(node -e "
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
    try {
        const res = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            method: 'PATCH',
            headers: headers,
            body: JSON.stringify({
                labels: ['timeout-release'],
                state: 'closed',
                body: 'LOCK_STATUS: timeout-released\\nRELEASED_AT: ' + now + '\\nREASON: held_over_60min'
            }),
            signal: AbortSignal.timeout(15000)
        });
        if (res.ok) {
            console.log(JSON.stringify({status: 'force_released'}));
        } else {
            const errBody = await res.text();
            console.log(JSON.stringify({status: 'error', message: 'Force release failed: ' + res.status}));
        }
    } catch (e) {
        console.log(JSON.stringify({status: 'error', message: 'Network error: ' + e.message}));
    }
}
run();
" 2>/dev/null)

        FORCE_STATUS=$(echo "$FORCE_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.status);" 2>/dev/null || echo "error")

        if [ "$FORCE_STATUS" = "force_released" ]; then
            echo -e "${YELLOW}   旧锁已释放，重新获取锁...${NC}"
            REACQUIRE_RESULT=$(node -e "
const token = process.env.GITHUB_PERSONAL_ACCESS_TOKEN;
const owner = '${OWNER}';
const repo = '${REPO}';
const session = process.env.HOSTNAME || 'unknown-session';
const now = new Date().toISOString();

async function run() {
    const headers = {
        'Authorization': 'token ' + token,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'sandbox-evolve-lock'
    };
    try {
        const res = await fetch('https://api.github.com/repos/' + owner + '/' + repo + '/issues/1', {
            method: 'PATCH',
            headers: headers,
            body: JSON.stringify({
                body: 'LOCK_ACQUIRED_AT: ' + now + '\\nLOCK_SESSION: ' + session + '\\nLOCK_STATUS: acquired',
                labels: ['evolving'],
                state: 'open'
            }),
            signal: AbortSignal.timeout(15000)
        });
        if (res.ok) {
            console.log(JSON.stringify({status: 'acquired'}));
        } else {
            console.log(JSON.stringify({status: 'error', message: 'Reacquire failed'}));
        }
    } catch (e) {
        console.log(JSON.stringify({status: 'error', message: e.message}));
    }
}
run();
" 2>/dev/null)
            REACQUIRE_STATUS=$(echo "$REACQUIRE_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.status);" 2>/dev/null || echo "error")
            if [ "$REACQUIRE_STATUS" = "acquired" ]; then
                echo -e "${GREEN}✅ 锁获取成功（超时接管）${NC}"
                exit 0
            else
                echo -e "${RED}❌ 重新获取锁失败${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ 强制释放锁失败${NC}"
            exit 1
        fi
        ;;
    acquired)
        CREATED=$(echo "$LOCK_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(String(j.created||false));" 2>/dev/null || echo "false")
        if [ "$CREATED" = "true" ]; then
            echo -e "${GREEN}✅ 锁获取成功（新建 Issue #1）${NC}"
        else
            echo -e "${GREEN}✅ 锁获取成功${NC}"
        fi
        exit 0
        ;;
    error)
        MSG=$(echo "$LOCK_RESULT" | node -e "const d=require('fs').readFileSync(0,'utf8');const j=JSON.parse(d);process.stdout.write(j.message||'unknown error');" 2>/dev/null || echo "unknown error")
        echo -e "${RED}❌ 锁获取失败: ${MSG}${NC}"
        exit 1
        ;;
    *)
        echo -e "${RED}❌ 未知状态: ${STATUS}${NC}"
        exit 1
        ;;
esac
