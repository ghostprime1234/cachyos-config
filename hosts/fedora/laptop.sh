#!/usr/bin/env bash
# hosts/laptop.sh - Fedora laptop setup for battery and data science mobility

set -euo pipefail

echo "Tuning Fedora laptop for battery and data science mobility..."

sudo dnf install -y \
  direnv \
  power-profiles-daemon

sudo systemctl enable --now power-profiles-daemon

echo "Checking IdeaPad battery conservation support..."

CONSERVATION_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

if [[ -f "$CONSERVATION_PATH" ]]; then
  echo "Enabling IdeaPad Battery Conservation Mode..."
  echo 1 | sudo tee "$CONSERVATION_PATH" >/dev/null
else
  ALT_PATH=$(find /sys/devices/platform -name "conservation_mode" 2>/dev/null | head -n 1 || true)

  if [[ -n "$ALT_PATH" ]]; then
    echo "Enabling Conservation Mode via: $ALT_PATH"
    echo 1 | sudo tee "$ALT_PATH" >/dev/null
  else
    echo "Battery conservation mode path not found. Skipping."
  fi
fi

echo "Configuring touchpad and power profile..."

mkdir -p "$HOME/.config"

if ! grep -q "TapToClick=true" "$HOME/.config/touchpadrc" 2>/dev/null; then
  echo "TapToClick=true" >> "$HOME/.config/touchpadrc"
fi

if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set balanced || true
fi

mkdir -p "$HOME/Documents/University"
mkdir -p "$HOME/Synology_Home"

echo "Laptop hardware configuration complete."
