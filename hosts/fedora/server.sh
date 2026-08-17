#!/usr/bin/env bash
# Fedora Server configuration for the home mini PC

set -euo pipefail

echo "Configuring Fedora Server..."

echo "Installing Podman container tooling..."

sudo dnf install -y \
    podman \
    podman-compose \
    podman-docker

# Allow user services and containers to continue running
# after the user logs out.
sudo loginctl enable-linger "$USER"

echo
echo "Fedora Server configuration complete."
echo "Docker-compatible commands are provided by podman-docker."
