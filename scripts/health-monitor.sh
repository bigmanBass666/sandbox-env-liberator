#!/bin/bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

HISTORY_DIR="/tmp/sandbox-health"
HISTORY_LOG="${HISTORY_DIR}/history.log"
NETWORK_PREV="${HISTORY_DIR}/network-prev.state"
TIMEOUT_CMD=5

CRITICAL_COUNT=0
WARNING_COUNT=0
OK_COUNT=0

mkdir -p "$HISTORY_DIR"

report_ok() {
    OK_COUNT=$((OK_COUNT + 1))
    echo -e "${GREEN}🟢 OK:${NC} $1"
}

report_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
    echo -e "${YELLOW}🟡 WARNING:${NC} $1"
    echo -e "  ${YELLOW}→ 修复建议:${NC} $2"
}

report_critical() {
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    echo -e "${RED}🔴 CRITICAL:${NC} $1"
    echo -e "  ${RED}→ 修复建议:${NC} $2"
}

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   SANDBOX HEALTH MONITOR                             ║"
echo "║   $(date '+%Y-%m-%d %H:%M:%S')                           ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# 1. 关键服务状态检查
# ============================================================
echo -e "${CYAN}━━━ 1. 关键服务状态检查 ━━━${NC}"

VNC_OK=false
if timeout $TIMEOUT_CMD node -e "
const net=require('net');
const s=net.createConnection(5900,'127.0.0.1');
s.setTimeout(3000);
s.on('connect',()=>{s.end();process.exit(0)});
s.on('error',()=>process.exit(1));
s.on('timeout',()=>{s.destroy();process.exit(1)});
" 2>/dev/null; then
    VNC_OK=true
    report_ok "VNC服务正常 (端口5900)"
else
    report_critical "VNC服务不可达 (端口5900)" "检查VNC服务: supervisorctl status vnc 或重启: supervisorctl restart vnc"
fi

CDP_OK=false
if timeout $TIMEOUT_CMD curl -s --connect-timeout 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/v1/cdp 2>/dev/null | grep -qE '^[0-9]+$'; then
    CDP_OK=true
    CDP_STATUS=$(timeout $TIMEOUT_CMD curl -s --connect-timeout 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/v1/cdp 2>/dev/null)
    if [ "$CDP_STATUS" = "200" ]; then
        report_ok "CDP端点正常 (端口8088, HTTP $CDP_STATUS)"
    else
        report_warning "CDP端点响应异常 (端口8088, HTTP $CDP_STATUS)" "检查CDP代理服务: ps aux | grep cdp"
    fi
else
    report_critical "CDP端点不可达 (端口8088)" "启动CDP代理: 检查agent-tool-host是否运行"
fi

PROXY_OK=false
if timeout $TIMEOUT_CMD curl -s --connect-timeout 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:18080 2>/dev/null | grep -qE '^[0-9]+$'; then
    PROXY_OK=true
    report_ok "HTTP代理可达 (端口18080)"
else
    report_warning "HTTP代理不可达 (端口18080)" "检查代理服务: supervisorctl status | grep proxy"
fi

CHROME_RUNNING=false
CHROME_PROCS=$(timeout $TIMEOUT_CMD ps aux 2>/dev/null | grep -i chrome | grep -v grep | wc -l | tr -d '[:space:]' || echo "0")
if [ "$CHROME_PROCS" -gt 0 ]; then
    CHROME_RUNNING=true
    report_ok "浏览器进程存在 (${CHROME_PROCS}个)"
else
    report_critical "浏览器进程不存在" "npx playwright install chromium && 启动浏览器"
fi

SUPERVISOR_OK=false
if timeout $TIMEOUT_CMD ps aux 2>/dev/null | grep -E 'supervisorctl|supervisord' | grep -v grep | grep -q .; then
    SUPERVISOR_OK=true
    report_ok "Supervisor进程运行中"
else
    report_warning "Supervisor进程未检测到" "启动Supervisor: supervisord -c /etc/supervisor/supervisord.conf"
fi

AGENT_OK=false
if timeout $TIMEOUT_CMD ps aux 2>/dev/null | grep 'agent-tool-host' | grep -v grep | grep -q .; then
    AGENT_OK=true
    report_ok "agent-tool-host进程运行中"
else
    report_warning "agent-tool-host进程未检测到" "启动agent-tool-host: 检查Supervisor配置或手动启动"
fi

echo ""

# ============================================================
# 2. 资源使用趋势记录
# ============================================================
echo -e "${CYAN}━━━ 2. 资源使用趋势记录 ━━━${NC}"

CPU_IDLE_1=$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null)
CPU_TOTAL_1=$(awk '/^cpu /{printf "%.0f", $2+$3+$4+$5+$6+$7+$8}' /proc/stat 2>/dev/null)
sleep 1
CPU_IDLE_2=$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null)
CPU_TOTAL_2=$(awk '/^cpu /{printf "%.0f", $2+$3+$4+$5+$6+$7+$8}' /proc/stat 2>/dev/null)

