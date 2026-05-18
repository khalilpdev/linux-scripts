#!/usr/bin/env bash

echo "============================================="
echo "⚙️ Enabling Auto-Login on Fedora 44 KDE..."
echo "============================================="

# 1. Grab the currently logged-in user (ignoring sudo context)
TARGET_USER="${SUDO_USER:-$USER}"

if [ "$TARGET_USER" = "root" ]; then
    echo "❌ Error: Do not run this script as root directly."
    echo "Run it as your normal user (it will prompt for sudo when needed)."
    exit 1
fi

echo "-> Target user detected: $TARGET_USER"

# 2. Define the configuration directory and file path
# Fedora 44 handles login configs dynamically in this directory
CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="$CONFIG_DIR/kde_settings.conf"

echo "-> Creating configuration directory..."
sudo mkdir -p "$CONFIG_DIR"

# 3. Write the Autologin blocks
echo "-> Writing auto-login configurations to $CONFIG_FILE..."
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
[Autologin]
Relogin=false
Session=plasmawayland.desktop
User=$TARGET_USER

[General]
NumLock=on
EOF

# 4. Set appropriate permissions on the file
sudo chmod 644 "$CONFIG_FILE"

echo "============================================="
echo "✅ Auto-login enabled successfully!"
echo "🔄 Reboot your computer to test the setup."
echo "============================================="
