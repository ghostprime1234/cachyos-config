#!/usr/bin/env bash
# hosts/desktop.sh - Fedora desktop setup for Michael's NVIDIA/gaming/data science machine

set -euo pipefail



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

# ------------------------------------------------------------
# Data drive
# ------------------------------------------------------------

DATA_MOUNT="/mnt/Data"
DATA_UUID="5ae96703-ba78-4401-9c92-9d06dd52589d"

echo "Configuring data drive..."

sudo mkdir -p "$DATA_MOUNT"

if ! blkid -U "$DATA_UUID" >/dev/null 2>&1; then
    echo "WARNING: Data drive with UUID $DATA_UUID was not found."
    echo "Skipping automatic mount."
else
    DATA_DEVICE="$(blkid -U "$DATA_UUID")"

    if ! grep -q "UUID=$DATA_UUID" /etc/fstab; then
        echo "Adding data drive to /etc/fstab..."

        FILESYSTEM="$(lsblk -no FSTYPE "$DATA_DEVICE")"

        echo "UUID=$DATA_UUID $DATA_MOUNT $FILESYSTEM defaults,nofail 0 0" \
            | sudo tee -a /etc/fstab >/dev/null
    else
        echo "Data drive already exists in /etc/fstab."
    fi

    if ! mountpoint -q "$DATA_MOUNT"; then
        echo "Mounting $DATA_MOUNT..."
        sudo mount "$DATA_MOUNT"
    else
        echo "$DATA_MOUNT is already mounted."
    fi
fi

MOUNTED_UUID="$(findmnt -no UUID "$DATA_MOUNT" 2>/dev/null || true)"

if mountpoint -q "$DATA_MOUNT" && [[ "$MOUNTED_UUID" == "$DATA_UUID" ]]; then
    echo "Creating local university folder..."
    sudo mkdir -p "$DATA_MOUNT/University"
    sudo chown "$USER:$USER" "$DATA_MOUNT/University"
else
    echo "WARNING: $DATA_MOUNT is not mounted with the expected data drive (UUID $DATA_UUID)."
    echo "University directory was not created."
fi

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

echo "Installing Podman container tooling..."

sudo dnf install -y \
    podman \
    podman-compose \
    podman-docker

echo "Desktop hardware configuration complete."

echo "Building NVIDIA kernel modules..."
sudo akmods --force || true

echo "Regenerating initramfs..."
sudo dracut --force || true

echo
echo "NVIDIA setup complete."
echo "A reboot is recommended before testing NVIDIA, gaming, or Proton workloads."
