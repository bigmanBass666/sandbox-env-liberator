#!/bin/bash
# Persist important files to /data/user for cross-session persistence
set -euo pipefail

PERSIST_DIR="/data/user/persisted"
BACKUP_DIR="/data/user/persisted/backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

mkdir -p "${PERSIST_DIR}"
mkdir -p "${BACKUP_DIR}"

# List of important files to persist
FILES_TO_PERSIST=(
    "/workspace/references/polaris-score.md"
    "/workspace/references/handoff.md"
    "/workspace/references/evolution-log.md"
)

log "Persisting important files to ${PERSIST_DIR}..."
for file in "${FILES_TO_PERSIST[@]}"; do
    if [ -f "${file}" ]; then
        filename=$(basename "${file}")
        cp "${file}" "${PERSIST_DIR}/${filename}"
        log "  - ${filename}"
    else
        warn "  - ${file} not found, skipping"
    fi
done

# Backup existing persisted files with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
tar -czf "${BACKUP_DIR}/persisted-${TIMESTAMP}.tar.gz" -C "${PERSIST_DIR}" .
log "Backup created: ${BACKUP_DIR}/persisted-${TIMESTAMP}.tar.gz"

log "Persistence complete!"
