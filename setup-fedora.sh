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

if [[ -z "$ROLE" ]]; then
    # Read Fedora variant information.
    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${VARIANT_ID:-}" == "server" ]]; then
        ROLE="server"
    else
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

case "$ROLE" in
    desktop)
        DESIRED_HOSTNAME="michael-desktop-fedora"
        ;;
    laptop)
        DESIRED_HOSTNAME="michael-laptop-fedora"
        ;;
    server)
        DESIRED_HOSTNAME="michael-server-fedora"
        ;;
esac

# ------------------------------------------------------------
# Fedora validation
# ------------------------------------------------------------

if [[ ! -f /etc/fedora-release ]]; then
    echo "Error: this setup script is intended for Fedora."
    exit 1
fi

echo "Configuring hostname for Fedora $ROLE..."

# ------------------------------------------------------------
# Hostname
# ------------------------------------------------------------
#
if [[ "$(hostnamectl --static)" != "$DESIRED_HOSTNAME" ]]; then
    echo "Setting hostname to $DESIRED_HOSTNAME..."
    sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"
else
    echo "Hostname already configured."
fi


# ------------------------------------------------------------
# System update
# ------------------------------------------------------------

echo "Updating Fedora..."
sudo dnf upgrade -y

# ------------------------------------------------------------
# Tailscale repository
# ------------------------------------------------------------

echo "Configuring Tailscale repository..."

if [[ ! -f /etc/yum.repos.d/tailscale.repo ]]; then
    sudo dnf config-manager addrepo \
        --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
else
    echo "Tailscale repository already configured."
fi

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

ZSH_PATH="$(command -v zsh)"

if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo "Setting Zsh as default shell..."
    chsh -s "$ZSH_PATH"
fi

# ------------------------------------------------------------
# Powerlevel10k
# ------------------------------------------------------------

echo "Configuring Powerlevel10k..."

P10K_DIR="$HOME/.local/share/powerlevel10k"

if [[ ! -d "$P10K_DIR/.git" ]]; then
    echo "Installing Powerlevel10k..."

    git clone --depth=1 \
        https://github.com/romkatv/powerlevel10k.git \
        "$P10K_DIR"
else
    echo "Powerlevel10k already installed."
fi

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
        virt-install \
        libvirt \
        qemu-kvm \
        vlc \
        xdg-user-dirs

    echo "Configuring virtualization..."

    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt "$USER"

    # --------------------------------------------------------
    # Flatpak applications
    # --------------------------------------------------------

    echo "Installing Flatpak applications..."

    flatpak install -y flathub \
        md.obsidian.Obsidian \
        net.davidotek.pupgui2 \
        com.github.IsmaelMartinez.teams_for_linux \
        com.umlet.Umlet \
        com.discordapp.Discord \
        io.dbeaver.DBeaverCommunity \
        us.zoom.Zoom

    # --------------------------------------------------------
    # JetBrains Toolbox
    # --------------------------------------------------------

    echo "Installing JetBrains Toolbox..."

    TOOLBOX_DIR="$HOME/.local/share/JetBrains/Toolbox-App"

    if [[ ! -x "$TOOLBOX_DIR/bin/jetbrains-toolbox" ]]; then
        mkdir -p "$TOOLBOX_DIR"

        TOOLBOX_ARCHIVE="$(mktemp --suffix=.tar.gz)"

        curl -L \
            "https://data.services.jetbrains.com/products/download?code=TBA&platform=linux" \
            -o "$TOOLBOX_ARCHIVE"

        tar -xzf "$TOOLBOX_ARCHIVE" \
            --strip-components=1 \
            -C "$TOOLBOX_DIR"

        rm -f "$TOOLBOX_ARCHIVE"

		"$TOOLBOX_DIR/bin/jetbrains-toolbox" >/dev/null 2>&1 &
        echo "JetBrains Toolbox installed."
    else
        echo "JetBrains Toolbox already installed."
    fi

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
echo "NOTE: ProjectLibre is not installed automatically."
echo "Install the ProjectLibre RPM manually if required for coursework."
echo "Fedora $ROLE setup complete."
