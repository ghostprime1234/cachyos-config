#!/usr/bin/env bash

# MDS Backup and Synchronisation
# Daily incremental snapshots / weekly compressed archive
# Workstation ↔ Mini PC synchronisation
# Workstation → USB vault replication

set -Eeuo pipefail

# ==============================================================================
# 0. ENVIRONMENT CONFIGURATION
# ==============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/mds_backup.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "⚠ CRITICAL ERROR: Configuration file '$ENV_FILE' not found."
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Ensure all required configuration variables exist.
REQUIRED_VARIABLES=(
    SOURCE
    SNAPSHOT_ROOT
    ARCHIVE_ROOT
    LOCAL_VAULT
    EXCLUDES
    ARCHIVE_EXCLUDES
    STATUS_FILE
    REMOTE_USER
    REMOTE_HOST
    REMOTE_PATH
    SSH_KEY
    REMOTE_SYNC_SCRIPT
    DAILY_RETENTION_DAYS
    FULL_RETENTION_DAYS
)

for variable in "${REQUIRED_VARIABLES[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "⚠ CRITICAL ERROR: Required variable '$variable' is not configured."
        exit 1
    fi
done

SOURCE="${SOURCE%/}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT%/}"
ARCHIVE_ROOT="${ARCHIVE_ROOT%/}"
LOCAL_VAULT="${LOCAL_VAULT%/}"
REMOTE_PATH="${REMOTE_PATH%/}"

DOW="$(date +%u)"
TIMESTAMP="$(date +%Y%m%d)"

REMOTE_SNAPSHOTS="${REMOTE_PATH}/snapshots"

# ==============================================================================
# 1. NETWORK AND PATH CONFIGURATION
# ==============================================================================

SSH_ARGS=(
    -i "$SSH_KEY"
    -o BatchMode=yes
    -o ConnectTimeout=15
)

SSH_DESTINATION="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_TARGET="${SSH_DESTINATION}:${REMOTE_PATH}"
SSH_TRANSPORT="ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"

USB_LIVE_WORK="${LOCAL_VAULT}/Live_Work"
USB_ARCHIVES="${LOCAL_VAULT}/archives"
USB_SNAPSHOTS="${LOCAL_VAULT}/snapshots"
REMOTE_SNAPSHOTS="${REMOTE_PATH}/snapshots"

# ==============================================================================
# 2. GUARDIAN LAYER
# ==============================================================================

echo "--- Running safety checks ---"

if [[ ! -d "$SOURCE" ]]; then
    echo "⚠ CRITICAL ERROR: Source directory does not exist:"
    echo "  $SOURCE"
    exit 1
fi