CPU_USAGE_PCT="N/A"
if [ -n "$CPU_IDLE_1" ] && [ -n "$CPU_IDLE_2" ] && [ -n "$CPU_TOTAL_1" ] && [ -n "$CPU_TOTAL_2" ]; then
    DIFF_IDLE=$((CPU_IDLE_2 - CPU_IDLE_1))
    DIFF_TOTAL=$((CPU_TOTAL_2 - CPU_TOTAL_1))
    if [ "$DIFF_TOTAL" -gt 0 ]; then
        CPU_USAGE_PCT=$(awk "BEGIN{printf \"%.1f\", 100 - ($DIFF_IDLE/$DIFF_TOTAL)*100}")
    fi
fi

if [ "$CPU_USAGE_PCT" != "N/A" ]; then
    CPU_INT=$(printf "%.0f" "$CPU_USAGE_PCT")
    if [ "$CPU_INT" -gt 90 ]; then
        report_warning "CPU使用率 ${CPU_USAGE_PCT}% (>90%)" "检查高CPU进程: ps aux --sort=-%cpu | head -10"
    else
        report_ok "CPU使用率 ${CPU_USAGE_PCT}%"
    fi
else
    report_warning "CPU使用率无法计算" "检查/proc/stat是否可读"
fi

MEM_INFO=$(timeout $TIMEOUT_CMD free 2>/dev/null | grep "^Mem:" || true)
MEM_USAGE_PCT="N/A"
if [ -n "$MEM_INFO" ]; then
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    if [ "$MEM_TOTAL" -gt 0 ] 2>/dev/null; then
        MEM_USAGE_PCT=$(awk "BEGIN{printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")
    fi
fi

if [ "$MEM_USAGE_PCT" != "N/A" ]; then
    MEM_INT=$(printf "%.0f" "$MEM_USAGE_PCT")
    if [ "$MEM_INT" -gt 90 ]; then
        report_critical "内存使用率 ${MEM_USAGE_PCT}% (>90%)" "清理缓存: apt-get clean && npm cache clean --force && sync && echo 3 > /proc/sys/vm/drop_caches"
    elif [ "$MEM_INT" -gt 80 ]; then
        report_warning "内存使用率 ${MEM_USAGE_PCT}% (>80%)" "清理缓存 (apt-get clean && npm cache clean --force)"
    else
        report_ok "内存使用率 ${MEM_USAGE_PCT}%"
    fi
else
    report_warning "内存使用率无法获取" "检查free命令是否可用"
fi

DISK_USAGE_PCT="N/A"
DISK_INFO=$(timeout $TIMEOUT_CMD df / 2>/dev/null | tail -1 || true)
if [ -n "$DISK_INFO" ]; then
    DISK_USAGE_PCT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
fi

if [ "$DISK_USAGE_PCT" != "N/A" ]; then
    if [ "$DISK_USAGE_PCT" -gt 90 ]; then
        report_critical "磁盘使用率 ${DISK_USAGE_PCT}% (>90%)" "清理磁盘: apt-get clean && npm cache clean --force && rm -rf /tmp/* /root/.cache/*"
    elif [ "$DISK_USAGE_PCT" -gt 80 ]; then
        report_warning "磁盘使用率 ${DISK_USAGE_PCT}% (>80%)" "清理缓存和不必要文件: apt-get clean && npm cache clean --force"
    else
        report_ok "磁盘使用率 ${DISK_USAGE_PCT}%"
    fi
else
    report_warning "磁盘使用率无法获取" "检查df命令是否可用"
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "${TIMESTAMP},${CPU_USAGE_PCT},${MEM_USAGE_PCT},${DISK_USAGE_PCT}" >> "$HISTORY_LOG"
echo -e "  ${CYAN}→ 资源数据已记录到 ${HISTORY_LOG}${NC}"

echo ""

# ============================================================
# 3. 网络连通性变化检测
# ============================================================
echo -e "${CYAN}━━━ 3. 网络连通性变化检测 ━━━${NC}"

