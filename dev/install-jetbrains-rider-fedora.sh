#!/bin/bash

# Script de instalação do JetBrains Rider (e Toolbox) no Fedora
# O JetBrains Toolbox gerencia a instalação e atualização do Rider e outras IDEs
# Autor: Assistente
# Data: $(date +%Y-%m-%d)

set -e

# Cores para output no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script NÃO deve ser executado como root."
        print_error "Execute como um usuário normal com privilégios sudo."
        exit 1
    fi
}

check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Este script foi projetado apenas para Fedora Linux."
        exit 1
    fi

    local fedora_version=$(rpm -E %fedora)
    print_info "Sistema detectado: Fedora $fedora_version"
}

install_dependencies() {
    print_info "Instalando dependências..."
    sudo dnf install -y wget tar xz gtk3 libXtst libXxf86vm libXScrnSaver

    print_success "Dependências instaladas"
}

download_and_install_toolbox() {
    local toolbox_url="https://download.jetbrains.com/toolbox/jetbrains-toolbox-latest.tar.gz"
    local install_dir="$HOME/.local/share/JetBrains/Toolbox"

    print_info "Baixando JetBrains Toolbox..."
    wget -O /tmp/jetbrains-toolbox.tar.gz "$toolbox_url"

    print_info "Extraindo JetBrains Toolbox..."
    mkdir -p "$install_dir"
    tar -xzf /tmp/jetbrains-toolbox.tar.gz -C "$install_dir" --strip-components=1

    # Localiza o binário (o nome do diretório varia conforme a versão)
    local toolbox_bin=$(find "$install_dir" -name "jetbrains-toolbox" -type f | head -1)

    if [[ -n "$toolbox_bin" ]]; then
        chmod +x "$toolbox_bin"

        # Cria link simbólico no PATH
        mkdir -p "$HOME/.local/bin"
        ln -sf "$toolbox_bin" "$HOME/.local/bin/jetbrains-toolbox"

        print_success "JetBrains Toolbox instalado em: $install_dir"
        print_success "Link simbólico criado: ~/.local/bin/jetbrains-toolbox"
    else
        print_error "Binário do JetBrains Toolbox não encontrado após extração."
        exit 1
    fi

    rm -f /tmp/jetbrains-toolbox.tar.gz
}

create_desktop_entry() {
    local desktop_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/jetbrains-toolbox.desktop"

    mkdir -p "$desktop_dir"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JetBrains Toolbox
Comment=Manage JetBrains tools and projects
Exec=$HOME/.local/bin/jetbrains-toolbox
Icon=$HOME/.local/share/JetBrains/Toolbox/toolbox.svg
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-toolbox
EOF

    chmod +x "$desktop_file"
    print_success "Atalho criado: $desktop_file"
}

verify_installation() {
    print_info "Verificando instalação..."

    if [[ -x "$HOME/.local/bin/jetbrains-toolbox" ]]; then
        print_success "✓ JetBrains Toolbox instalado"
    else
        print_error "✗ JetBrains Toolbox não encontrado"
        exit 1
    fi
}

show_completion_instructions() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA!${NC}"
    echo "=========================================="
    echo ""
    echo "✅ JetBrains Toolbox instalado"
    echo ""
    echo "PRÓXIMOS PASSOS:"
    echo "  1. Execute o JetBrains Toolbox:"
    echo "     jetbrains-toolbox"
    echo "     ou pelo menu de aplicativos"
    echo ""
    echo "  2. Dentro do Toolbox, clique em \"Install\" ao lado do Rider"
    echo ""
    echo "  3. (Opcional) Instale também outras IDEs:"
    echo "     - IntelliJ IDEA (Java/Kotlin)"
    echo "     - PyCharm (Python)"
    echo "     - WebStorm (JavaScript/TypeScript)"
    echo "     - DataGrip (Banco de dados)"
    echo ""
    echo "  4. Certifique-se de que ~/.local/bin está no seu PATH:"
    echo "     Adicione ao ~/.bashrc:"
    echo "     export PATH=\$PATH:\$HOME/.local/bin"
    echo ""
    echo "=========================================="
}

main() {
    echo "=========================================="
    echo "  Fedora - JetBrains Rider Installer"
    echo "  (via JetBrains Toolbox)"
    echo "=========================================="
    echo ""

    check_root
    check_fedora
    install_dependencies
    download_and_install_toolbox
    create_desktop_entry
    verify_installation
    show_completion_instructions
}

main

exit 0
