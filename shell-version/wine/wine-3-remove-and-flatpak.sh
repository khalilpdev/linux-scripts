#!/bin/bash
# =============================================================================
# Script: wine-3-remove-and-flatpak.sh
# Descrição: Remove Wine instalado via DNF/WineHQ, apaga ~/.wine e instala
#            a última versão via Flatpak com comando 'wine' exportado
# Autor: Leandro Khalil
# Data: $(date +%Y-%m-%d)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Este script não deve rodar como root. Execute como usuário normal."
        exit 1
    fi
}

detect_fedora_version() {
    if [ -f /etc/fedora-release ]; then
        FEDORA_VERSION=$(rpm -E %fedora)
        log_info "Fedora versão $FEDORA_VERSION detectada"
    else
        log_error "Sistema não parece ser Fedora. Abortando."
        exit 1
    fi
}

remove_wine_installed() {
    log_info "Removendo Wine instalado via DNF/WineHQ..."

    if command -v wine &> /dev/null; then
        CURRENT_WINE=$(wine --version 2>/dev/null | head -1)
        log_info "Wine atual detectado: $CURRENT_WINE"
    fi

    sudo dnf remove -y 'wine*' 'winehq*' 2>/dev/null || true

    if [ -f /etc/yum.repos.d/winehq.repo ]; then
        log_info "Removendo repositório WineHQ..."
        sudo rm -f /etc/yum.repos.d/winehq.repo
    fi

    log_success "Wine removido via DNF/WineHQ"
}

remove_wine_prefix() {
    if [ -d "$HOME/.wine" ]; then
        log_warning "Pasta ~/.wine encontrada."
        read -p "Deseja remover a pasta ~/.wine? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            rm -rf "$HOME/.wine"
            log_success "Pasta ~/.wine removida"
        else
            log_info "Remoção de ~/.wine ignorada"
        fi
    else
        log_info "Nenhuma pasta ~/.wine encontrada"
    fi
}

remove_wine_flatpak_old() {
    if flatpak list | grep -q org.winehq.Wine; then
        log_info "Removendo instalação antiga do Wine Flatpak..."
        flatpak uninstall -y org.winehq.Wine 2>/dev/null || true
        log_success "Wine Flatpak antigo removido"
    fi
}

install_flatpak_and_wine() {
    log_info "Instalando Wine via Flatpak..."

    if ! command -v flatpak &> /dev/null; then
        log_info "Instalando flatpak..."
        sudo dnf install -y flatpak
    fi

    if ! flatpak remotes | grep -q flathub; then
        log_info "Adicionando repositório Flathub..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    flatpak install -y flathub org.winehq.Wine

    log_success "Wine instalado via Flatpak: $(flatpak run org.winehq.Wine --version 2>/dev/null | head -1)"
}

export_wine_command() {
    local SHELL_RC=""
    local ALIAS_LINE="alias wine='flatpak run org.winehq.Wine'"

    if [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi

    if [ -n "$SHELL_RC" ]; then
        if grep -q "alias wine=" "$SHELL_RC" 2>/dev/null; then
            log_info "Alias 'wine' já existe em $SHELL_RC"
        else
            echo "" >> "$SHELL_RC"
            echo "# Wine Flatpak (adicionado por wine-3 script)" >> "$SHELL_RC"
            echo "$ALIAS_LINE" >> "$SHELL_RC"
            log_success "Alias 'wine' adicionado ao $SHELL_RC"
        fi
    fi

    log_info "Para usar imediatamente nesta sessão, execute:"
    echo "  source $SHELL_RC"
    echo ""
    log_info "Ou use diretamente:"
    echo "  flatpak run org.winehq.Wine seu_programa.exe"
}

main() {
    echo "==========================================================================="
    echo "        Remover Wine DNF/WineHQ e Instalar via Flatpak                    "
    echo "==========================================================================="
    echo ""

    check_root
    detect_fedora_version

    echo ""
    log_warning "Este script irá:"
    echo "  1. Remover Wine instalado via DNF ou WineHQ"
    echo "  2. Perguntar se deve apagar ~/.wine"
    echo "  3. Remover Wine Flatpak antigo (se existir)"
    echo "  4. Instalar Wine via Flatpak (última versão)"
    echo "  5. Exportar comando 'wine' via alias"
    echo ""

    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Script abortado pelo usuário."
        exit 0
    fi

    remove_wine_installed
    remove_wine_prefix
    remove_wine_flatpak_old
    install_flatpak_and_wine
    export_wine_command

    echo ""
    log_success "Script finalizado!"
    log_info "Teste com: wine --version"
}

main "$@"
