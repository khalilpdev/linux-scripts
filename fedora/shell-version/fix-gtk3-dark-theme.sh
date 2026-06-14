#!/bin/bash

# Script rápido para corrigir tema escuro GTK3

echo "Corrigindo tema escuro para GTK3..."

# Instala tema
sudo dnf install -y adw-gtk3-theme
flatpak install -y flathub org.gtk.Gtk3theme.adw-gtk3 2>/dev/null

# Cria configuração
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name = adw-gtk3-dark
gtk-application-prefer-dark-theme = true
EOF

# Aplica configurações
gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null

# Configura Flatpak
flatpak override --user --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null

# Limpa cache
rm -rf ~/.cache/gtk-3.0 ~/.cache/gtk-4.0

echo "Correção aplicada! Reinicie os aplicativos."