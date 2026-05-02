#!/bin/bash

# Script de instalação para Fedora 44
# Instala: GNOME Extensions App, GNOME Tweaks e Dash to Dock
# Autor: Assistente
# Data: $(date +%Y-%m-%d)

set -e  # Interrombe o script em caso de erro

# Cores para output no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens informativas
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Função para exibir mensagens de sucesso
print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

# Função para exibir mensagens de erro
print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para exibir mensagens de aviso
print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verifica se está rodando como root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Este script não deve ser executado como root."
        print_warning "Em vez disso, o script solicitará sudo quando necessário."
        print_warning "Por favor, execute como usuário normal."
        exit 1
    fi
}

# Verifica se é Fedora
check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Este script foi projetado apenas para Fedora Linux."
        print_error "Sistema detectado não é Fedora. Abortando instalação."
        exit 1
    fi
    
    local fedora_version=$(rpm -E %fedora)
    print_info "Sistema detectado: Fedora $fedora_version"
    
    if [[ $fedora_version -ne 44 ]]; then
        print_warning "Este script foi testado no Fedora 44."
        print_warning "Sua versão é Fedora $fedora_version. Pode funcionar, mas não é garantido."
        read -p "Deseja continuar? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

# Atualiza o sistema
update_system() {
    print_info "Atualizando o cache do DNF..."
    sudo dnf makecache --refresh
    print_success "Cache atualizado com sucesso"
}

# Instala os pacotes necessários
install_packages() {
    print_info "Instalando pacotes necessários..."
    
    local packages=(
        "gnome-extensions-app"  # GUI para gerenciar extensões GNOME [citation:2]
        "gnome-tweaks"          # Ferramenta de ajustes do GNOME [citation:10]
        "gnome-shell-extension-dash-to-dock"  # Extensão Dash to Dock [citation:4][citation:8]
    )
    
    print_info "Pacotes a serem instalados:"
    printf '%s\n' "${packages[@]}"
    echo
    
    sudo dnf install -y "${packages[@]}" 
    
    if [[ $? -eq 0 ]]; then
        print_success "Todos os pacotes foram instalados com sucesso"
    else
        print_error "Falha na instalação de alguns pacotes"
        exit 1
    fi
}

# Verifica se os pacotes foram instalados corretamente
verify_installation() {
    print_info "Verificando instalação..."
    
    local commands=(
        "gnome-extensions-app"
        "gnome-tweaks"
    )
    
    local success=true
    
    # Verifica execução dos comandos
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd está disponível"
        else
            print_warning "$cmd não encontrado no PATH"
            success=false
        fi
    done
    
    # Verifica extensão Dash to Dock
    if rpm -q gnome-shell-extension-dash-to-dock &> /dev/null; then
        print_success "Dash to Dock está instalado"
    else
        print_warning "Dash to Dock não confirmado"
        success=false
    fi
    
    if [[ "$success" == true ]]; then
        print_success "Verificação concluída: todos os componentes instalados"
    else
        print_warning "Verificação concluída com ressalvas"
    fi
}

# Exibe instruções para ativação das extensões
show_activation_instructions() {
    echo
    echo "=========================================="
    echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA!${NC}"
    echo "=========================================="
    echo
    echo "Para ativar o Dash to Dock:"
    echo "  1. Abra o aplicativo 'Extensions' (Extensões)"
    echo "  2. Localize 'Dash to Dock' na lista"
    echo "  3. Ative usando o botão deslizante"
    echo
    echo "Alternativamente, via linha de comando:"
    echo "  gnome-extensions enable dash-to-dock@micxgx.gmail.com"
    echo
    echo "Para gerenciar extensões e ajustes:"
    echo "  - Aplicativo 'Extensions': gerenciar todas as extensões [citation:1]"
    echo "  - Aplicativo 'Tweaks' (Ajustes): personalizar temas, fontes, etc."
    echo
    echo "=========================================="
}

# Função principal
main() {
    echo "=========================================="
    echo "  Fedora 44 - GNOME Extensions Installer"
    echo "=========================================="
    echo
    
    check_root
    check_fedora
    update_system
    install_packages
    verify_installation
    show_activation_instructions
}

# Executa o script
main

exit 0