#!/bin/bash
set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BACKUP_DIR="/data/user/sandbox-backup"
mkdir -p "$BACKUP_DIR"

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# List of paths to backup/restore
PATHS=(
    # Shell configs
    "/root/.bashrc"
    "/root/.zshrc"
    "/root/.profile"
    
    # Package manager configs
    "/root/.npmrc"
    "/root/.pip"
    "/root/.cargo/config.toml"
    "/etc/apt/sources.list.d/ubuntu-mirror.list"
    "/etc/apt/sources.list.d"
    "/root/.config/sandbox-env"
    
    # Our custom scripts
    "/usr/local/bin/sandbox-env-setup.sh"
    "/usr/local/bin/sandbox-restore.sh"
    "/etc/profile.d/sandbox-env.sh"
    
    # Git config
    "/root/.gitconfig"
    
    # Workspace-specific files
    "/workspace/.git/config"
)

backup() {
    log_info "Starting backup to $BACKUP_DIR ..."
    TIMESTAMP=$(date -u '+%Y%m%d-%H%M%S')
    BACKUP_DEST="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_DEST"
    
    for path in "${PATHS[@]}"; do
        if [ -e "$path" ]; then
            log_info "Backing up $path ..."
            dest="$BACKUP_DEST/$(echo "$path" | sed 's|^/||')"
            dest_dir=$(dirname "$dest")
            mkdir -p "$dest_dir"
            if [ -d "$path" ]; then
                cp -a "$path" "$dest_dir/"
            else
                cp -a "$path" "$dest"
            fi
            log_ok "Backed up $path"
        else
            log_warn "Skipping $path (does not exist)"
        fi
    done
    
    # Create symlink to latest backup
    ln -sf "backup-$TIMESTAMP" "$BACKUP_DIR/latest"
    log_ok "Backup complete! Latest at $BACKUP_DIR/latest"
}

restore() {
    if [ ! -L "$BACKUP_DIR/latest" ]; then
        log_error "No backup found at $BACKUP_DIR/latest"
        exit 1
    fi
    log_info "Restoring from $BACKUP_DIR/latest ..."
    BACKUP_SRC=$(readlink -f "$BACKUP_DIR/latest")
    
    for path in "${PATHS[@]}"; do
        src="$BACKUP_SRC/$(echo "$path" | sed 's|^/||')"
        if [ -e "$src" ]; then
            log_info "Restoring $path ..."
            dest_dir=$(dirname "$path")
            mkdir -p "$dest_dir"
            if [ -d "$src" ]; then
                cp -a "$src" "$dest_dir/"
            else
                cp -a "$src" "$path"
            fi
            log_ok "Restored $path"
        else
            log_warn "Skipping $path (not in backup)"
        fi
    done
    log_ok "Restore complete!"
}

list() {
    log_info "Backups in $BACKUP_DIR:"
    for backup in "$BACKUP_DIR"/backup-*; do
        if [ -d "$backup" ]; then
            echo "  - $(basename "$backup")"
        fi
    done
    if [ -L "$BACKUP_DIR/latest" ]; then
        echo "  Latest: $(readlink "$BACKUP_DIR/latest")"
    fi
}

case "${1:-}" in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    list)
        list
        ;;
    *)
        echo "Usage: $0 {backup|restore|list}"
        exit 1
        ;;
esac

