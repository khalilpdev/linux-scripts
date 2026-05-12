#!/bin/bash
# Script REPARO RÁPIDO para driver NVIDIA 390xx no Fedora
# Apenas corrige o que foi quebrado por atualizações
# Sem reinstalar drivers - apenas repara links e recria módulos

echo "=== Reparando driver NVIDIA 390xx (pós-atualização) ==="

# 1. Verificar se o driver está instalado
echo "[1/6] Verificando instalação do driver..."
if ! rpm -qa | grep -q nvidia-390xx; then
    echo "❌ Driver NVIDIA 390xx não encontrado!"
    echo "   Execute o script de instalação completo primeiro."
    exit 1
fi
echo "   ✅ Driver encontrado"

# 2. Parar qualquer processo NVIDIA rodando
echo "[2/6] Parando serviços NVIDIA..."
sudo systemctl stop gdm 2>/dev/null || sudo systemctl stop sddm 2>/dev/null || true
sudo rmmod nvidia nvidia_drm nvidia_modeset nvidia_uvm 2>/dev/null || true

# 3. Forçar recompilação do módulo do kernel
echo "[3/6] Recompilando módulo do kernel (pode levar 2-3 minutos)..."
sudo akmods --force --rebuild

# 4. CORREÇÃO PRINCIPAL: Reparar o link da libglx
echo "[4/6] 👈 CORREÇÃO PRINCIPAL: Reparando libglx..."

# Aguarda o akmods terminar
sleep 3

# Busca o arquivo correto da libglx em vários lugares possíveis
LIBGLX_FILE=""
for path in /usr/lib64/xorg/modules/extensions/nvidia/libglx.so.390.157 \
            /usr/lib64/xorg/modules/extensions/libglx.so.390.157 \
            /usr/lib64/nvidia/xorg/libglx.so.390.157 \
            /usr/lib64/xorg/nvidia/libglx.so.390.157; do
    if [ -f "$path" ]; then
        LIBGLX_FILE="$path"
        break
    fi
done

# Se não encontrou, busca com find
if [ -z "$LIBGLX_FILE" ]; then
    LIBGLX_FILE=$(sudo find /usr -name "libglx.so.390.157" 2>/dev/null | head -1)
fi

if [ -n "$LIBGLX_FILE" ]; then
    echo "   Arquivo encontrado: $LIBGLX_FILE"
    
    # Remove links antigos/quebrados
    sudo rm -f /usr/lib64/xorg/modules/extensions/libglx.so
    sudo rm -f /usr/lib64/xorg/modules/extensions/libglx.so.bak
    
    # Cria link correto
    sudo ln -sf "$LIBGLX_FILE" /usr/lib64/xorg/modules/extensions/libglx.so
    echo "   ✅ Link reparado: /usr/lib64/xorg/modules/extensions/libglx.so -> $LIBGLX_FILE"
else
    echo "   ⚠️  Arquivo libglx.so.390.157 não encontrado!"
    echo "   Tentando reinstalar apenas o pacote Xorg do driver..."
    sudo dnf reinstall -y xorg-x11-drv-nvidia-390xx
    
    # Tenta novamente após reinstalar
    LIBGLX_FILE=$(sudo find /usr -name "libglx.so.390.157" 2>/dev/null | head -1)
    if [ -n "$LIBGLX_FILE" ]; then
        sudo ln -sf "$LIBGLX_FILE" /usr/lib64/xorg/modules/extensions/libglx.so
        echo "   ✅ Link reparado após reinstalação parcial"
    else
        echo "   ❌ ERRO CRÍTICO: libglx.so.390.157 continua ausente"
        exit 1
    fi
fi

# 5. Recriar initramfs com o módulo correto
echo "[5/6] Recriando initramfs..."
sudo dracut --force --regenerate-all

# 6. Verificar se o módulo foi compilado
echo "[6/6] Verificando módulos compilados..."
MODULE_PATH="/lib/modules/$(uname -r)/extra/nvidia.ko.xz"
if [ -f "$MODULE_PATH" ] || [ -f "${MODULE_PATH%.xz}" ]; then
    echo "   ✅ Módulo NVIDIA encontrado"
    ls -la /lib/modules/$(uname -r)/extra/nvidia*.ko* 2>/dev/null | head -3
else
    echo "   ⚠️  Módulo não encontrado, tentando carregar manualmente..."
    sudo modprobe nvidia
fi

echo ""
echo "=========================================="
echo "✅ REPARO CONCLUÍDO!"
echo "=========================================="
echo ""
echo "📋 O que foi reparado:"
echo "   ✅ Recompilação forçada do módulo"
echo "   ✅ Link da libglx corrigido"
echo "   ✅ Initramfs recriado"
echo ""
echo "⚠️  REINICIE O SISTEMA:"
echo "   sudo reboot"
echo ""
echo "🔍 Após reiniciar, verifique com:"
echo "   nvidia-smi"
echo "   lsmod | grep nvidia"
echo "   glxinfo | grep -i \"openGL\""
echo ""

read -p "Reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Reiniciando..."
    sudo reboot
else
    echo "Lembre-se de reiniciar manualmente depois!"
fi