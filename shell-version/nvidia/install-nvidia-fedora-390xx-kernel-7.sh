#!/bin/bash
# Script para instalar/REPARAR driver NVIDIA 390xx no Fedora
# Compatível com GeForce GT 630M / 620M (GF108)
# v2 - Com correções para kernel 7.x e libglx

set -e  # Para o script se algum comando falhar

echo "=== Instalando/Reparando driver NVIDIA 390xx no Fedora (v2) ==="

# 1. Remover drivers conflitantes
echo "[1/9] Removendo drivers NVIDIA antigos e cache..."
sudo dnf remove -y \*nvidia\* --exclude=nvidia-gpu-firmware 2>/dev/null
sudo rm -rf /var/cache/akmods/nvidia*
sudo rm -rf /var/lib/nvidia

# 2. Adicionar RPM Fusion (se não tiver)
echo "[2/9] Verificando repositório RPM Fusion..."
if ! dnf repolist | grep -q rpmfusion-nonfree; then
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
fi

# 3. Instalar kernel headers e ferramentas de build
echo "[3/9] Instalando headers e ferramentas do kernel..."
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers gcc make dkms

# 4. Instalar driver 390xx
echo "[4/9] Instalando driver NVIDIA 390xx..."
sudo dnf install -y akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx xorg-x11-drv-nvidia-390xx-cuda

# 5. Instalar bibliotecas 32-bit
echo "[5/9] Instalando bibliotecas 32-bit..."
sudo dnf install -y xorg-x11-drv-nvidia-390xx-libs.i686

# 6. Bloquear nouveau (mais agressivo)
echo "[6/9] Bloqueando driver nouveau..."
sudo tee /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# 7. Configurar módulo NVIDIA com parâmetros otimizados
echo "[7/9] Configurando módulo NVIDIA..."
sudo tee /etc/modprobe.d/nvidia-optimus.conf << EOF
options nvidia modeset=1
options nvidia_drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnableMSI=0
options nvidia NVreg_RegisterForACPIEvents=1
options nvidia NVreg_DynamicPowerManagement=0x02
EOF

# 8. Forçar compilação do módulo
echo "[8/9] Compilando módulo NVIDIA (pode levar 3-5 minutos)..."
sudo akmods --force --rebuild

# 9. CORREÇÃO CRÍTICA: Reparar o link da libglx (problema do kernel 7.x)
echo "[9/9] Aplicando correção da libglx para kernel 7.x..."

# Aguarda o akmods terminar completamente
sleep 5

# Localiza o arquivo correto da libglx
LIBGLX_PATH=$(find /usr/lib64 -name "libglx.so.390.157" 2>/dev/null | head -1)

if [ -n "$LIBGLX_PATH" ]; then
    echo "   Encontrado: $LIBGLX_PATH"
    # Remove links antigos
    sudo rm -f /usr/lib64/xorg/modules/extensions/libglx.so
    sudo rm -f /usr/lib64/xorg/modules/extensions/libglx.so.old
    
    # Cria o link correto
    sudo ln -sf "$LIBGLX_PATH" /usr/lib64/xorg/modules/extensions/libglx.so
    echo "   ✅ Link da libglx corrigido"
else
    echo "   ⚠️  libglx.so.390.157 não encontrada, tentando método alternativo..."
    # Método alternativo: reinstalar apenas a parte Xorg
    sudo dnf reinstall -y xorg-x11-drv-nvidia-390xx
fi

# Força recriação do initramfs com o módulo correto
echo "   Recriando initramfs..."
sudo dracut --force --regenerate-all

# Configuração extra: garantir que X11 seja usado
echo "   Configurando X11 como padrão..."
if [ -f /etc/gdm/custom.conf ]; then
    sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /etc/gdm/custom.conf
    sudo sed -i 's/WaylandEnable=true/WaylandEnable=false/g' /etc/gdm/custom.conf
else
    echo "WaylandEnable=false" | sudo tee -a /etc/gdm/custom.conf
fi

# Limpeza final
echo "   Limpando caches..."
sudo rm -rf /var/cache/akmods/nvidia-390xx/*.failed.log 2>/dev/null

# Verificação pós-instalação
echo ""
echo "=========================================="
echo "✅ Instalação/Reparo concluído!"
echo "=========================================="

echo ""
echo "🔍 Verificando módulo compilado..."
if ls /lib/modules/$(uname -r)/extra/nvidia*.ko 2>/dev/null | grep -q nvidia; then
    echo "   ✅ Módulo NVidia encontrado!"
else
    echo "   ⚠️  Módulo não encontrado - pode precisar de reboot"
fi

echo ""
echo "⚠️  IMPORTANTE:"
echo "1. REINICIE o sistema AGORA: sudo reboot"
echo ""
echo "2. APÓS reiniciar, verifique com:"
echo "   nvidia-smi"
echo "   lsmod | grep nvidia"
echo "   glxinfo | grep \"OpenGL renderer\""
echo ""
echo "3. Se ainda tiver problemas, veja o log:"
echo "   sudo cat /var/log/nvidia-installer.log"
echo "   sudo journalctl -xe | grep -i nvidia"
echo ""

# Oferece reboot automático
read -p "Deseja reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Reiniciando..."
    sudo reboot
else
    echo "Lembre-se de reiniciar manualmente depois!"
fi