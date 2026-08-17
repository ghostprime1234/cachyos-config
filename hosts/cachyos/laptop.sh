#!/bin/bash
# hosts/laptop.sh - Michael's IdeaPad Efficiency & Mobility

echo "🔋 Tuning IdeaPad for Battery & Data Science Mobility..."

# 0. Install all apps
sudo pacman -S direnv

# 1. Power Management (Auto-Scaling)
# auto-cpufreq is better than powertop for modern Ryzen/Intel IdeaPads
paru -S --needed --noconfirm auto-cpufreq
sudo systemctl enable --now auto-cpufreq

# 2. Battery Conservation Mode (Threshold at 80%)
# This prevents your battery from sitting at 100% while plugged in at your desk
echo "🔋 Checking IdeaPad Battery Conservation Support..."
CONSERVATION_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

if [ -f "$CONSERVATION_PATH" ]; then
    echo "✅ Enabling IdeaPad Battery Conservation Mode..."
    echo 1 | sudo tee "$CONSERVATION_PATH"
else
    # Fallback for newer kernels/models
    ALT_PATH=$(find /sys/devices/platform -name "conservation_mode" 2>/dev/null | head -n 1)
    if [ -n "$ALT_PATH" ]; then
        echo "✅ Enabling Conservation Mode via: $ALT_PATH"
        echo 1 | sudo tee "$ALT_PATH"
    fi
fi

# 3. Touchpad & UI Tuning (KDE Plasma)
echo "🖱️  Configuring Touchpad and Power Profile..."
# Enable tap-to-click for KDE Plasma
mkdir -p "$HOME/.config"
if ! grep -q "TapToClick=true" "$HOME/.config/touchpadrc" 2>/dev/null; then
    echo "TapToClick=true" >> "$HOME/.config/touchpadrc"
fi

# Ensure the 'power-profiles-daemon' is in 'balanced' or 'power-saver'
if command -v powerprofilesctl &> /dev/null; then
    powerprofilesctl set balanced
fi

# 4. Local University Folders
mkdir -p "$HOME/Documents/University"
mkdir -p "$HOME/Synology_Home"

echo "✅ Laptop Hardware Configuration Complete!"
