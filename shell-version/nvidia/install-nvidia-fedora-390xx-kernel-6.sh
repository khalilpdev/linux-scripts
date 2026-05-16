#!/bin/bash
# Script para instalar driver NVIDIA 390xx no Fedora
# Compatível com GeForce GT 630M / 620M (GF108)

set -e  # Para o script se algum comando falhar

echo "=== Instalando driver NVIDIA 390xx no Fedora ==="

# 1. Remover drivers conflitantes
echo "[1/8] Removendo drivers NVIDIA antigos..."
sudo dnf remove -y \*nvidia\* --exclude=nvidia-gpu-firmware 2>/dev/null
sudo rm -rf /var/cache/akmods/nvidia*

# 2. Adicionar RPM Fusion
echo "[2/8] Adicionando repositório RPM Fusion..."
sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 3. Instalar kernel headers
echo "[3/8] Instalando headers do kernel..."
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers

# 4. Instalar driver 390xx
echo "[4/8] Instalando driver NVIDIA 390xx..."
sudo dnf install -y akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx xorg-x11-drv-nvidia-390xx-cuda

# 5. Instalar bibliotecas 32-bit
echo "[5/8] Instalando bibliotecas 32-bit..."
sudo dnf install -y xorg-x11-drv-nvidia-390xx-libs.i686

# 6. Bloquear nouveau
echo "[6/8] Bloqueando driver nouveau..."
sudo tee /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF

# 7. Configurar módulo NVIDIA
echo "[7/8] Configurando módulo NVIDIA..."
sudo tee /etc/modprobe.d/nvidia-optimus.conf << EOF
options nvidia modeset=1
options nvidia_drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnableMSI=0
options nvidia NVreg_RegisterForACPIEvents=1
EOF

# 8. Desabilitar Wayland para driver 390xx
echo "[8/8] Configurando X11 em vez de Wayland..."
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /etc/gdm/custom.conf 2>/dev/null || echo "Arquivo custom.conf não encontrado"

# Recriar initramfs e compilar módulo
echo "Compilando módulo NVIDIA (pode levar 2-5 minutos)..."
sudo dracut --force
sudo akmods --force

echo "=========================================="
echo "✅ Instalação concluída!"
echo "=========================================="
echo "⚠️  Reinicie o sistema para ativar o driver:"
echo "   sudo reboot"
echo ""
echo "Após reiniciar, verifique com:"
echo "   nvidia-smi"
echo "   lsmod | grep nvidia"