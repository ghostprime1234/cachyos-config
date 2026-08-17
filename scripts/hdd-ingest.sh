#!/usr/bin/env bash
# Import university files from MDS_VAULT into the desktop working copy.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

HDD_MOUNT="/mnt/MDS_VAULT"
HDD_SOURCE="$HDD_MOUNT/University_Vault/Live_Work/"
LOCAL_TARGET="/mnt/Data/University/"
BACKUP_SCRIPT="$SCRIPT_DIR/mds_backup.sh"

# ------------------------------------------------------------
# Validate HDD
# ------------------------------------------------------------

if ! mountpoint -q "$HDD_MOUNT"; then
    echo "ERROR: MDS_VAULT is not mounted at $HDD_MOUNT"
    exit 1
fi

if [[ ! -d "$HDD_SOURCE" ]]; then
    echo "ERROR: University vault not found at $HDD_SOURCE"
    exit 1
fi

if [[ ! -d "$LOCAL_TARGET" ]]; then
    echo "ERROR: Local University directory not found at $LOCAL_TARGET"
    exit 1
fi

# ------------------------------------------------------------
# Ingest
# ------------------------------------------------------------

echo "Importing MDS_VAULT into desktop working copy..."

rsync -avu \
    --delete \
    --exclude="snapshots/" \
    "$HDD_SOURCE" \
    "$LOCAL_TARGET"

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

if [[ -x "$BACKUP_SCRIPT" ]]; then
    echo "Running MDS backup workflow..."
    "$BACKUP_SCRIPT"
else
    echo "Warning: mds_backup.sh not found or not executable."
fi

# ------------------------------------------------------------
# Notification
# ------------------------------------------------------------

if command -v notify-send >/dev/null 2>&1; then
    notify-send \
        "MDS Vault" \
        "Ingest complete." \
        --icon=drive-harddisk
fi

echo "MDS Vault ingest complete."
