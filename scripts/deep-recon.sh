#!/bin/bash
# ============================================================
# Deep Platform Architecture Reconnaissance Script
# Probes internal platform infrastructure: Supervisor, MCP,
# port mapping, Kubernetes, Node.js runtime, agent-tool-host
# ============================================================

set -uo pipefail

RECON_DIR="/tmp/sandbox-deep-recon"
mkdir -p "$RECON_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; echo "PASS|$1" >> "$RECON_DIR/results.txt"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; echo "FAIL|$1" >> "$RECON_DIR/results.txt"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; echo "WARN|$1" >> "$RECON_DIR/results.txt"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; echo "INFO|$1" >> "$RECON_DIR/results.txt"; }
section() { echo ""; echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  DOMAIN $1: $2${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

> "$RECON_DIR/results.txt"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   DEEP PLATFORM ARCHITECTURE RECONNAISSANCE v1.0     ║"
echo "║   6-Domain Internal Infrastructure Probe             ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# ============================================================
# DOMAIN 1: SUPERVISOR CONFIG & PROCESS MANAGEMENT
# ============================================================
section "1" "SUPERVISOR CONFIG & PROCESS MANAGEMENT"

echo "--- 1.1 Supervisord Configuration File ---"
SUPERVISOR_CONF="/app/supervisord.conf"
if [ -f "$SUPERVISOR_CONF" ]; then
    pass "supervisord.conf found: $SUPERVISOR_CONF"
    CONF_SIZE=$(wc -c < "$SUPERVISOR_CONF")
    CONF_LINES=$(wc -l < "$SUPERVISOR_CONF")
    info "  Size: ${CONF_SIZE} bytes, ${CONF_LINES} lines"

    echo "--- 1.2 [program:*] Section Parsing ---"
    PROGRAM_SECTIONS=$(grep -c '^\[program:' "$SUPERVISOR_CONF" 2>/dev/null || echo 0)
    if [ "$PROGRAM_SECTIONS" -gt 0 ]; then
        pass "Found $PROGRAM_SECTIONS [program:*] sections"
        grep '^\[program:' "$SUPERVISOR_CONF" 2>/dev/null | while read line; do
            PROG_NAME=$(echo "$line" | sed 's/\[program:\(.*\)\]/\1/')
            info "  Program: $PROG_NAME"
        done

        echo "--- 1.3 Program Command & Autostart Details ---"
        CURRENT_PROG=""
        while IFS= read -r line; do
            if echo "$line" | grep -q '^\[program:'; then
                CURRENT_PROG=$(echo "$line" | sed 's/\[program:\(.*\)\]/\1/')
            elif [ -n "$CURRENT_PROG" ]; then
                if echo "$line" | grep -qE '^(command|autostart|autorestart|directory|user|environment|priority|stdout_logfile|redirect_stderr)='; then
                    KEY=$(echo "$line" | cut -d= -f1 | xargs)
                    VAL=$(echo "$line" | cut -d= -f2- | xargs)
                    info "    [$CURRENT_PROG] $KEY=$VAL"
                fi
            fi
        done < "$SUPERVISOR_CONF"
    else
        warn "No [program:*] sections found in supervisord.conf"
    fi

    echo "--- 1.4 Include Directories ---"
    INCLUDE_DIR=$(grep '^\[include\]' -A5 "$SUPERVISOR_CONF" 2>/dev/null | grep '^files=' | cut -d= -f2 | xargs)
    if [ -n "$INCLUDE_DIR" ]; then
        info "Include files pattern: $INCLUDE_DIR"
        for inc_file in $INCLUDE_DIR; do
            for f in /app/etc/supervisor.d/${inc_file}; do
                if [ -f "$f" ]; then
                    pass "  Included config: $f"
                fi
            done
        done 2>/dev/null
    else
        info "No [include] section in supervisord.conf"
    fi
else
    fail "supervisord.conf NOT FOUND at $SUPERVISOR_CONF"
    info "Searching alternative locations..."
    for alt in /etc/supervisor/supervisord.conf /etc/supervisord.conf /usr/local/etc/supervisord.conf; do
        if [ -f "$alt" ]; then
            pass "  Found at: $alt"
        fi
    done
fi

echo "--- 1.5 supervisorctl Availability ---"
if which supervisorctl &>/dev/null; then
    pass "supervisorctl: AVAILABLE ($(which supervisorctl))"
    STATUS_OUTPUT=$(timeout 5 supervisorctl status 2>&1)
    if echo "$STATUS_OUTPUT" | grep -qiE "RUNNING|STOPPED|FATAL|STARTING|BACKOFF"; then
        pass "supervisorctl status: ACCESSIBLE"
        echo "$STATUS_OUTPUT" | while read line; do
            [ -n "$line" ] && info "  $line"
        done
    else
        warn "supervisorctl status: FAILED or NOT CONNECTED"
        info "  Output: $(echo "$STATUS_OUTPUT" | head -3)"
    fi
else
    fail "supervisorctl: NOT IN PATH"
    for alt in /usr/local/bin/supervisorctl /usr/bin/supervisorctl /app/bin/supervisorctl; do
        if [ -x "$alt" ]; then
            pass "  Found at: $alt"
        fi
    done
fi

echo "--- 1.6 Supervisord Process ---"
SUPERVISOR_PID=$(timeout 3 pgrep -f "supervisord" 2>/dev/null | head -1)
if [ -n "$SUPERVISOR_PID" ]; then
    pass "supervisord process running (PID: $SUPERVISOR_PID)"
    SUPERVISOR_CMD=$(timeout 3 ps -p "$SUPERVISOR_PID" -o args= 2>/dev/null)
    info "  Command: ${SUPERVISOR_CMD:-unknown}"
else
    warn "supervisord process NOT DETECTED via pgrep"
fi

# ============================================================
# DOMAIN 2: MCP PROCESS IDENTIFICATION & CONFIG
# ============================================================
section "2" "MCP PROCESS IDENTIFICATION & CONFIG"

echo "--- 2.1 MCP Server Configuration ---"
MCP_CONF="/app/etc/mcp_servers.json"
if [ -f "$MCP_CONF" ]; then
    pass "mcp_servers.json found: $MCP_CONF"
    MCP_SIZE=$(wc -c < "$MCP_CONF")
    info "  Size: ${MCP_SIZE} bytes"

    echo "--- 2.2 MCP Server Entries ---"
    if which jq &>/dev/null; then
        MCP_SERVERS=$(timeout 5 jq -r 'keys[]' "$MCP_CONF" 2>/dev/null)
        if [ -n "$MCP_SERVERS" ]; then
            SERVER_COUNT=$(echo "$MCP_SERVERS" | wc -l)
            pass "Found $SERVER_COUNT MCP server entries"
            echo "$MCP_SERVERS" | while read srv; do
                [ -n "$srv" ] && info "  Server: $srv"
            done

            echo "--- 2.3 MCP Server Command Details ---"
            for srv in $MCP_SERVERS; do
                CMD=$(timeout 5 jq -r ".[\"$srv\"].command // empty" "$MCP_CONF" 2>/dev/null)
                ARGS=$(timeout 5 jq -r ".[\"$srv\"].args // [] | join(\" \")" "$MCP_CONF" 2>/dev/null)
                ENV_KEYS=$(timeout 5 jq -r ".[\"$srv\"].env // {} | keys[] as \$k | \"\(\$k)=\(.[\$k])\"" "$MCP_CONF" 2>/dev/null)
                if [ -n "$CMD" ]; then
                    info "  [$srv] command: $CMD ${ARGS}"
                fi
                if [ -n "$ENV_KEYS" ]; then
                    echo "$ENV_KEYS" | while read ek; do
                        [ -n "$ek" ] && info "    env: $ek"
                    done
                fi
            done
        else
            warn "Could not parse MCP server keys (jq returned empty)"
        fi
    else
        warn "jq not available, attempting raw parse"
        grep -oP '"[^"]+"\s*:' "$MCP_CONF" 2>/dev/null | head -20 | while read key; do
            info "  Key: $key"
        done
    fi
else
    fail "mcp_servers.json NOT FOUND at $MCP_CONF"
    for alt in /app/mcp_servers.json /etc/mcp_servers.json /app/config/mcp_servers.json; do
        if [ -f "$alt" ]; then
            pass "  Found at: $alt"
        fi
    done
fi

echo "--- 2.4 MCP Process Detection via ps ---"
MCP_KEYWORDS="context7 playwright-mcp memory sequential-thinking mcp brave-search filesystem"
for kw in $MCP_KEYWORDS; do
    PROCS=$(timeout 5 ps aux 2>/dev/null | grep -i "$kw" | grep -v grep)
    if [ -n "$PROCS" ]; then
        pass "MCP process detected: $kw"
        echo "$PROCS" | while read proc_line; do
            PID=$(echo "$proc_line" | awk '{print $2}')
            MEM=$(echo "$proc_line" | awk '{print $6}')
            CMD=$(echo "$proc_line" | awk '{for(i=11;i<=NF;i++) printf "%s ",$i; print ""}')
            info "  PID=$PID MEM=${MEM}KB CMD=$(echo "$CMD" | head -c 120)"
        done
    else
        info "MCP process NOT RUNNING: $kw"
    fi
done

echo "--- 2.5 MCP Process Summary Table ---"
MCP_ALL_PROCS=$(timeout 5 ps aux 2>/dev/null | grep -iE "mcp|context7|playwright-mcp|memory|sequential-thinking|brave-search" | grep -v grep)
if [ -n "$MCP_ALL_PROCS" ]; then
    PROC_COUNT=$(echo "$MCP_ALL_PROCS" | wc -l)
    pass "Total MCP-related processes: $PROC_COUNT"
    info "  PID       MEM(KB)   COMMAND"
    info "  --------  --------  ----------------------------------------"
    echo "$MCP_ALL_PROCS" | while read pline; do
        P=$(echo "$pline" | awk '{print $2}')
        M=$(echo "$pline" | awk '{print $6}')
        C=$(echo "$pline" | awk '{for(i=11;i<=NF;i++) printf "%s ",$i; print ""}' | head -c 80)
        info "  $(printf '%-8s' "$P")  $(printf '%-8s' "$M")  $C"
    done
else
    warn "No MCP-related processes detected via ps"
fi

# ============================================================
# DOMAIN 3: PORT-SERVICE MAPPING
# ============================================================
section "3" "PORT-SERVICE MAPPING"

echo "--- 3.1 Listening Ports (ss -tlnp) ---"
SS_OUTPUT=$(timeout 5 ss -tlnp 2>/dev/null)
if [ -n "$SS_OUTPUT" ]; then
    pass "ss -tlnp: EXECUTABLE"
    LISTEN_LINES=$(echo "$SS_OUTPUT" | tail -n +2 | grep "LISTEN")
    LISTEN_COUNT=$(echo "$LISTEN_LINES" | grep -c "LISTEN" 2>/dev/null || echo 0)
    info "Found $LISTEN_COUNT listening ports"

    PORT_MAP_FILE="$RECON_DIR/port_map.txt"
    > "$PORT_MAP_FILE"

    echo "$LISTEN_LINES" | while read lline; do
        PORT=$(echo "$lline" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        ADDR=$(echo "$lline" | awk '{print $4}' | rev | cut -d: -f2- | rev)
        PROC_INFO=$(echo "$lline" | grep -oP 'users:\(\("\K[^"]+' 2>/dev/null || echo "unknown")
        PID_INFO=$(echo "$lline" | grep -oP 'pid=\K[0-9]+' 2>/dev/null || echo "-")
        if [ -n "$PORT" ] && [ "$PORT" -eq "$PORT" ] 2>/dev/null; then
            info "  Port $PORT: addr=$ADDR pid=$PID_INFO proc=$PROC_INFO"
            echo "$PORT|$PID_INFO|$PROC_INFO" >> "$PORT_MAP_FILE"
        fi
    done
else
    fail "ss -tlnp: FAILED or NOT AVAILABLE"
    NETSTAT_OUTPUT=$(timeout 5 netstat -tlnp 2>/dev/null)
    if [ -n "$NETSTAT_OUTPUT" ]; then
        pass "netstat -tlnp: FALLBACK AVAILABLE"
        echo "$NETSTAT_OUTPUT" | grep "LISTEN" | while read nline; do
            info "  $nline"
        done
    else
        fail "netstat -tlnp: ALSO NOT AVAILABLE"
    fi
fi

echo "--- 3.2 HTTP Service Probing ---"
if [ -f "$PORT_MAP_FILE" ] && [ -s "$PORT_MAP_FILE" ]; then
    HTTP_PORTS=""
    while read pentry; do
        P=$(echo "$pentry" | cut -d'|' -f1)
        if [ "$P" -ge 1 ] && [ "$P" -le 65535 ] 2>/dev/null; then
            HTTP_PORTS="$HTTP_PORTS $P"
        fi
    done < "$PORT_MAP_FILE"

    for port in $HTTP_PORTS; do
        HTTP_RESP=$(timeout 3 curl -s -o /dev/null -w "%{http_code}|%{content_type}|%{redirect_url}" "http://127.0.0.1:$port/" 2>/dev/null)
        if [ -n "$HTTP_RESP" ] && [ "$HTTP_RESP" != "000||" ]; then
            HTTP_CODE=$(echo "$HTTP_RESP" | cut -d'|' -f1)
            CONTENT_TYPE=$(echo "$HTTP_RESP" | cut -d'|' -f2)
            REDIRECT=$(echo "$HTTP_RESP" | cut -d'|' -f3)
            pass "  Port $port HTTP: status=$HTTP_CODE type=$CONTENT_TYPE"
            [ -n "$REDIRECT" ] && info "    Redirect: $REDIRECT"

            TITLE=$(timeout 3 curl -s "http://127.0.0.1:$port/" 2>/dev/null | grep -oP '<title>\K[^<]+' | head -1)
            [ -n "$TITLE" ] && info "    Title: $TITLE"
        else
            info "  Port $port HTTP: no response or non-HTTP"
        fi
    done
else
    info "No port map file available, probing common ports..."
    for port in 3000 4000 5000 5173 8000 8080 8443 9000 9090 9222; do
        HTTP_RESP=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/" 2>/dev/null)
        if [ -n "$HTTP_RESP" ] && [ "$HTTP_RESP" != "000" ]; then
            pass "  Port $port HTTP: status=$HTTP_RESP"
        fi
    done
fi

echo "--- 3.3 Port-Service-Process Mapping Table ---"
if [ -f "$PORT_MAP_FILE" ] && [ -s "$PORT_MAP_FILE" ]; then
    info "  PORT      PID       PROCESS          HTTP_STATUS"
    info "  --------  --------  ---------------  -----------"
    while read pentry; do
        P=$(echo "$pentry" | cut -d'|' -f1)
        PID=$(echo "$pentry" | cut -d'|' -f2)
        PROC=$(echo "$pentry" | cut -d'|' -f3)
        HTTP_CODE=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$P/" 2>/dev/null)
        [ "$HTTP_CODE" = "000" ] && HTTP_CODE="-"
        info "  $(printf '%-8s' "$P")  $(printf '%-8s' "$PID")  $(printf '%-15s' "$PROC")  $HTTP_CODE"
    done < "$PORT_MAP_FILE"
else
    warn "No port mapping data available"
fi

# ============================================================
# DOMAIN 4: KUBERNETES ENVIRONMENT
# ============================================================
section "4" "KUBERNETES ENVIRONMENT"

echo "--- 4.1 Kubernetes Service Environment ---"
K8S_HOST="${KUBERNETES_SERVICE_HOST:-}"
K8S_PORT="${KUBERNETES_SERVICE_PORT:-}"
if [ -n "$K8S_HOST" ]; then
    pass "KUBERNETES_SERVICE_HOST: $K8S_HOST"
    pass "KUBERNETES_SERVICE_PORT: $K8S_PORT"
    K8S_API="https://${K8S_HOST}:${K8S_PORT}"
    info "Kubernetes API endpoint: $K8S_API"
else
    info "KUBERNETES_SERVICE_HOST: NOT SET (likely not in K8s)"
fi

echo "--- 4.2 Service Account Token ---"
SA_DIR="/var/run/secrets/kubernetes.io/serviceaccount"
if [ -d "$SA_DIR" ]; then
    pass "Service account directory exists: $SA_DIR"

    if [ -f "$SA_DIR/token" ]; then
        TOKEN_SIZE=$(wc -c < "$SA_DIR/token")
        TOKEN_PREVIEW=$(head -c 30 "$SA_DIR/token" 2>/dev/null)
        pass "Service account token: EXISTS (${TOKEN_SIZE} bytes, preview: ${TOKEN_PREVIEW}...)"
    else
        fail "Service account token: NOT FOUND"
    fi

    if [ -f "$SA_DIR/namespace" ]; then
        NAMESPACE=$(cat "$SA_DIR/namespace" 2>/dev/null)
        pass "Namespace: ${NAMESPACE:-unknown}"
    else
        info "Namespace file: NOT FOUND"
    fi

    if [ -f "$SA_DIR/ca.crt" ]; then
        CA_SIZE=$(wc -c < "$SA_DIR/ca.crt")
        pass "Cluster CA certificate: EXISTS (${CA_SIZE} bytes)"
    else
        info "Cluster CA certificate: NOT FOUND"
    fi
else
    info "Service account directory: NOT FOUND (not in K8s or no SA mounted)"
fi

echo "--- 4.3 Kubernetes Environment Variables ---"
K8S_ENV_VARS=$(env 2>/dev/null | grep -iE "^KUBERNETES_" | sort)
if [ -n "$K8S_ENV_VARS" ]; then
    K8S_VAR_COUNT=$(echo "$K8S_ENV_VARS" | wc -l)
    pass "Found $K8S_VAR_COUNT KUBERNETES_* environment variables"
    echo "$K8S_ENV_VARS" | while read kvar; do
        if echo "$kvar" | grep -qi "token\|key\|secret\|password"; then
            info "  $(echo "$kvar" | cut -d= -f1)=***REDACTED***"
        else
            info "  $kvar"
        fi
    done
else
    info "No KUBERNETES_* environment variables found"
fi

echo "--- 4.4 kubectl Availability ---"
if which kubectl &>/dev/null; then
    pass "kubectl: AVAILABLE ($(which kubectl))"
    K8S_VERSION=$(timeout 5 kubectl version --client 2>/dev/null | head -2)
    info "  kubectl client version: $K8S_VERSION"

    if [ -n "$K8S_HOST" ]; then
        K8S_CLUSTER_INFO=$(timeout 5 kubectl cluster-info 2>&1 | head -3)
        if echo "$K8S_CLUSTER_INFO" | grep -qi "running"; then
            pass "Kubernetes cluster: ACCESSIBLE"
        else
            warn "Kubernetes cluster: NOT ACCESSIBLE"
            info "  $(echo "$K8S_CLUSTER_INFO" | head -2)"
        fi

        NODE_INFO=$(timeout 5 kubectl get nodes -o wide 2>&1 | head -5)
        if echo "$NODE_INFO" | grep -qiE "Ready|NotReady"; then
            info "  Node info:"
            echo "$NODE_INFO" | while read nline; do
                info "    $nline"
            done
        fi
    fi
else
    info "kubectl: NOT INSTALLED"
fi

echo "--- 4.5 Pod Metadata ---"
if [ -f "/etc/hostname" ]; then
    HOSTNAME_VAL=$(cat /etc/hostname 2>/dev/null)
    info "Hostname: $HOSTNAME_VAL (may be Pod name in K8s)"
fi
POD_NAME="${HOSTNAME:-}"
if [ -n "$POD_NAME" ]; then
    info "POD name (from HOSTNAME): $POD_NAME"
fi

# ============================================================
# DOMAIN 5: NODE.JS RUNTIME & PRELOAD CONFIG
# ============================================================
section "5" "NODE.JS RUNTIME & PRELOAD CONFIG"

echo "--- 5.1 Preload Module (preload.cjs) ---"
PRELOAD_FILE="/app/mcp_proxy_bootstrap/preload.cjs"
if [ -f "$PRELOAD_FILE" ]; then
    pass "preload.cjs found: $PRELOAD_FILE"
    PRELOAD_SIZE=$(wc -c < "$PRELOAD_FILE")
    PRELOAD_LINES=$(wc -l < "$PRELOAD_FILE")
    info "  Size: ${PRELOAD_SIZE} bytes, ${PRELOAD_LINES} lines"

    echo "--- 5.2 Preload Module Content Analysis ---"
    REQUIRES=$(grep -E "require\(" "$PRELOAD_FILE" 2>/dev/null)
    if [ -n "$REQUIRES" ]; then
        REQ_COUNT=$(echo "$REQUIRES" | wc -l)
        info "  Found $REQ_COUNT require() calls"
        echo "$REQUIRES" | while read rline; do
            info "    $rline"
        done
    fi

    MODULE_EXPORTS=$(grep -E "module\.exports|exports\." "$PRELOAD_FILE" 2>/dev/null)
    if [ -n "$MODULE_EXPORTS" ]; then
        info "  Module exports detected:"
        echo "$MODULE_EXPORTS" | while read mline; do
            info "    $mline"
        done
    fi

    PROCESS_ON=$(grep -E "process\.(on|prependEventListener)" "$PRELOAD_FILE" 2>/dev/null)
    if [ -n "$PROCESS_ON" ]; then
        info "  Process event listeners:"
        echo "$PROCESS_ON" | while read pline; do
            info "    $pline"
        done
    fi

    GLOBAL_PATCHES=$(grep -E "global\.(fetch|WebSocket|FormData|Headers|Request|Response)" "$PRELOAD_FILE" 2>/dev/null)
    if [ -n "$GLOBAL_PATCHES" ]; then
        info "  Global API patches:"
        echo "$GLOBAL_PATCHES" | while read gline; do
            info "    $gline"
        done
    fi
else
    fail "preload.cjs NOT FOUND at $PRELOAD_FILE"
    for alt in /app/preload.cjs /app/mcp_proxy_bootstrap/preload.js /app/bootstrap/preload.cjs; do
        if [ -f "$alt" ]; then
            pass "  Found at: $alt"
        fi
    done
fi

echo "--- 5.3 MCP Proxy Bootstrap Directory ---"
BOOTSTRAP_DIR="/app/mcp_proxy_bootstrap"
if [ -d "$BOOTSTRAP_DIR" ]; then
    pass "Bootstrap directory exists: $BOOTSTRAP_DIR"
    BOOTSTRAP_FILES=$(ls -la "$BOOTSTRAP_DIR" 2>/dev/null)
    echo "$BOOTSTRAP_FILES" | tail -n +2 | while read bfile; do
        info "  $bfile"
    done
else
    warn "Bootstrap directory NOT FOUND: $BOOTSTRAP_DIR"
fi

echo "--- 5.4 NODE_OPTIONS Analysis ---"
NODE_OPTS="${NODE_OPTIONS:-}"
if [ -n "$NODE_OPTS" ]; then
    pass "NODE_OPTIONS is set"
    echo "$NODE_OPTS" | tr ' ' '\n' | while read opt; do
        [ -n "$opt" ] && info "  $opt"
    done

    PRELOAD_FLAG=$(echo "$NODE_OPTS" | grep -oP '(?<=--require\s|--require=)[^\s]+' 2>/dev/null)
    if [ -n "$PRELOAD_FLAG" ]; then
        pass "  --require preload: $PRELOAD_FLAG"
        for pf in $PRELOAD_FLAG; do
            if [ -f "$pf" ]; then
                pass "    Preload file exists: $pf"
            else
                warn "    Preload file NOT FOUND: $pf"
            fi
        done
    fi

    LOADER_FLAG=$(echo "$NODE_OPTS" | grep -oP '(?<=--loader\s|--loader=)[^\s]+' 2>/dev/null)
    if [ -n "$LOADER_FLAG" ]; then
        pass "  --loader: $LOADER_FLAG"
    fi
else
    info "NODE_OPTIONS: NOT SET"
fi

echo "--- 5.5 NODE_PATH Module Directories ---"
NODE_PATH_VAL="${NODE_PATH:-}"
if [ -n "$NODE_PATH_VAL" ]; then
    pass "NODE_PATH is set"
    echo "$NODE_PATH_VAL" | tr ':' '\n' | while read npath; do
        if [ -d "$npath" ]; then
            MOD_COUNT=$(ls "$npath" 2>/dev/null | wc -l)
            pass "  $npath (exists, $MOD_COUNT entries)"
        else
            fail "  $npath (NOT FOUND)"
        fi
    done
else
    info "NODE_PATH: NOT SET"
fi

echo "--- 5.6 Node.js Runtime Details ---"
if which node &>/dev/null; then
    NODE_VER=$(timeout 3 node --version 2>/dev/null)
    pass "Node.js version: ${NODE_VER:-unknown}"

    NODE_PATHS=$(timeout 3 node -e "console.log(require.resolve.paths('xyz').join('\n'))" 2>/dev/null)
    if [ -n "$NODE_PATHS" ]; then
        info "Node.js module resolution paths:"
        echo "$NODE_PATHS" | while read npath; do
            [ -d "$npath" ] && info "  $npath (exists)" || info "  $npath (missing)"
        done
    fi

    NODE_ARCH=$(timeout 3 node -e "console.log(process.arch)" 2>/dev/null)
    NODE_PLATFORM=$(timeout 3 node -e "console.log(process.platform)" 2>/dev/null)
    NODE_PID=$(timeout 3 node -e "console.log(typeof process.pid)" 2>/dev/null)
    info "  arch=$NODE_ARCH platform=$NODE_PLATFORM"
fi

# ============================================================
# DOMAIN 6: AGENT-TOOL-HOST ANALYSIS
# ============================================================
section "6" "AGENT-TOOL-HOST ANALYSIS"

echo "--- 6.1 IDE Dynamic Config ---"
IDE_CONFIG="/app/etc/ide_dynamic_config_basic.json"
if [ -f "$IDE_CONFIG" ]; then
    pass "ide_dynamic_config_basic.json found: $IDE_CONFIG"
    IDE_SIZE=$(wc -c < "$IDE_CONFIG")
    info "  Size: ${IDE_SIZE} bytes"

    echo "--- 6.2 Feature Flags ---"
    if which jq &>/dev/null; then
        FEATURE_FLAGS=$(timeout 5 jq -r 'to_entries[] | select(.value | type == "boolean" or type == "string") | "\(.key)=\(.value)"' "$IDE_CONFIG" 2>/dev/null)
        if [ -n "$FEATURE_FLAGS" ]; then
            FLAG_COUNT=$(echo "$FEATURE_FLAGS" | wc -l)
            pass "Found $FLAG_COUNT feature flags/config entries"
            echo "$FEATURE_FLAGS" | while read flag; do
                [ -n "$flag" ] && info "  $flag"
            done
        else
            info "No boolean/string feature flags found (may be nested structure)"
            ALL_KEYS=$(timeout 5 jq -r 'paths | join(".")' "$IDE_CONFIG" 2>/dev/null | head -30)
            if [ -n "$ALL_KEYS" ]; then
                info "Config key paths (top 30):"
                echo "$ALL_KEYS" | while read kpath; do
                    VAL=$(timeout 5 jq -r ".$kpath" "$IDE_CONFIG" 2>/dev/null | head -c 80)
                    info "  $kpath = $VAL"
                done
            fi
        fi
    else
        warn "jq not available for feature flag parsing"
        grep -E '"[^"]+"\s*:\s*(true|false|"[^"]*")' "$IDE_CONFIG" 2>/dev/null | head -20 | while read fline; do
            info "  $fline"
        done
    fi
else
    fail "ide_dynamic_config_basic.json NOT FOUND at $IDE_CONFIG"
    for alt in /app/ide_dynamic_config_basic.json /app/etc/ide_config.json /app/config/ide_dynamic_config.json; do
        if [ -f "$alt" ]; then
            pass "  Found at: $alt"
        fi
    done
fi

echo "--- 6.3 Key Environment Variables ---"
KEY_ENV_VARS=(
    "PREVIEW_PROXY_PUBLIC_PORT"
    "PREVIEW_PROXY_INTERNAL_PORT"
    "AGENT_TOOL_HOST_PORT"
    "SANDBOX_ID"
    "SANDBOX_RUNTIME"
    "WORKSPACE_MOUNT_PATH"
    "WEB_HOST"
    "WEB_PORT"
    "API_HOST"
    "API_PORT"
    "MCP_PROXY_PORT"
    "IDE_SERVER_PORT"
    "RUNTIME_TYPE"
    "CONTAINER_ID"
)
FOUND_ENV=0
for envvar in "${KEY_ENV_VARS[@]}"; do
    VAL="${!envvar:-}"
    if [ -n "$VAL" ]; then
        pass "$envvar=$VAL"
        FOUND_ENV=$((FOUND_ENV + 1))
    else
        info "$envvar: NOT SET"
    fi
done
info "Key environment variables found: $FOUND_ENV / ${#KEY_ENV_VARS[@]}"

echo "--- 6.4 Agent Tool Host Process ---"
ATH_PROCS=$(timeout 5 ps aux 2>/dev/null | grep -iE "agent.tool.host|agent-tool-host|tool.host" | grep -v grep)
if [ -n "$ATH_PROCS" ]; then
    pass "agent-tool-host process detected"
    echo "$ATH_PROCS" | while read aproc; do
        PID=$(echo "$aproc" | awk '{print $2}')
        MEM=$(echo "$aproc" | awk '{print $6}')
        CMD=$(echo "$aproc" | awk '{for(i=11;i<=NF;i++) printf "%s ",$i; print ""}' | head -c 120)
        info "  PID=$PID MEM=${MEM}KB CMD=$CMD"
    done
else
    info "agent-tool-host process: NOT DETECTED via ps"
fi

echo "--- 6.5 /app/etc Directory Scan ---"
if [ -d "/app/etc" ]; then
    pass "/app/etc directory: EXISTS"
    ETC_FILES=$(ls -la /app/etc/ 2>/dev/null)
    echo "$ETC_FILES" | tail -n +2 | while read efile; do
        info "  $efile"
    done
else
    warn "/app/etc directory: NOT FOUND"
fi

echo "--- 6.6 /app Directory Top-Level Structure ---"
if [ -d "/app" ]; then
    APP_ENTRIES=$(ls -la /app/ 2>/dev/null | tail -n +2)
    APP_COUNT=$(echo "$APP_ENTRIES" | wc -l)
    info "/app directory: $APP_COUNT entries"
    echo "$APP_ENTRIES" | while read aentry; do
        info "  $aentry"
    done
else
    warn "/app directory: NOT FOUND"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   DEEP RECONNAISSANCE COMPLETE                       ║"
echo "╚═══════════════════════════════════════════════════════╝"

PASS_COUNT=$(grep -c "^PASS|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
WARN_COUNT=$(grep -c "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
INFO_COUNT=$(grep -c "^INFO|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)

echo ""
echo "Results Summary:"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"
echo "  ⚠️  WARN: $WARN_COUNT"
echo "  ℹ️  INFO: $INFO_COUNT"
echo ""
echo "Full results saved to: $RECON_DIR/results.txt"
echo "Port mapping saved to: $RECON_DIR/port_map.txt"
echo ""
echo "Domain Coverage:"
echo "  1. Supervisor Config & Process Management"
echo "  2. MCP Process Identification & Config"
echo "  3. Port-Service Mapping"
echo "  4. Kubernetes Environment"
echo "  5. Node.js Runtime & Preload Config"
echo "  6. Agent-Tool-Host Analysis"