NODE_NET_OK=false
NODE_NET_TIME=""
NODE_START=$(date +%s%N 2>/dev/null || date +%s)
NODE_RESULT=$(timeout 10 node -e "
const start=Date.now();
fetch('https://httpbin.org/ip',{signal:AbortSignal.timeout(8000)})
  .then(r=>{if(r.ok)console.log('OK:'+(Date.now()--start));else console.log('FAIL')})
  .catch(()=>console.log('FAIL'));
" 2>/dev/null || echo "FAIL")
NODE_END=$(date +%s%N 2>/dev/null || date +%s)

if echo "$NODE_RESULT" | grep -q "^OK:"; then
    NODE_NET_OK=true
    NODE_NET_TIME=$(echo "$NODE_RESULT" | cut -d: -f2)
    report_ok "Node.js fetch可达 (耗时${NODE_NET_TIME}ms)"
else
    report_warning "Node.js fetch不可达" "检查DNS和代理设置: cat /etc/resolv.conf && echo $http_proxy"
fi

CURL_NET_OK=false
CURL_NET_TIME=""
CURL_START=$(date +%s%N 2>/dev/null || date +%s)
CURL_RESULT=$(timeout 10 curl -s --connect-timeout 5 -o /dev/null -w '%{http_code}:%{time_total}' https://httpbin.org/ip 2>/dev/null || echo "000:0")
CURL_END=$(date +%s%N 2>/dev/null || date +%s)

CURL_HTTP_CODE=$(echo "$CURL_RESULT" | cut -d: -f1)
CURL_TIME_SEC=$(echo "$CURL_RESULT" | cut -d: -f2)

if [ "$CURL_HTTP_CODE" != "000" ] && [ -n "$CURL_HTTP_CODE" ]; then
    CURL_NET_OK=true
    CURL_NET_TIME=$(awk "BEGIN{printf \"%.0f\", ${CURL_TIME_SEC}*1000}")
    report_ok "curl可达 (HTTP ${CURL_HTTP_CODE}, 耗时${CURL_NET_TIME}ms)"
else
    report_warning "curl不可达" "检查网络连接和代理配置"
fi

PREV_NODE_OK=""
PREV_CURL_OK=""
if [ -f "$NETWORK_PREV" ]; then
    PREV_NODE_OK=$(awk -F, 'NR==1{print $1}' "$NETWORK_PREV")
    PREV_CURL_OK=$(awk -F, 'NR==1{print $2}' "$NETWORK_PREV")
fi

if [ "$PREV_NODE_OK" = "true" ] && [ "$NODE_NET_OK" = "false" ]; then
    report_critical "Node.js网络从可用变为不可用！" "检查网络接口: ip addr && 检查DNS: nslookup httpbin.org"
fi
if [ "$PREV_CURL_OK" = "true" ] && [ "$CURL_NET_OK" = "false" ]; then
    report_critical "curl网络从可用变为不可用！" "检查网络连接: ping -c 1 httpbin.org && 检查代理: env | grep -i proxy"
fi

echo "${NODE_NET_OK},${CURL_NET_OK}" > "$NETWORK_PREV"

echo ""

# ============================================================
# 4. 进程存活状态监控
# ============================================================
echo -e "${CYAN}━━━ 4. 进程存活状态监控 ━━━${NC}"

PROCESS_LIST="chrome|node|agent-tool-host|supervisord"

for proc_name in chrome node agent-tool-host supervisord; do
    PROC_COUNT=$(timeout $TIMEOUT_CMD ps aux 2>/dev/null | grep -E "(^|/)"$proc_name | grep -v grep | wc -l | tr -d '[:space:]' || echo "0")
    if [ "$PROC_COUNT" -gt 0 ]; then
        report_ok "进程 ${proc_name} 存活 (${PROC_COUNT}个实例)"
    else
        case "$proc_name" in
            chrome)
                report_critical "进程 ${proc_name} 不存在" "npx playwright install chromium"
                ;;
            node)
                report_critical "进程 ${proc_name} 不存在" "Node.js服务可能未启动，检查Supervisor配置"
                ;;
            agent-tool-host)
                report_warning "进程 ${proc_name} 不存在" "检查agent-tool-host是否需要启动: supervisorctl status"
                ;;
            supervisord)
                report_warning "进程 ${proc_name} 不存在" "启动Supervisor: supervisord -c /etc/supervisor/supervisord.conf"
                ;;
        esac
    fi
done

echo ""

# ============================================================
# 5. 异常报告和修复建议生成
# ============================================================
echo -e "${CYAN}━━━ 5. 异常报告与修复建议汇总 ━━━${NC}"
echo ""

if [ "$CRITICAL_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}🎉 所有检查项均正常，沙箱环境运行良好！${NC}"
else
    if [ "$CRITICAL_COUNT" -gt 0 ]; then
        echo -e "${RED}🔴 发现 ${CRITICAL_COUNT} 个严重问题需要立即处理${NC}"
    fi
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}🟡 发现 ${WARNING_COUNT} 个警告项建议关注${NC}"
    fi
    echo ""
    echo -e "${CYAN}建议修复优先级：${NC}"
    echo "  1. 浏览器进程缺失 → npx playwright install chromium"
    echo "  2. CDP/VNC服务不可达 → supervisorctl restart all"
    echo "  3. 内存/磁盘高占用 → apt-get clean && npm cache clean --force"
    echo "  4. 网络不可达 → 检查DNS和代理配置"
    echo "  5. agent-tool-host缺失 → 检查Supervisor配置并重启"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   健康监控完成                                       ║"
echo "║   🟢 正常: $OK_COUNT    🟡 警告: $WARNING_COUNT    🔴 严重: $CRITICAL_COUNT"
echo "╚═══════════════════════════════════════════════════════╝"

if [ "$CRITICAL_COUNT" -gt 0 ]; then
    exit 2
elif [ "$WARNING_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
