#!/bin/bash
# CORREÇÃO DEFINITIVA - NVIDIA 390xx para kernel 7.x
# Modifica o código fonte antes da compilação

set -e

echo "=== CORREÇÃO DEFINITIVA NVIDIA 390xx ==="

# 1. Instalar fonte do driver se não tiver
echo "[1/6] Garantindo fonte do driver..."
if ! rpm -qa | grep -q nvidia-390xx-kmodsrc; then
    sudo dnf install -y xorg-x11-drv-nvidia-390xx-kmodsrc
fi

# 2. Limpar builds antigos
echo "[2/6] Limpando caches..."
sudo systemctl stop akmods 2>/dev/null || true
sudo rm -rf /var/cache/akmods/nvidia-390xx
sudo rm -rf /var/lib/akmods/nvidia-390xx

# 3. Forçar akmods criar o diretório de build
echo "[3/6] Criando ambiente de build..."
sudo akmods --force --rebuild &
AKMODS_PID=$!
sleep 15
sudo kill $AKMODS_PID 2>/dev/null || true

# 4. Localizar e patch o arquivo fonte
echo "[4/6] Aplicando patch no código fonte..."

# Encontra o diretório de fonte
SOURCE_DIR=$(find /usr/src -type d -name "nvidia-390xx-kmod-*" 2>/dev/null | head -1)

if [ -z "$SOURCE_DIR" ]; then
    # Extrai manualmente
    cd /usr/src
    sudo rpm2cpio $(rpm -ql xorg-x11-drv-nvidia-390xx-kmodsrc | grep .src.rpm | head -1) | sudo cpio -idmv 2>/dev/null || true
    SOURCE_DIR=$(find /usr/src -type d -name "nvidia-390xx-kmod-*" 2>/dev/null | head -1)
fi

if [ -z "$SOURCE_DIR" ]; then
    echo "❌ Não encontrou fonte do driver"
    exit 1
fi

echo "   Source dir: $SOURCE_DIR"

# Arquivo a ser patchado
OS_INTERFACE="$SOURCE_DIR/nvidia/os-interface.c"

if [ ! -f "$OS_INTERFACE" ]; then
    echo "❌ os-interface.c não encontrado"
    exit 1
fi

# Fazer backup
sudo cp "$OS_INTERFACE" "$OS_INTERFACE.original"

# PATCH: Adicionar declaração extern no início do arquivo
sudo sed -i '1i\
/* PATCH para kernel 7.x - Adiciona declaração extern */\
extern struct screen_info screen_info;\
' "$OS_INTERFACE"

# PATCH alternativo: Modificar a função para não usar screen_info
sudo sed -i '/^static void os_get_screen_info/,/^}/c\
static void os_get_screen_info(void)\
{\
    /* PATCH: Função desabilitada para kernel 7.x */\
    nv_printf(NV_DBG_INFO, "os_get_screen_info: disabled for kernel 7.0.4+\\n");\
    return;\
}' "$OS_INTERFACE"

echo "   ✅ Patch aplicado"

# 5. Copiar fonte patchada para o local correto
echo "[5/6] Preparando build..."
BUILD_DIR="/var/cache/akmods/nvidia-390xx/390.157-24-for-$(uname -r)/_kmod_build_$(uname -r)"
sudo mkdir -p "$(dirname "$BUILD_DIR")"

if [ -d "$BUILD_DIR" ]; then
    sudo cp "$OS_INTERFACE" "$BUILD_DIR/nvidia/os-interface.c"
fi

# 6. Recompilar
echo "[6/6] Recompilando módulo..."
sudo akmods --force --rebuild

echo ""
echo "✅ Processo concluído!"
echo "Verificando resultado..."

sleep 10

# Verificar
if ls /lib/modules/$(uname -r)/extra/nvidia*.ko* 2>/dev/null | grep -q nvidia; then
    echo "🎉 SUCESSO! Módulo compilado!"
    sudo dracut --force
    echo ""
    echo "=========================================="
    echo "✅ REINICIE O SISTEMA AGORA!"
    echo "   sudo reboot"
    echo "=========================================="
else
    echo "⚠️ Ainda falhou, veja o log:"
    sudo tail -50 /var/cache/akmods/nvidia-390xx/*.failed.log 2>/dev/null | grep -i error
fi