#!/usr/bin/env bash

set -Eeuo pipefail

SOURCE="/mnt/Data/University/UOW"
DEST="michael@michael-server-fedora:/data/University/UOW"
SSH_KEY="$HOME/.ssh/id_ed25519_desktop"

echo "Starting UOW sync..."

if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: Source directory does not exist:"
    echo "  $SOURCE"
    exit 1
fi

if [[ -z "$(find "$SOURCE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "ERROR: Source directory is empty:"
    echo "  $SOURCE"
    echo "Aborting to prevent accidental deletion of remote data."
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: SSH key does not exist:"
    echo "  $SSH_KEY"
    exit 1
fi

rsync -avh \
    --delete \
    --progress \
    -e "ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=15" \
    "$SOURCE/" \
    "$DEST/"

echo "UOW sync complete."
