#!/usr/bin/env bash
# setup-fedora.sh - Michael's Fedora Migration & Uni Sync

set -euo pipefail

CHASSIS=$(hostnamectl chassis 2>/dev/null || echo "unknown")
echo "Starting Fedora setup on a $CHASSIS..."

# 1. System update
sudo dnf upgrade -y

# 2. Enable core repos
echo "Enabling Flathub..."
sudo dnf install -y flatpak dnf-plugins-core
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "Enabling RPM Fusion..."
sudo dnf install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# 3. External repos: VS Code, Brave, Docker
echo "Adding Microsoft VS Code repo..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

echo "Adding Brave repo..."
sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

echo "Adding Docker repo..."
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

# 4. Base essentials
echo "Installing base tools..."
sudo dnf install -y \
  bc \
  btop \
  curl \
  direnv \
  dmidecode \
  fastfetch \
  git \
  htop \
  micro \
  nfs-utils \
  psmisc \
  rclone \
  ripgrep \
  rsync \
  tailscale \
  tree \
  vim \
  wget \
  xdg-user-dirs \
  zsh \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# 5. Dev, uni, and desktop apps
echo "Installing desktop/dev apps..."
sudo dnf install -y \
  brave-browser \
  code \
  dbeaver \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  java-21-openjdk \
  kdenlive \
  libreoffice \
  lutris \
  NetworkManager-openvpn \
  obs-studio \
  plasma-browser-integration \
  poppler-glib \
  power-profiles-daemon \
  python3 \
  python3-defusedxml \
  python3-packaging \
  steam \
  virt-manager \
  vlc

# 6. Flatpak apps
echo "Installing Flatpaks..."
flatpak install -y flathub \
  md.obsidian.Obsidian \
  net.davidotek.pupgui2 \
  com.github.IsmaelMartinez.teams_for_linux \
  com.umlet.Umlet \
  org.projectlibre.ProjectLibre \
  com.ticktick.TickTick \
  com.jetbrains.Toolbox \
  com.discordapp.Discord \
  us.zoom.Zoom

# 7. Tailscale
echo "Setting up Tailscale..."
sudo systemctl enable --now tailscaled

if ! tailscale status >/dev/null 2>&1; then
  echo "Tailscale login required for NAS/Proxmox access."
  sudo tailscale up --operator="$USER"
else
  echo "Tailscale is already online."
fi

# 8. Docker
echo "Setting up Docker..."
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# 9. Hardware-specific scripts
HOST_SCRIPT="./hosts/fedora/${CHASSIS}.sh"

if [[ -f "$HOST_SCRIPT" ]]; then
  chmod +x "$HOST_SCRIPT"
  "$HOST_SCRIPT"
else
  echo "No Fedora host script found for chassis: $CHASSIS"
fi

# 10. University aliases
ALIASES=(
  "alias uni-pull='rsync -avzu --no-perms --no-owner --no-group --exclude=\".conda/\" /mnt/proxmox_uni/ ~/Documents/University/'"
  "alias uni-push='rsync -avzu --no-perms --no-owner --no-group --exclude=\".conda/\" ~/Documents/University/ /mnt/Synology_Home/Documents/University/University/'"
  "alias uni-status='mutagen sync list && echo \"--- Hub Connectivity ---\" && ping -c 1 100.70.100.118 | grep \"time=\"'"
)

for shell_rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  touch "$shell_rc"
  for line in "${ALIASES[@]}"; do
    grep -qF "$line" "$shell_rc" || echo "$line" >> "$shell_rc"
  done
done

# 11. Mutagen sync
if command -v mutagen >/dev/null 2>&1; then
  SESSION_NAME="uni-sync-$(hostname)"
  HUB_IP="100.99.160.1"

  mutagen daemon start 2>/dev/null || true
  mutagen sync terminate "$SESSION_NAME" 2>/dev/null || true

  if ping -c 1 "$HUB_IP" >/dev/null 2>&1; then
    mutagen sync create --name="$SESSION_NAME" \
      "$HOME/Documents/University" \
      "michael@$HUB_IP:~/University"
    echo "Mutagen sync session '$SESSION_NAME' created."
  else
    echo "Warning: could not reach Hub ($HUB_IP). Mutagen session will need manual start."
  fi
else
  echo "Mutagen not installed. Skipping Mutagen sync setup."
fi

# 12. Dual-NAS fstab setup
sudo mkdir -p /mnt/proxmox /mnt/proxmox_uni /mnt/nas /mnt/Synology_Homes /mnt/Synology_Home

PVE_UNI="100.70.100.118:/home/michael/University /mnt/proxmox_uni nfs rw,_netdev,x-systemd.automount,noauto,soft,timeo=14 0 0"
NAS_HOMES="100.99.160.1:/volume1/homes /mnt/Synology_Homes nfs nfsvers=3,nolock,tcp,rw,_netdev,x-systemd.automount,noauto,soft,timeo=14 0 0"
NAS_BIND="/mnt/Synology_Homes/Michael /mnt/Synology_Home none bind,x-systemd.automount,noauto,x-systemd.requires=/mnt/Synology_Homes 0 0"

for entry in "$PVE_UNI" "$NAS_HOMES" "$NAS_BIND"; do
  grep -qF "$entry" /etc/fstab || echo "$entry" | sudo tee -a /etc/fstab >/dev/null
done

sudo systemctl daemon-reload

# 13. Discord native update-fix, harmless if using Flatpak too
mkdir -p "$HOME/.config/discord"
echo '{"SKIP_HOST_UPDATE": true}' > "$HOME/.config/discord/settings.json"

# 14. Optional Bluetooth audio script
if [[ -f "./fix-bluetooth-audio.sh" ]]; then
  echo "Launching Bluetooth audio fixes..."
  chmod +x ./fix-bluetooth-audio.sh
  ./fix-bluetooth-audio.sh
fi

echo "Fedora setup complete. Reboot or log out/in so Docker group membership applies."
