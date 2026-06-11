#!/bin/bash

# Script rápido para corrigir tema escuro Qt5

echo "Corrigindo tema escuro para Qt5..."

# Instala pacotes necessários
sudo dnf install -y qt5ct
sudo dnf install -y kvantum 2>/dev/null || sudo dnf install -y breeze-qt5 2>/dev/null

# Cria diretório de configuração do qt5ct
mkdir -p ~/.config/qt5ct

# Configura qt5ct para tema escuro
cat > ~/.config/qt5ct/qt5ct.conf << EOF
[Appearance]
style=kvantum
color_scheme_path=
icon_theme=Adwaita
standard_dialogs=default
EOF

# Se kvantum estiver disponível, aplica tema escuro
if command -v kvantummanager &>/dev/null; then
  kvantummanager --set Kvantum 2>/dev/null || true
fi

# Configura Flatpak
flatpak override --user --env=QT_QPA_PLATFORMTHEME=qt5ct 2>/dev/null

# Adiciona variável de ambiente para Qt5
PROFILE_FILE="$HOME/.bashrc"
if ! grep -q "QT_QPA_PLATFORMTHEME" "$PROFILE_FILE" 2>/dev/null; then
  cat >> "$PROFILE_FILE" << 'EOF'

# Qt5 dark theme
export QT_QPA_PLATFORMTHEME=qt5ct
EOF
  echo "Variável de ambiente adicionada ao ~/.bashrc"
fi

echo "Correção aplicada! Efetue logout e login novamente."
