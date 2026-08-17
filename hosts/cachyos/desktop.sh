#!/bin/bash
# hosts/desktop.sh - Optimized for Michael's RTX 5070 Ti & CachyOS

echo "🎮 Configuring Desktop for Blackwell GPU & University Workflow..."

# 1. Install CachyOS Gaming Meta & NVIDIA Drivers
# We use 'nvidia-cachyos-dkms' to ensure the driver rebuilds automatically
# whenever CachyOS updates your kernel (which happens often!)
sudo pacman -S --needed --noconfirm \
    cachyos-gaming-meta \
    nvidia-dkms \
    lib32-nvidia-utils-cachyos \
    nvidia-settings \
    cuda \
    direnv

# 2. NVIDIA Power Management & Sleep Fixes
# Critical for Blackwell: Preserves VRAM state during sleep to prevent crashes
echo "🔧 Configuring NVIDIA Power Management..."
sudo systemctl enable --now nvidia-hibernate.service nvidia-resume.service nvidia-suspend.service

# Apply the kernel parameter for VRAM preservation
if [ ! -f /etc/modprobe.d/nvidia-power.conf ]; then
    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee /etc/modprobe.d/nvidia-power.conf
fi

# 3. Create Local University Folders (Michael's Directory Structure)
echo "📂 Initializing University directory structure..."
mkdir -p "/mnt/Data/University"
mkdir -p "$HOME/Synology_Home"

# 4. Performance Tuning (Optional but recommended for Desktop)
# Sets the CPU governor to 'performance' for your data science workloads
if command -v powerprofilesctl &> /dev/null; then
    powerprofilesctl set performance
fi

# 5. RGB Control (OpenRGB)
echo "Instaling OpenRGB for Blackwell/System lighting..."
# openrgb-dkms-git ensures the i2c-piix4 and i2c-nvidia-drivers are rebuilt for my CachyOS kernel
paru -S --needed --noconfirm openrgb

# Enable the OpenRGB SDK server for background control
sudo systemctl enable --now openrgb.service

# Load the i2c-dev module (required for GPU/Motherboard communication)
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf sudo modprobe i2c-dev

echo "✅ Desktop Hardware Configuration Complete!"
