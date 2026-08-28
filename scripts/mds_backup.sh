#!/usr/bin/env bash

# ==============================================================================
# MDS WORKSTATION SYNCHRONISATION
#
# Desktop ↔ Fedora server live-file synchronisation
# Desktop → USB vault live-work replication
# Fedora server handles snapshots, archives, NAS and OneDrive backups
# ==============================================================================

set -Eeuo pipefail

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE ==="
fi

RSYNC_DRY_ARGS=()
if [[ "$DRY_RUN" == true ]]; then
    RSYNC_DRY_ARGS+=(--dry-run)
fi

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

REQUIRED_VARIABLES=(
    SOURCE
    LOCAL_VAULT
    EXCLUDES
    STATUS_FILE
    REMOTE_USER
    REMOTE_HOST
    REMOTE_PATH
    SSH_KEY
)

for variable in "${REQUIRED_VARIABLES[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "⚠ CRITICAL ERROR: Required variable '$variable' is not configured."
        exit 1
    fi
done

SOURCE="${SOURCE%/}"
LOCAL_VAULT="${LOCAL_VAULT%/}"
REMOTE_PATH="${REMOTE_PATH%/}"

# ==============================================================================
# 1. NETWORK / PATH CONFIGURATION
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
    echo "Aborting to prevent accidental deletion of remote data."
    exit 1
fi

if [[ ! -f "$EXCLUDES" ]]; then
    echo "⚠ CRITICAL ERROR: Rsync exclusions file does not exist:"
    echo "  $EXCLUDES"
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    echo "⚠ CRITICAL ERROR: SSH private key does not exist:"
    echo "  $SSH_KEY"
    exit 1
fi

# Protect against accidental University/University nesting.
if [[ -d "${SOURCE}/University" ]]; then
    echo "⚠ CRITICAL ERROR: Unexpected nested University directory exists:"
    echo "  ${SOURCE}/University"
    exit 1
fi

REMOTE_AVAILABLE=false

if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
    "test -d '$REMOTE_PATH'" 2>/dev/null; then

    REMOTE_AVAILABLE=true
    echo "✓ Fedora server is available."
else
    echo "⚠ WARNING: Fedora server is unavailable."
    echo "Remote synchronisation will be skipped."
fi

if [[ "$REMOTE_AVAILABLE" == true ]]; then
    if ssh "${SSH_ARGS[@]}" "$SSH_DESTINATION" \
        "test -d '${REMOTE_PATH}/University'"; then

        echo "⚠ CRITICAL ERROR: Unexpected nested University directory exists remotely:"
        echo "  ${SSH_DESTINATION}:${REMOTE_PATH}/University"
        exit 1
    fi
fi

# ==============================================================================
# 3. DESKTOP ↔ FEDORA SERVER
# ==============================================================================

if [[ "$REMOTE_AVAILABLE" == true ]]; then

    echo
    echo "--- Step 1a: Pulling newer files from Fedora server ---"

    if ! rsync -avu \
        "${RSYNC_DRY_ARGS[@]}" \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        "$REMOTE_TARGET/" \
        "$SOURCE/"; then

        echo "⚠ CRITICAL ERROR: Server pull failed."
        exit 1
    fi

    echo
    echo "--- Step 1b: Pushing desktop files to Fedora server ---"

    if ! rsync -av \
        "${RSYNC_DRY_ARGS[@]}" \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        "$SOURCE/" \
        "$REMOTE_TARGET/"; then

        echo "⚠ CRITICAL ERROR: Server push failed."
        echo "Remote cleanup has been skipped."
        exit 1
    fi

    echo
    echo "--- Step 1c: Reconciling deleted files on Fedora server ---"

    if ! rsync -av \
        "${RSYNC_DRY_ARGS[@]}" \
        --delete \
        --existing \
        -e "$SSH_TRANSPORT" \
        --exclude-from="$EXCLUDES" \
        "$SOURCE/" \
        "$REMOTE_TARGET/"; then

        echo "⚠ CRITICAL ERROR: Remote cleanup failed."
        exit 1
    fi
fi

# ==============================================================================
# 4. USB VAULT LIVE-WORK COPY
# ==============================================================================

if [[ -d "$LOCAL_VAULT" && -w "$LOCAL_VAULT" ]]; then

    mkdir -p "$USB_LIVE_WORK"

    echo
    echo "--- Step 2a: Pushing live work to USB vault ---"

    if rsync -av \
        "${RSYNC_DRY_ARGS[@]}" \
        --exclude-from="$EXCLUDES" \
        "$SOURCE/" \
        "$USB_LIVE_WORK/"; then

        echo
        echo "--- Step 2b: Reconciling deleted files on USB vault ---"

        if ! rsync -av \
            "${RSYNC_DRY_ARGS[@]}" \
            --delete \
            --existing \
            --exclude-from="$EXCLUDES" \
            "$SOURCE/" \
            "$USB_LIVE_WORK/"; then

            echo "⚠ WARNING: USB vault cleanup failed."
        fi
    else
        echo "⚠ WARNING: USB vault push failed."
        echo "USB cleanup was skipped."
    fi

else
    echo
    echo "⏸ USB vault unavailable or read-only:"
    echo "  $LOCAL_VAULT"
fi

# ==============================================================================
# 5. STATUS
# ==============================================================================

mkdir -p "$(dirname "$STATUS_FILE")"

{
    echo "Last MDS Sync: $(date --iso-8601=seconds)"
    echo "Source: $SOURCE"
    echo "Remote: ${SSH_DESTINATION}:${REMOTE_PATH}"
} > "$STATUS_FILE"

echo
echo "============================================================"
echo "✓ MDS workstation synchronisation completed"
echo "  Source: $SOURCE"
echo "  Remote: ${SSH_DESTINATION}:${REMOTE_PATH}"
echo "============================================================"
