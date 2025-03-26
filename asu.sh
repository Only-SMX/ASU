#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Verify Ubuntu version
if ! grep -q 'Ubuntu 24.04' /etc/os-release; then
    echo "This script is intended for Ubuntu 24.04 only."
    exit 1
fi

echo "=== Starting Snap removal process ==="

# Step 1: First attempt to remove all snap packages normally
echo "Attempting to remove all installed Snap packages..."
snap_packages=$(snap list | awk 'NR>1 {print $1}')
for package in $snap_packages; do
    echo "Removing $package..."
    snap remove --purge "$package" 2>/dev/null || true
done

# Step 2: Forcefully remove any remaining snaps (handles "being used by snap" error)
echo "Forcefully removing any remaining snap packages..."
for package in $(snap list | awk 'NR>1 {print $1}'); do
    echo "Force removing $package..."
    # Unmount any snap mounts first
    umount /snap/$package/* 2>/dev/null || true
    # Remove the snap
    snap remove --purge "$package" --no-wait 2>/dev/null || true
done

# Step 3: Completely stop and disable all snap services
echo "Stopping and disabling ALL Snap services..."
systemctl stop snapd.socket snapd.service snapd.seeded.service
systemctl disable snapd.socket snapd.service snapd.seeded.service

# Step 4: Kill any remaining snap processes
echo "Killing any remaining snap processes..."
pkill -9 -f snapd 2>/dev/null || true
pkill -9 -f snap-confine 2>/dev/null || true

# Step 5: Unmount any remaining snap mounts
echo "Unmounting any remaining snap mounts..."
umount /snap/* 2>/dev/null || true
umount /var/snap/* 2>/dev/null || true

# Step 6: Remove snapd and related packages
echo "Removing Snap daemon and related packages..."
apt-get purge -y snapd gnome-software-plugin-snap

# Step 7: Remove remaining files and directories
echo "Cleaning up remaining Snap files..."
rm -rf /var/cache/snapd/
rm -rf /var/lib/snapd/
rm -rf /snap/
rm -rf /var/snap/
rm -rf ~/snap/

# Step 8: Prevent snap from being reinstalled
echo "Preventing Snap from being reinstalled..."
cat > /etc/apt/preferences.d/no-snap.pref <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Step 9: Update package list
echo "Updating package list..."
apt-get update

# Step 10: Optional: Install gnome-software without snap support
echo "Reinstalling gnome-software without snap support..."
apt-get install -y --reinstall gnome-software

echo "=== Snap removal completed successfully ==="
echo "You should reboot your system to complete the removal process."
