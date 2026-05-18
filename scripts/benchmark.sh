#!/bin/bash
set -uo pipefail

BENCHMARK_FILE="/workspace/references/performance-benchmarks.jsonl"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ROUND="${1:-unknown}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() { echo -e "${CYAN}[BENCH]${NC} $1"; }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   PERFORMANCE BENCHMARK - Round $ROUND"
echo "║   $TIMESTAMP"
echo "╚═══════════════════════════════════════════════════════╝"

RESULT="{\"timestamp\":\"$TIMESTAMP\",\"round\":\"$ROUND\""

RESULT+=",\"hostname\":\"$(hostname 2>/dev/null || echo unknown)\""

log "Measuring network speed..."
if command -v curl &>/dev/null; then
    NET_SPEED=$(curl -x http://127.0.0.1:18080 -s -o /dev/null -w '%{speed_download}' --connect-timeout 10 --max-time 15 https://npmmirror.com/mirrors/npm/index.json 2>/dev/null || echo "0")
    NET_LATENCY=$(curl -x http://127.0.0.1:18080 -s -o /dev/null -w '%{time_total}' --connect-timeout 10 --max-time 15 https://npmmirror.com/mirrors/npm/index.json 2>/dev/null || echo "0")
    RESULT+=",\"net_speed_bps\":$NET_SPEED"
    RESULT+=",\"net_latency_s\":$NET_LATENCY"
    pass "Network: $(echo "$NET_SPEED" | awk '{printf "%.0f KB/s", $1/1024}')"
else
    RESULT+=",\"net_speed_bps\":0"
    RESULT+=",\"net_latency_s\":0"
    warn "curl not available"
fi

log "Measuring DNS resolution..."
DNS_TIME=$(dig +stats google.com 2>/dev/null | grep "Query time" | awk '{print $4}' || echo "0")
RESULT+=",\"dns_ms\":$DNS_TIME"
pass "DNS: ${DNS_TIME}ms"

log "Measuring disk I/O..."
if [ -d /workspace ]; then
    DISK_AVAIL=$(df -B1 /workspace 2>/dev/null | tail -1 | awk '{print $4}')
    DISK_USED_PCT=$(df /workspace 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    DISK_TOTAL=$(df -B1 /workspace 2>/dev/null | tail -1 | awk '{print $2}')
    RESULT+=",\"disk_available_bytes\":$DISK_AVAIL"
    RESULT+=",\"disk_used_pct\":$DISK_USED_PCT"
    RESULT+=",\"disk_total_bytes\":$DISK_TOTAL"
    pass "Disk: $(echo "$DISK_AVAIL" | awk '{printf "%.1f GB available", $1/1073741824}')"
fi

log "Measuring memory..."
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
MEM_AVAIL_KB=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
RESULT+=",\"mem_total_kb\":${MEM_TOTAL_KB:-0}"
RESULT+=",\"mem_avail_kb\":${MEM_AVAIL_KB:-0}"
pass "Memory: $(echo "${MEM_AVAIL_KB:-0}" | awk '{printf "%.1f GB available / %.1f GB total", $1/1048576, '${MEM_TOTAL_KB:-0}'/1048576}')"

log "Measuring CPU..."
CPU_COUNT=$(nproc 2>/dev/null || echo "0")
CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "unknown")
CPU_LOAD_1M=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo "0")
RESULT+=",\"cpu_count\":$CPU_COUNT"
RESULT+=",\"cpu_load_1m\":$CPU_LOAD_1M"
RESULT+=",\"cpu_model\":\"$CPU_MODEL\""
pass "CPU: $CPU_COUNT cores, load $CPU_LOAD_1M"

log "Measuring service status..."
SERVICES_RUNNING=0
SERVICES_TOTAL=5

if redis-cli ping 2>/dev/null | grep -q PONG; then
    SERVICES_RUNNING=$((SERVICES_RUNNING + 1))
    REDIS_STARTUP=$( (time redis-cli ping 2>/dev/null) 2>&1 | grep real | awk '{print $2}')
    RESULT+=",\"redis_status\":\"running\""
else
    RESULT+=",\"redis_status\":\"down\""
fi

if pg_isready -h localhost -p 5432 2>/dev/null | grep -q "accepting"; then
    SERVICES_RUNNING=$((SERVICES_RUNNING + 1))
    RESULT+=",\"postgresql_status\":\"running\""
else
    RESULT+=",\"postgresql_status\":\"down\""
fi

if echo "stats" | nc -w1 localhost 11211 2>/dev/null | grep -q STAT; then
    SERVICES_RUNNING=$((SERVICES_RUNNING + 1))
    RESULT+=",\"memcached_status\":\"running\""
else
    RESULT+=",\"memcached_status\":\"down\""
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null | grep -q "200"; then
    SERVICES_RUNNING=$((SERVICES_RUNNING + 1))
    RESULT+=",\"lighttpd_status\":\"running\""
else
    RESULT+=",\"lighttpd_status\":\"down\""
fi

if echo -e "stats\r\n" | nc -w1 localhost 11300 2>/dev/null | grep -q "OK"; then
    SERVICES_RUNNING=$((SERVICES_RUNNING + 1))
    RESULT+=",\"beanstalkd_status\":\"running\""
else
    RESULT+=",\"beanstalkd_status\":\"down\""
fi

RESULT+=",\"services_running\":$SERVICES_RUNNING"
RESULT+=",\"services_total\":$SERVICES_TOTAL"
pass "Services: $SERVICES_RUNNING/$SERVICES_TOTAL running"

log "Measuring package managers..."
NPM_VER=$(npm --version 2>/dev/null || echo "N/A")
PIP_VER=$(pip --version 2>/dev/null | awk '{print $2}' || echo "N/A")
GO_VER=$(go version 2>/dev/null | awk '{print $3}' || echo "N/A")
CARGO_VER=$(cargo --version 2>/dev/null | awk '{print $2}' || echo "N/A")
RESULT+=",\"npm_version\":\"$NPM_VER\""
RESULT+=",\"pip_version\":\"$PIP_VER\""
RESULT+=",\"go_version\":\"$GO_VER\""
RESULT+=",\"cargo_version\":\"$CARGO_VER\""
pass "Package managers: npm=$NPM_VER pip=$PIP_VER go=$GO_VER cargo=$CARGO_VER"

log "Measuring CDP browser..."
CDP_STATUS="unavailable"
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9222/json/version 2>/dev/null | grep -q "200"; then
    CDP_STATUS="available"
    CDP_VER=$(curl -s http://127.0.0.1:9222/json/version 2>/dev/null | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    RESULT+=",\"cdp_browser\":\"$CDP_VER\""
fi
RESULT+=",\"cdp_status\":\"$CDP_STATUS\""
pass "CDP Browser: $CDP_STATUS"

RESULT+="}"

mkdir -p "$(dirname "$BENCHMARK_FILE")"
echo "$RESULT" >> "$BENCHMARK_FILE"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   BENCHMARK COMPLETE                                  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo "  Results appended to: $BENCHMARK_FILE"
echo "  Total entries: $(wc -l < "$BENCHMARK_FILE")"
