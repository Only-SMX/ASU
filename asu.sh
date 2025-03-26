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

# Step 1: Remove all snap packages
echo "Removing all installed Snap packages..."
snap_packages=$(snap list | awk 'NR>1 {print $1}')
for package in $snap_packages; do
    echo "Removing $package..."
    snap remove --purge "$package"
done

# Step 2: Stop and disable snap services
echo "Stopping and disabling Snap services..."
systemctl stop snapd.socket snapd.service
systemctl disable snapd.socket snapd.service

# Step 3: Remove snapd and related packages
echo "Removing Snap daemon and related packages..."
apt-get purge -y snapd gnome-software-plugin-snap

# Step 4: Remove remaining files and directories
echo "Cleaning up remaining Snap files..."
rm -rf /var/cache/snapd/
rm -rf /var/lib/snapd/
rm -rf /snap/
rm -rf ~/snap/

# Step 5: Prevent snap from being reinstalled
echo "Preventing Snap from being reinstalled..."
cat > /etc/apt/preferences.d/no-snap.pref <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Step 6: Update package list
echo "Updating package list..."
apt-get update

# Step 7: Optional: Install gnome-software without snap support
echo "Reinstalling gnome-software without snap support..."
apt-get install -y gnome-software

echo "=== Snap removal completed successfully ==="
echo "You may want to reboot your system to complete the removal process."
