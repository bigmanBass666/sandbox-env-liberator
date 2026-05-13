#!/bin/bash
# MCP Server Manager: Automate MCP server registration to /data/user/mcp/mcp-servers.json

set -euo pipefail

MCP_CONFIG="/data/user/mcp/mcp-servers.json"
BACKUP_DIR="/data/user/mcp/backups"
BACKUP_FILE="${BACKUP_DIR}/mcp-servers-$(date +%s).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed!"
        exit 1
    fi
}

# Backup current config
backup_config() {
    if [ -f "${MCP_CONFIG}" ]; then
        mkdir -p "${BACKUP_DIR}"
        cp "${MCP_CONFIG}" "${BACKUP_FILE}"
        log "Config backed up to ${BACKUP_FILE}"
    fi
}

# List all registered MCP servers
list_servers() {
    log "Registered MCP servers:"
    jq -r '.mcpServers | keys | .[]' "${MCP_CONFIG}" | while read -r server; do
        echo "  - ${server}"
    done
}

# Add a new MCP server
add_server() {
    local name="$1"
    local command="$2"
    shift 2
    local args=("$@")

    # Build args array as JSON
    local args_json
    args_json=$(printf '%s\n' "${args[@]}" | jq -R . | jq -s '.')

    # Check if server already exists
    if jq -e ".mcpServers | has(\"${name}\")" "${MCP_CONFIG}" > /dev/null; then
        warn "Server '${name}' already exists!"
        return 0
    fi

    # Add server to config
    jq ".mcpServers.\"${name}\" = { command: \"${command}\", args: ${args_json} }" "${MCP_CONFIG}" > "${MCP_CONFIG}.tmp"
    mv "${MCP_CONFIG}.tmp" "${MCP_CONFIG}"
    log "Server '${name}' added successfully!"
}

# Remove an MCP server
remove_server() {
    local name="$1"

    if ! jq -e ".mcpServers | has(\"${name}\")" "${MCP_CONFIG}" > /dev/null; then
        warn "Server '${name}' not found!"
        return 0
    fi

    jq "del(.mcpServers.\"${name}\")" "${MCP_CONFIG}" > "${MCP_CONFIG}.tmp"
    mv "${MCP_CONFIG}.tmp" "${MCP_CONFIG}"
    log "Server '${name}' removed successfully!"
}

# Show server details
show_server() {
    local name="$1"
    jq ".mcpServers.\"${name}\"" "${MCP_CONFIG}"
}

# Usage
usage() {
    cat << EOF
MCP Server Manager - Automate MCP server registration

Usage: $0 <command> [options]

Commands:
  list                List all registered MCP servers
  add <name> <command> [args...]  Add a new MCP server
  remove <name>       Remove a registered MCP server
  show <name>         Show details of a specific MCP server
  backup              Backup current config
  help                Show this help message

Examples:
  $0 add my-server python3 -m my_mcp_server
  $0 list
  $0 show my-server
  $0 remove my-server
EOF
}

# Main
main() {
    check_dependencies

    case "${1:-help}" in
        list)
            list_servers
            ;;
        add)
            if [ "$#" -lt 3 ]; then
                error "Not enough arguments for 'add'!"
                usage
                exit 1
            fi
            backup_config
            add_server "$2" "$3" "${@:4}"
            ;;
        remove)
            if [ "$#" -ne 2 ]; then
                error "Please specify a server name to remove!"
                usage
                exit 1
            fi
            backup_config
            remove_server "$2"
            ;;
        show)
            if [ "$#" -ne 2 ]; then
                error "Please specify a server name to show!"
                usage
                exit 1
            fi
            show_server "$2"
            ;;
        backup)
            backup_config
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
