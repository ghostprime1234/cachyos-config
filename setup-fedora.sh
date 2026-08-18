#!/usr/bin/env bash
# Fedora setup for desktop, laptop, and server systems.
#
# Usage:
#   ./setup-fedora.sh desktop
#   ./setup-fedora.sh laptop
#   ./setup-fedora.sh server

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Role selection
# ------------------------------------------------------------

ROLE="${1:-}"

# Auto-detect workstation type when no role is supplied.
if [[ -z "$ROLE" ]]; then
    CHASSIS="$(hostnamectl chassis 2>/dev/null || true)"

    case "$CHASSIS" in
        desktop)
            ROLE="desktop"
            ;;
        laptop)
            ROLE="laptop"
            ;;
        *)
            echo "Unable to determine system role automatically."
            echo "Usage: $0 {desktop|laptop|server}"
            exit 1
            ;;
    esac
fi

case "$ROLE" in
    desktop|laptop|server)
        ;;
    *)
        echo "Invalid role: $ROLE"
        echo "Usage: $0 {desktop|laptop|server}"
        exit 1
        ;;
esac

echo "Starting Fedora setup for role: $ROLE"

# ------------------------------------------------------------
# Fedora validation
# ------------------------------------------------------------

if [[ ! -f /etc/fedora-release ]]; then
    echo "Error: this setup script is intended for Fedora."
    exit 1
fi

# ------------------------------------------------------------
# System update
# ------------------------------------------------------------

echo "Updating Fedora..."
sudo dnf upgrade -y

# ------------------------------------------------------------
# Common packages
# ------------------------------------------------------------

echo "Installing common packages..."

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
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting

# ------------------------------------------------------------
# Tailscale
# ------------------------------------------------------------

echo "Configuring Tailscale..."

sudo systemctl enable --now tailscaled

if ! tailscale status >/dev/null 2>&1; then
    echo "Tailscale authentication required."
    sudo tailscale up --operator="$USER"
else
    echo "Tailscale is already online."
fi

# ------------------------------------------------------------
# Zsh configuration
# ------------------------------------------------------------

echo "Installing common Zsh configuration..."

for file in .zshrc .p10k.zsh; do
    source_file="$REPO_DIR/hosts/common/$file"
    target="$HOME/$file"

    # Replace an existing file or stale symlink.
    rm -f "$target"

    ln -s "$source_file" "$target"
done

# ------------------------------------------------------------
# Workstation configuration
# ------------------------------------------------------------

if [[ "$ROLE" == "desktop" || "$ROLE" == "laptop" ]]; then

    echo "Configuring Fedora Workstation repositories..."

    sudo dnf install -y \
        flatpak \
        dnf-plugins-core

    # Flathub
    flatpak remote-add --if-not-exists \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    # RPM Fusion
    echo "Configuring RPM Fusion repositories..."

    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 ||
       ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then

        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    else
        echo "RPM Fusion repositories already configured."
    fi

    # VS Code
    echo "Configuring Microsoft VS Code repository..."

    if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
        sudo rpm --import \
            https://packages.microsoft.com/keys/microsoft.asc

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
    else
        echo "VS Code repository already configured."
    fi

    # Brave
    echo "Configuring Brave repository..."

    if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
        sudo dnf config-manager addrepo \
            --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

        sudo rpm --import \
            https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    else
        echo "Brave repository already configured."
    fi

    # --------------------------------------------------------
    # Workstation packages
    # --------------------------------------------------------

    echo "Installing workstation applications..."

    sudo dnf install -y \
        brave-browser \
        code \
        java-21-openjdk \
        kdenlive \
        libreoffice \
        lutris \
        NetworkManager-openvpn \
        obs-studio \
        plasma-browser-integration \
        poppler-glib \
        python3 \
        python3-defusedxml \
        python3-packaging \
        steam \
        virt-manager \
        vlc \
        xdg-user-dirs

    # --------------------------------------------------------
    # Flatpak applications
    # --------------------------------------------------------

    echo "Installing Flatpak applications..."

    flatpak install -y flathub \
        md.obsidian.Obsidian \
        net.davidotek.pupgui2 \
        com.github.IsmaelMartinez.teams_for_linux \
        com.umlet.Umlet \
        org.projectlibre.ProjectLibre \
        com.jetbrains.Toolbox \
        com.discordapp.Discord \
        io.dbeaver.DBeaverCommunity \
        us.zoom.Zoom

    # --------------------------------------------------------
    # SSH configuration
    # --------------------------------------------------------

    SSH_CONFIG="$REPO_DIR/config/ssh/${ROLE}.conf"

    if [[ -f "$SSH_CONFIG" ]]; then
        echo "Installing SSH configuration..."

        mkdir -p "$HOME/.ssh"
        cp "$SSH_CONFIG" "$HOME/.ssh/config"

        chmod 700 "$HOME/.ssh"
        chmod 600 "$HOME/.ssh/config"
    fi

    # --------------------------------------------------------
    # Bluetooth configuration
    # --------------------------------------------------------

    BLUETOOTH_SCRIPT="$REPO_DIR/scripts/fix-bluetooth-audio.sh"

    if [[ -f "$BLUETOOTH_SCRIPT" ]]; then
        echo "Applying Bluetooth audio configuration..."
        chmod +x "$BLUETOOTH_SCRIPT"
        "$BLUETOOTH_SCRIPT"
    fi
fi

# ------------------------------------------------------------
# Role-specific configuration
# ------------------------------------------------------------

ROLE_SCRIPT="$REPO_DIR/hosts/fedora/${ROLE}.sh"

if [[ ! -f "$ROLE_SCRIPT" ]]; then
    echo "Error: role configuration not found:"
    echo "$ROLE_SCRIPT"
    exit 1
fi

echo "Running Fedora $ROLE configuration..."

chmod +x "$ROLE_SCRIPT"
"$ROLE_SCRIPT"

# ------------------------------------------------------------
# Complete
# ------------------------------------------------------------

echo
echo "Fedora $ROLE setup complete."
