#!/usr/bin/env bash

echo "============================================="
echo "⚙️ Fixing GNOME/GTK Dark Mode on Fedora KDE..."
echo "============================================="

# 1. Fix GTK4 / Libadwaita apps via gsettings
echo "-> Setting GTK4 color scheme preference to dark..."
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# 2. Fix GTK3 / Legacy apps via configuration file
echo "-> Configuring GTK3 settings.ini..."
mkdir -p ~/.config/gtk-3.0
if ! grep -q "gtk-application-prefer-dark-theme=1" ~/.config/gtk-3.0/settings.ini 2>/dev/null; then
    cat <<EOF >> ~/.config/gtk-3.0/settings.ini
[Settings]
gtk-application-prefer-dark-theme=1
EOF
fi

# 3. Clean up potentially broken GTK4 cache directories
echo "-> Cleaning conflicting GTK4 local cache..."
rm -rf ~/.config/gtk-4.0/

# 4. Install required system compatibility themes and configs
echo "-> Installing system compatibility packages (requires sudo)..."
sudo dnf install -y kde-gtk-config breeze-gtk gnome-themes-extra

# 5. Fix Flatpak applications permissions if flatpak is installed
if command -v flatpak &> /dev/null; then
    echo "-> Applying dark theme overrides to Flatpaks..."
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
else
    echo "-> Flatpak not detected, skipping Flatpak overrides."
fi

echo "============================================="
echo "✅ Done! Please LOG OUT and LOG BACK IN now."
echo "============================================="
