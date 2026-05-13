#!/bin/bash

# Script para instalar winetricks mantendo winehq-devel
# Para Fedora com WineHQ já instalado

echo "=== INSTALANDO WINETRICKS (MANUAL) ==="
echo ""

# Instalar dependências
echo "📦 Instalando dependências..."
sudo dnf install -y cabextract p7zip unzip wget

# Remover winetricks do Fedora se existir
sudo dnf remove -y winetricks 2>/dev/null

# Baixar winetricks diretamente do GitHub
echo "📥 Baixando winetricks..."
sudo wget -O /usr/local/bin/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks

# Dar permissão de execução
sudo chmod +x /usr/local/bin/winetricks

# Verificar instalação
if command -v winetricks &> /dev/null; then
    echo "✅ winetricks instalado com sucesso!"
    echo "📍 Localização: $(which winetricks)"
    echo ""
    echo "📌 Para usar com seu prefixo MK:"
    echo "   export WINEPREFIX=\"/home/leandro/Games/MK_Solano_64\""
    echo "   export WINEARCH=\"win64\""
    echo "   winetricks"
else
    echo "❌ Falha na instalação"
    exit 1
fi

echo ""
echo "=== PRONTO PARA USAR ==="
