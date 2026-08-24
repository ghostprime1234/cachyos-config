#!/usr/bin/env bash
# Fedora Server configuration for the home mini PC

set -euo pipefail

echo "Configuring Fedora Server..."

DESIRED_HOSTNAME="michael-server-fedora"

if [[ "$(hostnamectl --static)" != "$DESIRED_HOSTNAME" ]]; then
    echo "Setting hostname to $DESIRED_HOSTNAME..."
    sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"
else
    echo "Hostname already configured."
fi

echo "Installing Podman container tooling..."

sudo dnf install -y \
    podman \
    podman-compose \
    podman-docker

# Allow user services and containers to continue running
# after the user logs out.
sudo loginctl enable-linger "$USER"

echo "Configuring Podman socket..."

systemctl --user enable --now podman.socket

echo
echo "Fedora Server configuration complete."
echo "Docker-compatible commands are provided by podman-docker."
