#!/bin/bash

# Script de instalação para Fedora 44
# Instala: Visual Studio Code (repositório Microsoft) + Extensões C# Dev Kit e Material Icon
# Instala: .NET 10 SDK via DNF (disponível nos repositórios oficiais do Fedora 44)
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
        print_warning "Sua versão é Fedora $fedora_version."
        read -p "Deseja continuar? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

# Adiciona o repositório do Visual Studio Code da Microsoft
add_vscode_repo() {
    print_info "Adicionando repositório oficial do Visual Studio Code (Microsoft)..."
    
    # Importa a chave GPG da Microsoft
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    
    # Cria o arquivo do repositório
    sudo tee /etc/yum.repos.d/vscode.repo > /dev/null <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    
    print_success "Repositório do VS Code adicionado com sucesso"
}

# Instala o Visual Studio Code
install_vscode() {
    print_info "Instalando Visual Studio Code..."
    
    # Atualiza o cache do DNF
    sudo dnf check-update
    
    # Instala o VS Code
    sudo dnf install -y code --skip-unavailable
    
    if command -v code &> /dev/null; then
        print_success "Visual Studio Code instalado com sucesso"
    else
        print_error "Falha na instalação do VS Code"
        exit 1
    fi
}

# Instala o .NET 10 SDK diretamente do repositório do Fedora 44
install_dotnet10() {
    print_info "Instalando .NET 10 SDK e Runtime..."
    print_info "O .NET 10 está disponível nos repositórios oficiais do Fedora 44 [citation:3][citation:7]"
    
    # Instala o pacote dotnet10.0 (inclui SDK e Runtime)
    sudo dnf install -y dotnet10.0 --skip-unavailable
    
    # Verifica a instalação
    if command -v dotnet &> /dev/null; then
        local dotnet_version=$(dotnet --version 2>/dev/null || echo "versão desconhecida")
        print_success ".NET SDK instalado: $dotnet_version"
    else
        print_warning ".NET SDK pode não estar no PATH. Tentando corrigir..."
        # Recarrega o perfil do usuário
        source ~/.bashrc 2>/dev/null || true
    fi
}

# Instala extensões do VS Code via linha de comando
install_vscode_extensions() {
    print_info "Instalando extensões do Visual Studio Code..."
    
    # Aguarda o VS Code inicializar completamente
    print_info "Aguardando inicialização do VS Code..."
    sleep 3
    
    # Extensões a serem instaladas:
    # 1. C# Dev Kit - Extensão oficial da Microsoft para desenvolvimento C# [citation:2][citation:10]
    #    Nota: Esta extensão automaticamente instala também:
    #    - .NET Install Tool (gerenciador de versões do .NET)
    #    - C# (suporte base à linguagem)
    # 2. Material Icon Theme - Ícones Material Design para arquivos e pastas [citation:4][citation:8]
    
    local extensions=(
        "ms-dotnettools.csdevkit"      # C# Dev Kit
        "pkief.material-icon-theme"    # Material Icon Theme
    )
    
    for ext in "${extensions[@]}"; do
        print_info "Instalando: $ext"
        if code --install-extension "$ext" --force; then
            print_success "Instalado: $ext"
        else
            print_warning "Falha ao instalar: $ext - tente instalar manualmente pelo marketplace"
        fi
    done
}

