#!/usr/bin/env bash
# hosts/laptop.sh - Fedora laptop setup for battery and data science mobility

set -euo pipefail

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

echo "Configuring touchpad..."

mkdir -p "$HOME/.config"

if ! grep -q "TapToClick=true" "$HOME/.config/touchpadrc" 2>/dev/null; then
  echo "TapToClick=true" >> "$HOME/.config/touchpadrc"
fi

echo "Configuring power profile..."

if command -v tuned-adm >/dev/null 2>&1 && sudo tuned-adm profile balanced; then
  echo "TuneD profile set to balanced."
elif command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set balanced
  echo "Power profile set to balanced."
else
  echo "No supported power profile manager found. Skipping."
fi

echo "Creating local university folder..."
mkdir -p "$HOME/Documents/University"

echo "Laptop hardware configuration complete."
