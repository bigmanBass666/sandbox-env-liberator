#!/bin/bash
# Custom Command Manager: Automate custom command registration to /data/user/commands/

set -euo pipefail

COMMANDS_DIR="/data/user/commands"
BACKUP_DIR="/data/user/commands/backups"

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

# Backup current commands
backup_commands() {
    mkdir -p "${BACKUP_DIR}"
    local backup_file="${BACKUP_DIR}/commands-$(date +%s).tar.gz"
    if ls "${COMMANDS_DIR}"/*.md 2>/dev/null; then
        tar -czf "${backup_file}" -C "${COMMANDS_DIR}" . --exclude="backups"
        log "Commands backed up to ${backup_file}"
    fi
}

# List all registered custom commands
list_commands() {
    log "Registered custom commands:"
    for cmd_file in "${COMMANDS_DIR}"/*.md; do
        if [ -f "${cmd_file}" ]; then
            local cmd_name=$(basename "${cmd_file}" .md)
            echo "  - /${cmd_name}"
        fi
    done
}

# Add a new custom command
add_command() {
    local name="$1"
    local description="$2"
    local content="$3"

    local cmd_file="${COMMANDS_DIR}/${name}.md"

    # Check if command already exists
    if [ -f "${cmd_file}" ]; then
        warn "Command '${name}' already exists!"
        return 0
    fi

    # Write command file
    cat > "${cmd_file}" << EOF
---
description: ${description}
name: ${name}
---

${content}
EOF
    log "Command '${name}' added successfully!"
}

# Remove a custom command
remove_command() {
    local name="$1"
    local cmd_file="${COMMANDS_DIR}/${name}.md"

    if [ ! -f "${cmd_file}" ]; then
        warn "Command '${name}' not found!"
        return 0
    fi

    rm "${cmd_file}"
    log "Command '${name}' removed successfully!"
}

# Show command details
show_command() {
    local name="$1"
    local cmd_file="${COMMANDS_DIR}/${name}.md"
    if [ -f "${cmd_file}" ]; then
        cat "${cmd_file}"
    else
        error "Command '${name}' not found!"
    fi
}

# Usage
usage() {
    cat << EOF
Custom Command Manager - Automate custom command registration

Usage: $0 <command> [options]

Commands:
  list                List all registered custom commands
  add <name> <description> <content>  Add a new custom command
  remove <name>       Remove a registered custom command
  show <name>         Show details of a specific custom command
  backup              Backup current commands
  help                Show this help message

Examples:
  $0 add my-command "My custom command" "This is what my command does..."
  $0 list
  $0 show my-command
  $0 remove my-command
EOF
}

# Main
main() {
    case "${1:-help}" in
        list)
            list_commands
            ;;
        add)
            if [ "$#" -lt 4 ]; then
                error "Not enough arguments for 'add'!"
                usage
                exit 1
            fi
            backup_commands
            add_command "$2" "$3" "$4"
            ;;
        remove)
            if [ "$#" -ne 2 ]; then
                error "Please specify a command name to remove!"
                usage
                exit 1
            fi
            backup_commands
            remove_command "$2"
            ;;
        show)
            if [ "$#" -ne 2 ]; then
                error "Please specify a command name to show!"
                usage
                exit 1
            fi
            show_command "$2"
            ;;
        backup)
            backup_commands
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
