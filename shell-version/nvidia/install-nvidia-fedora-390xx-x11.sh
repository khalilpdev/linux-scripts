#!/bin/bash

# Instala e ativa o NVIDIA 390xx no Fedora 42+ com sessão X11 no KDE.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script não deve ser executado como root."
        print_error "Execute como usuário normal; o script usa sudo quando necessário."
        exit 1
    fi
}

check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Este script foi projetado apenas para Fedora Linux."
        exit 1
    fi

    local fedora_version
    fedora_version=$(rpm -E %fedora)
    print_info "Sistema detectado: Fedora $fedora_version"

    if [[ $fedora_version -lt 42 ]]; then
        print_warning "O fluxo foi preparado para Fedora 42 ou superior."
        read -r -p "Deseja continuar mesmo assim? (s/N): " reply
        if [[ ! "$reply" =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

install_repos() {
    print_info "Garantindo os repositórios RPM Fusion..."
    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    print_info "Ativando suporte ao Plasma X11..."
    sudo dnf install -y 'dnf-command(copr)'
    sudo dnf copr enable -y @kdesig/plasma6-x11-unsupported
}

install_packages() {
    print_info "Instalando o driver 390xx e dependências do KDE X11..."
    sudo dnf install -y \
        kernel-devel-$(uname -r) \
        kernel-headers \
        gcc \
        make \
        dkms \
        akmod-nvidia-390xx \
        xorg-x11-drv-nvidia-390xx \
        xorg-x11-drv-nvidia-390xx-cuda \
        plasma-workspace-x11 \
        kwin-x11
}

configure_nvidia() {
    print_info "Removendo bloqueios do Nouveau criados por instalações anteriores..."
    sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
    sudo rm -f /usr/lib/modprobe.d/nvidia-installer-disable-nouveau.conf
    sudo rm -f /etc/modprobe.d/blacklist-nvidia-390xx.conf

    print_info "Bloqueando o Nouveau e habilitando parâmetros do NVIDIA..."
    sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

    sudo tee /etc/modprobe.d/nvidia-optimus.conf >/dev/null <<'EOF'
options nvidia modeset=1
options nvidia_drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnableMSI=0
options nvidia NVreg_RegisterForACPIEvents=1
EOF

    print_info "Criando fallback de Xorg para o NVIDIA 390xx..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/10-nvidia-390xx.conf >/dev/null <<'EOF'
Section "Device"
    Identifier "NVIDIA 390xx"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration" "true"
EndSection
EOF
}

configure_x11() {
    print_info "Configurando o SDDM para usar X11..."
    local user_name
    user_name="${SUDO_USER:-$USER}"

    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-nvidia-x11.conf >/dev/null <<'EOF'
[General]
DisplayServer=x11

[X11]
SessionDir=/usr/share/xsessions
EOF

    sudo mkdir -p /var/lib/sddm
    sudo tee /var/lib/sddm/state.conf >/dev/null <<EOF
[Last]
Session=plasmax11.desktop
User=${user_name}
EOF
}

rebuild_boot_image() {
    print_info "Recriando initramfs do kernel atual..."
    local kernel_version
    kernel_version="$(uname -r)"

    if ! sudo dracut --force "/boot/initramfs-${kernel_version}.img" "${kernel_version}"; then
        print_warning "O dracut falhou. Você pode precisar recriar o initramfs manualmente depois."
    fi
}

main() {
    check_root
    check_fedora
    install_repos
    install_packages
    configure_nvidia
    configure_x11
    rebuild_boot_image

    echo
    echo "=========================================="
    print_success "Driver NVIDIA 390xx ativado com SDDM e sessão Plasma X11."
    echo "=========================================="
    echo
    echo "Após reiniciar, selecione Plasma (X11) na tela de login se necessário."
    echo "Verifique com:"
    echo "  lsmod | grep -E 'nouveau|nvidia'"
    echo "  echo \$XDG_SESSION_TYPE"
    echo "  glxinfo | grep \"OpenGL renderer\""
    echo
    read -r -p "Deseja reiniciar agora? (s/N): " reply
    if [[ "$reply" =~ ^[Ss]$ ]]; then
        sudo reboot
    else
        print_warning "Reinicie manualmente quando quiser aplicar tudo."
    fi
}

main