# Configura o Material Icon Theme como tema de ícones padrão
configure_material_icon_theme() {
    print_info "Configurando Material Icon Theme como tema de ícones padrão..."
    
    local settings_dir="$HOME/.config/Code/User"
    local settings_file="$settings_dir/settings.json"
    
    mkdir -p "$settings_dir"
    
    # Verifica se o arquivo settings.json existe
    if [[ -f "$settings_file" ]]; then
        # Faz backup do arquivo original
        cp "$settings_file" "$settings_file.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Atualiza ou adiciona a configuração do tema de ícones usando jq (se disponível)
        if command -v jq &> /dev/null; then
            # Com jq: manipulação segura de JSON
            if grep -q "workbench.iconTheme" "$settings_file"; then
                jq '.["workbench.iconTheme"] = "material-icon-theme"' "$settings_file" > "$settings_file.tmp"
            else
                jq '. + {"workbench.iconTheme": "material-icon-theme"}' "$settings_file" > "$settings_file.tmp"
            fi
            mv "$settings_file.tmp" "$settings_file"
        else
            # Fallback: usando sed (menos seguro, mas funcional)
            if grep -q '"workbench.iconTheme"' "$settings_file"; then
                sed -i 's/"workbench.iconTheme":.*/"workbench.iconTheme": "material-icon-theme",/' "$settings_file"
            else
                # Remove a última chave para adicionar nova
                sed -i '$ s/,$//' "$settings_file"
                sed -i '$ a\  "workbench.iconTheme": "material-icon-theme"\n}' "$settings_file"
            fi
        fi
        print_success "Configuração do Material Icon Theme aplicada no settings.json"
    else
        # Cria novo arquivo settings.json
        cat > "$settings_file" <<EOF
{
    "workbench.iconTheme": "material-icon-theme"
}
EOF
        print_success "Arquivo settings.json criado com o Material Icon Theme configurado"
    fi
}

# Verifica todas as instalações
verify_installation() {
    print_info "Verificando instalações..."
    echo ""
    
    # Verifica VS Code
    if command -v code &> /dev/null; then
        local vscode_version=$(code --version | head -1)
        print_success "✓ Visual Studio Code: $vscode_version"
    else
        print_error "✗ Visual Studio Code: não encontrado"
    fi
    
    # Verifica .NET
    if command -v dotnet &> /dev/null; then
        local dotnet_version=$(dotnet --version 2>/dev/null || echo "versão instalada")
        print_success "✓ .NET SDK: $dotnet_version"
    else
        print_warning "✗ .NET SDK: não encontrado no PATH"
        print_info "Tente reiniciar o terminal ou executar: source ~/.bashrc"
    fi
    
    # Verifica extensões instaladas
    if command -v code &> /dev/null; then
        echo ""
        print_info "Extensões instaladas no VS Code:"
        code --list-extensions | while read -r ext; do
            echo "  - $ext"
        done
    fi
}

# Exibe instruções finais
show_completion_instructions() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA!${NC}"
    echo "=========================================="
    echo ""
    echo "✅ Visual Studio Code instalado"
    echo "✅ .NET 10 SDK e Runtime instalados [citation:3][citation:7]"
    echo "✅ C# Dev Kit instalada (inclui suporte C# e .NET Install Tool) [citation:2][citation:10]"
    echo "✅ Material Icon Theme instalado e configurado [citation:4][citation:8]"
    echo ""
    echo "Para iniciar o VS Code:"
    echo "  code ."
    echo ""
    echo "Para abrir uma pasta específica:"
    echo "  code /caminho/da/sua/pasta"
    echo ""
    echo "PRÓXIMOS PASSOS:"
    echo "  1. Reinicie o VS Code se ele já estava aberto"
    echo "  2. O C# Dev Kit pode solicitar login (opcional - pode ignorar)"
    echo "  3. Para criar um novo projeto .NET:"
    echo "     dotnet new console -n MeuProjeto"
    echo "     cd MeuProjeto"
    echo "     code ."
    echo ""
    echo "Para verificar as extensões ativas no VS Code:"
    echo "  Ctrl+Shift+P → Extensions: Show Installed Extensions"
    echo ""
    echo "=========================================="
}

# Função principal
main() {
    echo "=========================================="
    echo "  Fedora 44 - VS Code + .NET 10 Installer"
    echo "=========================================="
    echo ""
    
    check_root
    check_fedora
    add_vscode_repo
    install_vscode
    install_dotnet10
    install_vscode_extensions
    configure_material_icon_theme
    verify_installation
    show_completion_instructions
}

# Executa o script
main

exit 0