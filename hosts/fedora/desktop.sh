#!/usr/bin/env bash
# hosts/desktop.sh - Fedora desktop setup for Michael's NVIDIA/gaming/data science machine

set -euo pipefail

echo "Configuring Fedora desktop for NVIDIA, gaming, and university workflow..."
# ------------------------------------------------------------
# Hostname
# ------------------------------------------------------------

DESIRED_HOSTNAME="michael-desktop-fedora"

if [[ "$(hostnamectl --static)" != "$DESIRED_HOSTNAME" ]]; then
    echo "Setting hostname to $DESIRED_HOSTNAME..."
    sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"
else
    echo "Hostname already configured."
fi

# NVIDIA + CUDA support from RPM Fusion.
# Assumes RPM Fusion free/nonfree repos were already enabled by setup-fedora.sh.
sudo dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-cuda-libs \
    nvidia-settings \
    kernel-devel \
    kernel-headers \
    gcc \
    make

echo "Configuring NVIDIA power management..."

if [[ ! -f /etc/modprobe.d/nvidia-power.conf ]]; then
  echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee /etc/modprobe.d/nvidia-power.conf >/dev/null
fi

# These services exist once the NVIDIA RPM Fusion packages are installed.
sudo systemctl enable nvidia-hibernate.service nvidia-resume.service nvidia-suspend.service 2>/dev/null || true

echo "Creating local university folder..."
sudo mkdir -p "/mnt/Data/University"
sudo chown "$USER:$USER" "/mnt/Data/University"

if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set performance || true
fi

echo "Installing OpenRGB..."
sudo dnf install -y openrgb || echo "OpenRGB was not available from enabled Fedora repos."

echo "Loading i2c-dev for RGB/hardware control..."
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
sudo modprobe i2c-dev || true

if systemctl list-unit-files | grep -q '^openrgb\.service'; then
  sudo systemctl enable --now openrgb.service
fi

echo "Installing gaming performance tools..."
sudo dnf install -y gamemode

echo "Desktop hardware configuration complete."

echo "Building NVIDIA kernel modules..."
sudo akmods --force || true

echo "Regenerating initramfs..."
sudo dracut --force || true

echo
echo "NVIDIA setup complete."
echo "A reboot is recommended before testing NVIDIA, gaming, or Proton workloads."
