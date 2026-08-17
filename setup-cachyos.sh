#!/bin/bash
# setup-cachyos.sh - Michael's CachyOS Migration & Uni Sync

CHASSIS=$(hostnamectl chassis)
echo "🚀 Starting CachyOS Setup on a $CHASSIS..."

# 1. System Update & Base Essentials
# Includes Tailscale for networking and base tools
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm nfs-utils rclone psmisc curl git wget bc flatpak direnv tailscale

# --- Tailscale Activation ---
echo "🌐 Setting up Tailscale..."
sudo systemctl enable --now tailscaled

# Authenticate if not already connected
if ! tailscale status >/dev/null 2>&1; then
    echo "🔑 Tailscale login required for NAS/Proxmox access. Please follow the link:"
    sudo tailscale up --operator=$USER
else
    echo "✅ Tailscale is already online."
fi

# 2. Hardware-Specific Scripts
HOST_SCRIPT="./hosts/cachyos/${CHASSIS}.sh"

if [[ -f "$HOST_SCRIPT" ]]; then
  chmod +x "$HOST_SCRIPT"
  "$HOST_SCRIPT"
else
  echo "No CachyOS host script found for chassis: $CHASSIS"
fi

# 3. Native Apps (CachyOS Repos & AUR)
# Brave and Betterbird are pulled from CachyOS repos via paru for CPU optimization
echo "💻 Installing Browsers, Communication, and Dev Tools..."
paru -S --needed --noconfirm \
    betterbird-bin \
    brave-bin \
    discord \
    obsidian \
    visual-studio-code-bin \
    zoom \

# 4. Flatpaks (Optional fallback)
echo "💬 Configuring Flatpaks..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Apply Discord Update-Fix (Native version)
mkdir -p "$HOME/.config/discord"
echo '{"SKIP_HOST_UPDATE": true}' > "$HOME/.config/discord/settings.json"

# 5. University Terminal Logic
ALIASES=(
    "alias uni-pull='rsync -avzu --no-perms --no-owner --no-group --exclude=\".conda/\" /mnt/proxmox_uni/ ~/Documents/University/'"
    "alias uni-push='rsync -avzu --no-perms --no-owner --no-group --exclude=\".conda/\" ~/Documents/University/ /mnt/Synology_Home/Documents/University/University/'"
    "alias uni-status='mutagen sync list && echo \"--- Hub Connectivity ---\" && ping -c 1 100.70.100.118 | grep \"time=\"'"
)

for line in "${ALIASES[@]}"; do
    grep -qF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
done

# 6. Mutagen Sync (Tailscale Dependent)
sudo pacman -S --needed --noconfirm mutagen
SESSION_NAME="uni-sync-$(hostname)"
HUB_IP="100.99.160.1"

# Ensure daemon is up before creating session
mutagen daemon start 2>/dev/null
mutagen sync terminate "$SESSION_NAME" 2>/dev/null

# Attempt to create sync session
if ping -c 1 "$HUB_IP" &> /dev/null; then
    mutagen sync create --name="$SESSION_NAME" \
        "$HOME/Documents/University" \
        "michael@$HUB_IP:~/University"
    echo "🔗 Mutagen sync session '$SESSION_NAME' created."
else
    echo "⚠️ Warning: Could not reach Hub ($HUB_IP). Mutagen session will need manual start."
fi

# 7. Dual-NAS fstab Setup
sudo mkdir -p /mnt/proxmox /mnt/proxmox_uni /mnt/nas /mnt/Synology_Homes /mnt/Synology_Home

PVE_UNI="100.70.100.118:/home/michael/University /mnt/proxmox_uni nfs rw,_netdev,x-systemd.automount,noauto,soft,timeo=14 0 0"
NAS_HOMES="100.99.160.1:/volume1/homes /mnt/Synology_Homes nfs nfsvers=3,nolock,tcp,rw,_netdev,x-systemd.automount,noauto,soft,timeo=14 0 0"
NAS_BIND="/mnt/Synology_Homes/Michael /mnt/Synology_Home none bind,x-systemd.automount,noauto,x-systemd.requires=/mnt/Synology_Homes 0 0"

# Update fstab only if entry doesn't exist
for entry in "$PVE_UNI" "$NAS_HOMES" "$NAS_BIND"; do
    grep -qF "$entry" /etc/fstab || echo "$entry" | sudo tee -a /etc/fstab
done

sudo systemctl daemon-reload

# 8. Multi-Format Icon Mapping
APPS_DIR="$HOME/.local/share/applications"
ICON_PATH="$HOME/.local/share/icons/custom"

# This logic finds the icon file regardless of extension (.png, .svg, .webp)
find_icon() {
    # Searches for a file starting with the prefix in your Icons folder
    find "$ICON_PATH" -name "$1.*" -print -quit
}

echo "🎨 Mapping icons (SVG/PNG/WebP supported)..."

# Example for Google Gemini
GEMINI_FILE=$(grep -l "Name=Google Gemini" "$APPS_DIR"/brave-*.desktop)
GEMINI_ICON=$(find_icon "google-gemini-icon")

if [ -n "$GEMINI_FILE" ] && [ -n "$GEMINI_ICON" ]; then
    sed -i "s|^Icon=.*|Icon=$GEMINI_ICON|" "$GEMINI_FILE"
    echo "✅ Applied Gemini icon: $(basename "$GEMINI_ICON")"
fi

# Run the Bluetooth audio setup script safely
if [ -f "./fix-bluetooth-audio.sh" ]; then
    echo "--> Launching Bluetooth audio fixes..."
    chmod +x ./fix-bluetooth-audio.sh
    ./fix-bluetooth-audio.sh
else
    echo "Warning: fix-bluetooth-audio.sh not found."
fi

echo "✅ CachyOS Setup Complete!"