if [[ -z "$(find "$SOURCE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "⚠ CRITICAL ERROR: Source directory is empty:"
    echo "  $SOURCE"
    echo "Aborting to prevent accidental deletion of backup data."
    exit 1
fi

if [[ ! -f "$EXCLUDES" ]]; then
    echo "⚠ CRITICAL ERROR: Rsync exclusions file does not exist:"
    echo "  $EXCLUDES"
    exit 1
fi

if [[ ! -f "$ARCHIVE_EXCLUDES" ]]; then
    echo "⚠ CRITICAL ERROR: Archive exclusions file does not exist:"
    echo "  $ARCHIVE_EXCLUDES"
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    echo "⚠ CRITICAL ERROR: SSH private key does not exist:"
    echo "  $SSH_KEY"
    exit 1
fi

# This catches the accidental nesting that caused:
# /mnt/Data/University/University/University
if [[ -d "${SOURCE}/University" ]]; then
    echo "⚠ CRITICAL ERROR: An unexpected nested University directory exists:"
    echo "  ${SOURCE}/University"
    echo
    echo "This usually indicates that rsync previously copied the University"
    echo "directory itself into /mnt/Data/University."
    echo
    echo "Move or reconcile this directory before running the backup:"
    echo "  ${SOURCE}/University"
    exit 1
fi

REMOTE_AVAILABLE=false

if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
    "test -d '$REMOTE_PATH'" 2>/dev/null; then

    REMOTE_AVAILABLE=true
    echo "✓ Mini PC is available."
else
    echo "⚠ WARNING: Mini PC is unavailable."
    echo "Remote synchronisation will be skipped."
    echo "Local and USB backups will continue."
fi

if [[ "$REMOTE_AVAILABLE" == true ]]; then
    if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
        "test -d '${REMOTE_PATH}/University'"; then

        echo "⚠ CRITICAL ERROR: An unexpected nested University directory exists remotely:"
        echo "  ${SSH_DESTINATION}:${REMOTE_PATH}/University"
        echo
        echo "Move or reconcile the remote nested directory before synchronising."
        exit 1
    fi
fi

if [[ ! "$DAILY_RETENTION_DAYS" =~ ^[0-9]+$ ]] ||
   [[ ! "$FULL_RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    echo "⚠ CRITICAL ERROR: Retention values must be non-negative integers."
    exit 1
fi

mkdir -p "$SNAPSHOT_ROOT"
mkdir -p "$ARCHIVE_ROOT"

if [[ "$ARCHIVE_ROOT" == "$SNAPSHOT_ROOT" ]]; then
    echo "⚠ CRITICAL ERROR: ARCHIVE_ROOT and SNAPSHOT_ROOT must be different."
    exit 1
fi

# ==============================================================================
# 3. BIDIRECTIONAL MINI PC SYNC
# ==============================================================================

# Important trailing-slash behaviour:
#
#   "$SOURCE/"         = contents of /mnt/Data/University
#   "$REMOTE_TARGET/"  = contents of /home/michael/University
#
# Without those trailing slashes, rsync copies the University directory itself,
# which creates University/University nesting.

echo
if [[ "$REMOTE_AVAILABLE" == true ]]; then

    echo "--- Step 1a: Pulling newer data from Mini PC ---"

    if ! rsync -avu \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        --exclude="/snapshots/" \
        --exclude="/archives/" \
        --exclude="/legacy_full_snapshots/" \
        --exclude="/snapshot/" \
        "$REMOTE_TARGET/" \
        "$SOURCE/"; then

        echo "⚠ CRITICAL ERROR: Mini PC pull failed."
        echo "The remaining sync stages will not run."
        exit 1
    fi

    echo
    echo "--- Step 1b: Pushing local data to Mini PC ---"

    if ! rsync -av \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        --exclude="/snapshots/" \
        --exclude="/archives/" \
        --exclude="/legacy_full_snapshots/" \
        --exclude="/snapshot/" \
        "$SOURCE/" \
        "$REMOTE_TARGET/"; then

        echo "⚠ CRITICAL ERROR: Mini PC push failed."
        echo "Remote cleanup has been skipped to protect existing data."
        exit 1
    fi

    echo
    echo "--- Step 1c: Removing discarded files from Mini PC ---"

    if ! rsync -av \
        --delete \
        --existing \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        --exclude="/snapshots/" \
        --exclude="/archives/" \
        --exclude="/legacy_full_snapshots/" \
        --exclude="/snapshot/" \
        "$SOURCE/" \
        "$REMOTE_TARGET/"; then

        echo "⚠ CRITICAL ERROR: Mini PC cleanup failed."
        exit 1
    fi
fi

# ==============================================================================
# 4. USB VAULT SYNC
# ==============================================================================

if [[ -d "$LOCAL_VAULT" && -w "$LOCAL_VAULT" ]]; then
    mkdir -p "$USB_LIVE_WORK"

    echo
    echo "--- Step 2a: Pushing data to USB vault ---"

    if rsync -av \
        --exclude-from="$EXCLUDES" \
        --exclude="/snapshots/" \
        --exclude="/archives/" \
        --exclude="/legacy_full_snapshots/" \
        --exclude="/snapshot/" \
        "$SOURCE/" \
        "$USB_LIVE_WORK/"; then

        echo
        echo "--- Step 2b: Removing discarded files from USB vault ---"

        if ! rsync -av \
            --delete \
            --existing \
            --exclude-from="$EXCLUDES" \
            --exclude="/snapshots/" \
            --exclude="/archives/" \
            --exclude="/legacy_full_snapshots/" \
            --exclude="/snapshot/" \
            "$SOURCE/" \
            "$USB_LIVE_WORK/"; then

            echo "⚠ WARNING: USB vault cleanup failed."
        fi
    else
        echo "⚠ WARNING: USB vault push failed."
        echo "USB cleanup has been skipped to protect existing data."
    fi
else
    echo
    echo "⏸ INFO: USB vault is unavailable or read-only:"
    echo "  $LOCAL_VAULT"
    echo "Skipping USB live-work replication."
fi

# ==============================================================================
# 5. HYBRID ARCHIVE LOGIC
# ==============================================================================

# Find a completed full archive created within the previous six days.
RECENT_FULL="$(
    find "$ARCHIVE_ROOT" \
        -maxdepth 1 \
        -type f \
        -name "MDS_Full_Snapshot_*.tar.gz" \
        -mtime -6 \
        -print \
        -quit 2>/dev/null || true
)"

TODAY_FULL="${ARCHIVE_ROOT}/MDS_Full_Snapshot_${TIMESTAMP}.tar.gz"

if [[ ! -f "$TODAY_FULL" ]] && [[ "$DOW" -eq 7 || -z "$RECENT_FULL" ]]; then
    echo
    echo "--- Step 3: Creating selective weekly full archive ---"

    BACKUP_NAME="MDS_Full_Snapshot_${TIMESTAMP}.tar.gz"
    BACKUP_PATH="${ARCHIVE_ROOT}/${BACKUP_NAME}"
    TEMP_BACKUP="${BACKUP_PATH}.partial"

    rm -f -- "$TEMP_BACKUP"

    echo "Source:"
    echo "  $SOURCE"
    echo "Archive:"
    echo "  $BACKUP_PATH"
    echo "Exclusions:"
    echo "  $ARCHIVE_EXCLUDES"

    if tar \
        --create \
        --file="$TEMP_BACKUP" \
        --use-compress-program="pigz" \
        --exclude-from="$ARCHIVE_EXCLUDES" \
        --directory="$SOURCE" \
        .; then

        mv -- "$TEMP_BACKUP" "$BACKUP_PATH"

        echo "✓ Weekly full archive created:"
        echo "  $BACKUP_PATH"
    else
        rm -f -- "$TEMP_BACKUP"

        echo "⚠ CRITICAL ERROR: Weekly archive creation failed."
        echo "No incomplete archive has been retained."
        exit 1
    fi

    # Delete expired completed archives.
    find "$ARCHIVE_ROOT" \
        -maxdepth 1 \
        -type f \
        -name "MDS_Full_Snapshot_*.tar.gz" \
        -mtime +"$FULL_RETENTION_DAYS" \
        -delete

    # Clean up stale incomplete archives.
    find "$ARCHIVE_ROOT" \
        -maxdepth 1 \
        -type f \
        -name "*.partial" \
        -mtime +1 \
        -delete

else
    echo
    echo "--- Step 3: Creating incremental hard-link snapshot ---"

    DEST="${SNAPSHOT_ROOT}/MDS_Daily_${TIMESTAMP}"
    LATEST="${SNAPSHOT_ROOT}/latest"

    mkdir -p "$DEST"

    RSYNC_SNAPSHOT_ARGS=(
        -av
        --delete
        --exclude=/snapshots/
        --exclude=/archives/
        --exclude=/legacy_full_snapshots/
        --exclude=/snapshot/
        --exclude-from="$EXCLUDES"
    )

    if [[ -e "$LATEST" ]]; then
        RSYNC_SNAPSHOT_ARGS+=(--link-dest="$LATEST")
    else
        echo "ℹ No previous daily snapshot found."
        echo "The first daily snapshot will contain full file copies."
    fi

    if rsync \
        "${RSYNC_SNAPSHOT_ARGS[@]}" \
        "$SOURCE/" \
        "$DEST/"; then

        ln -sfn "$(basename "$DEST")" "$LATEST"

        echo "✓ Incremental snapshot created:"
        echo "  $DEST"
    else
        echo "⚠ CRITICAL ERROR: Incremental snapshot creation failed."
        exit 1
    fi
fi

# Delete expired daily snapshots whether this run was full or incremental.
find "$SNAPSHOT_ROOT" \
    -maxdepth 1 \
    -type d \
    -name "MDS_Daily_*" \
    -mtime +"$DAILY_RETENTION_DAYS" \
    -exec rm -rf -- {} +

# ==============================================================================
# 6. SNAPSHOT REPLICATION
# ==============================================================================

# ------------------------------------------------------------------------------
# 6a. Copy snapshots to USB
# ------------------------------------------------------------------------------

if [[ -d "$LOCAL_VAULT" && -w "$LOCAL_VAULT" ]]; then
    echo
    echo "--- Step 4a: Copying snapshots to USB vault ---"

    mkdir -p "$USB_SNAPSHOTS"

    if ! rsync -av \
        --delete \
        "$SNAPSHOT_ROOT/" \
        "$USB_SNAPSHOTS/"; then

        echo "⚠ WARNING: Snapshot replication to USB failed."
    fi
else
    echo
    echo "⏸ INFO: USB vault unavailable; snapshot USB replication skipped."
fi

# ------------------------------------------------------------------------------
# 6b. Copy completed weekly archives to USB
# ------------------------------------------------------------------------------

if [[ -d "$LOCAL_VAULT" && -w "$LOCAL_VAULT" ]]; then
    echo
    echo "--- Step 4b: Copying weekly archives to USB vault ---"

    mkdir -p "$USB_ARCHIVES"

    if ! rsync -av \
        --include="MDS_Full_Snapshot_*.tar.gz" \
        --exclude="*" \
        "$ARCHIVE_ROOT/" \
        "$USB_ARCHIVES/"; then

        echo "⚠ WARNING: Archive replication to USB failed."
    fi
else
    echo
    echo "⏸ INFO: USB vault unavailable or read-only."
    echo "Weekly archives remain available locally:"
    echo "  $ARCHIVE_ROOT"
fi

# ------------------------------------------------------------------------------
# 6c. Copy incremental snapshots to Mini PC
# ------------------------------------------------------------------------------

echo
if [[ "$REMOTE_AVAILABLE" == true ]]; then
    echo "--- Step 4c: Copying incremental snapshots to Mini PC ---"

    if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
        "mkdir -p '$REMOTE_SNAPSHOTS'"; then

        if ! rsync -av \
            --delete \
            -e "$SSH_TRANSPORT" \
            "$SNAPSHOT_ROOT/" \
            "${SSH_DESTINATION}:${REMOTE_SNAPSHOTS}/"; then

            echo "⚠ WARNING: Snapshot replication to Mini PC failed."
        fi
    else
        echo "⚠ WARNING: Could not create or access remote snapshot directory:"
        echo "  ${SSH_DESTINATION}:${REMOTE_SNAPSHOTS}"
    fi
else
    echo "⏸ Mini PC unavailable; remote snapshot replication skipped."
fi

# ==============================================================================
# 7. REMOTE LAB SYNC
# ==============================================================================

echo
if [[ "$REMOTE_AVAILABLE" == true ]]; then
    echo "--- Step 5: Triggering global lab sync on Mini PC ---"

    printf -v REMOTE_SCRIPT_QUOTED '%q' "$REMOTE_SYNC_SCRIPT"

    if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
        "nohup $REMOTE_SCRIPT_QUOTED >/dev/null 2>&1 </dev/null &"; then

        echo "✓ Remote lab sync started."
    else
        echo "⚠ WARNING: Failed to start remote lab sync."
    fi
else
    echo "⏸ Mini PC unavailable; global lab sync skipped."
fi


# ==============================================================================
# 8. STATUS
# ==============================================================================

mkdir -p "$(dirname "$STATUS_FILE")"

{
    echo "Last Global Sync: $(date --iso-8601=seconds)"
    echo "Source: $SOURCE"
    echo "Remote: ${SSH_DESTINATION}:${REMOTE_PATH}"
    echo "Snapshot Root: $SNAPSHOT_ROOT"
    echo "Archive Root: $ARCHIVE_ROOT"
} > "$STATUS_FILE"

echo "============================================================"
echo "✓ MDS backup and synchronisation completed successfully"
echo "  Source:    $SOURCE"
echo "  Remote:    ${SSH_DESTINATION}:${REMOTE_PATH}"
echo "  Snapshots: $SNAPSHOT_ROOT"
echo "  Archives:  $ARCHIVE_ROOT"
echo "============================================================"
