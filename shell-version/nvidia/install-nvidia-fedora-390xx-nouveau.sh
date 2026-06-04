#!/bin/bash

# Instala os pacotes NVIDIA 390xx no Fedora 42+,
# mas mantém o Nouveau como driver ativo.

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
}

install_packages() {
    print_info "Instalando o driver 390xx e dependências de build..."
    sudo dnf install -y \
        kernel-devel-$(uname -r) \
        kernel-headers \
        gcc \
        make \
        dkms \
        akmod-nvidia-390xx \
        xorg-x11-drv-nvidia-390xx \
        xorg-x11-drv-nvidia-390xx-cuda \
        xorg-x11-drv-nvidia-390xx-libs.i686
}

restore_nouveau() {
    print_info "Removendo bloqueios automáticos do Nouveau..."
    sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
    sudo rm -f /usr/lib/modprobe.d/nvidia-installer-disable-nouveau.conf
    sudo rm -f /etc/modprobe.d/nvidia-optimus.conf

    print_info "Bloqueando o carregamento automático dos módulos NVIDIA..."
    sudo tee /etc/modprobe.d/blacklist-nvidia-390xx.conf >/dev/null <<'EOF'
blacklist nvidia
blacklist nvidia-drm
blacklist nvidia-modeset
blacklist nvidia-uvm
EOF
}

rebuild_boot_images() {
    print_info "Recriando initramfs..."
    sudo dracut --force --regenerate-all
}

main() {
    check_root
    check_fedora
    install_repos
    install_packages
    restore_nouveau
    rebuild_boot_images

    echo
    echo "=========================================="
    print_success "Driver NVIDIA 390xx instalado sem desativar o Nouveau."
    echo "=========================================="
    echo
    echo "Após reiniciar, o sistema deve continuar usando Nouveau/Wayland."
    echo "Verifique com:"
    echo "  lsmod | grep -E 'nouveau|nvidia'"
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
