#!/bin/bash

# Script de instalação do .NET 10 no Fedora
# Baseado na documentação oficial da Microsoft:
# https://learn.microsoft.com/pt-br/dotnet/core/install/linux-fedora?tabs=dotnet10
# Autor: Assistente
# Data: $(date +%Y-%m-%d)

set -e  # Interrompe o script em caso de erro

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

# Verifica se está rodando como root (não deve)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script NÃO deve ser executado como root."
        print_error "Execute como um usuário normal com privilégios sudo."
        exit 1
    fi
}

# Verifica se é Fedora
check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Este script foi projetado apenas para Fedora Linux."
        exit 1
    fi
    
    local fedora_version=$(rpm -E %fedora)
    print_info "Sistema detectado: Fedora $fedora_version"
    
    # De acordo com a documentação, Fedora 42 e 43 são suportados para .NET 10
    if [[ $fedora_version -lt 42 ]]; then
        print_warning "Fedora $fedora_version pode não ser oficialmente suportado pelo .NET 10."
        print_warning "Versões suportadas: Fedora 42, 43 e superiores."
        read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

# Instala as dependências necessárias
install_dependencies() {
    print_info "Instalando dependências do .NET..."
    
    # Lista de dependências conforme documentação oficial
    local dependencies=(
        "glibc"
        "libgcc"
        "ca-certificates"
        "openssl-libs"
        "libstdc++"
        "libicu"
        "tzdata"
        "krb5-libs"
        "zlib"        # Necessário para .NET 8+, incluindo 10
    )
    
    sudo dnf install -y "${dependencies[@]}"
    
    if [[ $? -eq 0 ]]; then
        print_success "Dependências instaladas com sucesso"
    else
        print_error "Falha ao instalar dependências"
        exit 1
    fi
}

# Atualiza o cache do DNF
update_cache() {
    print_info "Atualizando cache do DNF..."
    sudo dnf makecache --refresh
    print_success "Cache atualizado"
}

# Instala o SDK do .NET 10 (recomendado para desenvolvimento)
install_dotnet_sdk() {
    print_info "Instalando .NET 10 SDK..."
    print_info "Isso inclui o runtime e a CLI para desenvolvimento."
    
    sudo dnf install -y dotnet-sdk-10.0
    
    if [[ $? -eq 0 ]]; then
        print_success ".NET 10 SDK instalado com sucesso"
    else
        print_error "Falha ao instalar o .NET 10 SDK"
        exit 1
    fi
}

# Instala apenas o runtime do ASP.NET Core (para executar aplicações)
install_aspnetcore_runtime() {
    print_info "Instalando ASP.NET Core Runtime 10.0..."
    print_info "Isso inclui os runtimes .NET e ASP.NET Core."
    
    sudo dnf install -y aspnetcore-runtime-10.0
    
    if [[ $? -eq 0 ]]; then
        print_success "ASP.NET Core Runtime 10.0 instalado com sucesso"
    else
        print_error "Falha ao instalar o ASP.NET Core Runtime"
        exit 1
    fi
}

# Instala apenas o runtime do .NET (sem suporte a ASP.NET Core)
install_dotnet_runtime() {
    print_info "Instalando .NET Runtime 10.0..."
    
    sudo dnf install -y dotnet-runtime-10.0
    
    if [[ $? -eq 0 ]]; then
        print_success ".NET Runtime 10.0 instalado com sucesso"
    else
        print_error "Falha ao instalar o .NET Runtime"
        exit 1
    fi
}

# Verifica a instalação
verify_installation() {
    print_info "Verificando instalação do .NET..."
    
    if command -v dotnet &> /dev/null; then
        local dotnet_version=$(dotnet --version 2>/dev/null)
        local dotnet_sdks=$(dotnet --list-sdks 2>/dev/null | wc -l)
        local dotnet_runtimes=$(dotnet --list-runtimes 2>/dev/null | wc -l)
        
        print_success "✅ .NET CLI disponível: versão $dotnet_version"
        echo -e "${GREEN}   SDKs instalados:${NC} $dotnet_sdks"
        echo -e "${GREEN}   Runtimes instalados:${NC} $dotnet_runtimes"
        
        # Mostra detalhes
        echo ""
        print_info "Detalhes dos SDKs instalados:"
        dotnet --list-sdks
        echo ""
        print_info "Detalhes dos Runtimes instalados:"
        dotnet --list-runtimes
    else
        print_error "❌ .NET CLI não encontrada no PATH"
        print_warning "Tente reiniciar o terminal ou executar: source ~/.bashrc"
        exit 1
    fi
}

# Menu de seleção do tipo de instalação
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Instalação do .NET 10 no Fedora"
    echo "=========================================="
    echo ""
    echo "Escolha o tipo de instalação:"
    echo "  1) SDK Completo (recomendado para desenvolvimento)"
    echo "  2) Apenas ASP.NET Core Runtime (para executar aplicações web)"
    echo "  3) Apenas .NET Runtime (para executar aplicações console)"
    echo "  4) Sair"
    echo ""
    read -p "Digite sua escolha [1-4]: " choice
    
    case $choice in
        1)
            echo ""
            install_dotnet_sdk
            ;;
        2)
            echo ""
            install_aspnetcore_runtime
            ;;
        3)
            echo ""
            install_dotnet_runtime
            ;;
        4)
            print_info "Instalação cancelada pelo usuário."
            exit 0
            ;;
        *)
            print_error "Opção inválida. Por favor, execute o script novamente."
            exit 1
            ;;
    esac
}

# Exibe instruções pós-instalação
show_post_instructions() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
    echo "=========================================="
    echo ""
    echo "Comandos úteis para gerenciar sua instalação .NET:"
    echo ""
    echo "  ${YELLOW}dotnet --info${NC}               - Mostra informações detalhadas"
    echo "  ${YELLOW}dotnet --list-sdks${NC}          - Lista SDKs instalados"
    echo "  ${YELLOW}dotnet --list-runtimes${NC}      - Lista runtimes instalados"
    echo "  ${YELLOW}dotnet new console${NC}          - Cria um novo projeto console"
    echo "  ${YELLOW}dotnet run${NC}                  - Executa o projeto atual"
    echo ""
    echo "Para criar seu primeiro aplicativo:"
    echo "  ${YELLOW}mkdir MeuApp && cd MeuApp${NC}"
    echo "  ${YELLOW}dotnet new console${NC}"
    echo "  ${YELLOW}dotnet run${NC}"
    echo ""
    echo "Documentação oficial:"
    echo "  https://learn.microsoft.com/pt-br/dotnet/core/install/linux-fedora"
    echo ""
    echo "=========================================="
}

# Função principal
main() {
    echo "=========================================="
    echo "  Fedora - .NET 10 Installer"
    echo "  Baseado na documentação oficial da Microsoft"
    echo "=========================================="
    
    check_root
    check_fedora
    update_cache
    install_dependencies
    show_menu
    verify_installation
    show_post_instructions
}

# Executa o script
main

exit 0