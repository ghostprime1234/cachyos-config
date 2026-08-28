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
VAULT_MOUNT="/mnt/MDS_VAULT"
VAULT_UUID="a358df98-79a1-42fb-af5c-d38f43c60305"

echo "Configuring data drive..."

sudo mkdir -p "$DATA_MOUNT"

if ! blkid -U "$DATA_UUID" >/dev/null 2>&1; then
    echo "WARNING: Data drive with UUID $DATA_UUID was not found."
    echo "Skipping automatic mount."
else
    DATA_DEVICE="$(blkid -U "$DATA_UUID")"

    if grep -Eq "^[[:space:]]*UUID=${DATA_UUID}[[:space:]]+${DATA_MOUNT}[[:space:]]" /etc/fstab; then
        echo "Data drive already exists in /etc/fstab."
    elif grep -Eq "^[[:space:]]*UUID=${DATA_UUID}[[:space:]]" /etc/fstab; then
        echo "ERROR: Data drive UUID $DATA_UUID is configured for a different mount point in /etc/fstab."
        exit 1
    else
        echo "Adding data drive to /etc/fstab..."

        FILESYSTEM="$(lsblk -no FSTYPE "$DATA_DEVICE")"

        if [[ -z "$FILESYSTEM" ]]; then
            echo "ERROR: Unable to determine the filesystem type for $DATA_DEVICE."
            exit 1
        fi

        echo "UUID=$DATA_UUID $DATA_MOUNT $FILESYSTEM defaults,nofail 0 0" \
            | sudo tee -a /etc/fstab >/dev/null
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

echo "Configuring MDS_VAULT mount point..."

sudo mkdir -p "$VAULT_MOUNT"

if ! blkid -U "$VAULT_UUID" >/dev/null 2>&1; then
    echo "WARNING: MDS_VAULT with UUID $VAULT_UUID was not found."
    echo "Skipping automatic mount."
elif grep -Eq "^[[:space:]]*UUID=${VAULT_UUID}[[:space:]]+${VAULT_MOUNT}[[:space:]]" /etc/fstab; then
    echo "MDS_VAULT already exists in /etc/fstab."
elif grep -Eq "^[[:space:]]*UUID=${VAULT_UUID}[[:space:]]" /etc/fstab; then
    echo "ERROR: MDS_VAULT UUID $VAULT_UUID is configured for a different mount point in /etc/fstab."
    exit 1
else
    echo "Adding MDS_VAULT to /etc/fstab..."
    echo "UUID=$VAULT_UUID $VAULT_MOUNT btrfs defaults,nofail 0 0" \
        | sudo tee -a /etc/fstab >/dev/null
fi

if blkid -U "$VAULT_UUID" >/dev/null 2>&1 && ! mountpoint -q "$VAULT_MOUNT"; then
    echo "Mounting $VAULT_MOUNT..."
    sudo mount "$VAULT_MOUNT"
fi

VAULT_IDENTITY="$(findmnt -no FSTYPE,LABEL,UUID "$VAULT_MOUNT" 2>/dev/null || true)"
if mountpoint -q "$VAULT_MOUNT" &&
   [[ "$VAULT_IDENTITY" != "btrfs MDS_VAULT $VAULT_UUID" ]]; then
    echo "ERROR: $VAULT_MOUNT is not the expected MDS_VAULT Btrfs filesystem."
    exit 1
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
