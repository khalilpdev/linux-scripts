#!/bin/bash

# Script de correção do VirtualBox para Fedora 44
# Resolve o erro: Kernel driver not installed (rc=-1908)
# Autor: Assistente
# Data: $(date +%Y-%m-%d)

set -e  # Interrompe em caso de erro crítico, mas algumas verificações continuam

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funções de mensagem
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

print_step() {
    echo -e "${CYAN}▶${NC} ${MAGENTA}$1${NC}"
}

# Verifica se está rodando como root (não deve)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script NÃO deve ser executado como root."
        print_error "Execute como usuário normal. O script usará sudo quando necessário."
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

# Verifica se o VirtualBox está instalado
check_virtualbox_installed() {
    print_info "Verificando instalação do VirtualBox..."
    
    if ! rpm -q VirtualBox &> /dev/null && ! command -v VBoxManage &> /dev/null; then
        print_error "VirtualBox não está instalado!"
        print_info "Para instalar o VirtualBox no Fedora 44, execute:"
        echo "  sudo dnf install --skip-unavailable VirtualBox"
        exit 1
    fi
    
    print_success "VirtualBox encontrado"
}

# Verifica o kernel atual
check_kernel() {
    print_info "Kernel em execução: $(uname -r)"
    print_info "Arquitetura: $(uname -m)"
}

# Instala pacotes necessários
install_dependencies() {
    print_step "Instalando dependências necessárias..."
    
    local packages=(
        "akmod-VirtualBox"           # Kernel modules para VirtualBox
        "kernel-devel"               # Headers do kernel atual
        "kernel-headers"             # Headers do kernel
        "gcc"                        # Compilador GCC
        "make"                       # Make
        "dkms"                       # Dynamic Kernel Module Support (fallback)
        "virtualbox-guest-additions" # Opcional, mas útil
    )
    
    # Obtém a versão exata do kernel atual
    local kernel_version=$(uname -r)
    
    print_info "Instalando kernel-devel para: $kernel_version"
    sudo dnf install -y --skip-unavailable "kernel-devel-$kernel_version" "kernel-headers-$kernel_version"
    
    print_info "Instalando outros pacotes necessários..."
    sudo dnf install -y --skip-unavailable "${packages[@]}"
    
    print_success "Dependências instaladas"
}

# Recompila e carrega o módulo vboxdrv
recompile_modules() {
    print_step "Recompilando e carregando módulos do VirtualBox..."
    
    # Remove módulos antigos se existirem
    print_info "Removendo módulos antigos..."
    sudo modprobe -r vboxdrv vboxnetflt vboxnetadp 2>/dev/null || true
    
    # Executa akmods para compilar módulos para o kernel atual
    print_info "Executando akmods para compilar módulos..."
    sudo akmods --force
    
    # Verifica se o akmods encontrou o kernel-devel correto
    if [[ $? -ne 0 ]]; then
        print_warning "akmods encontrou problemas. Tentando abordagem alternativa..."
        
        # Abordagem alternativa: compilar manualmente via dkms
        if command -v dkms &> /dev/null; then
            print_info "Tentando via DKMS..."
            sudo dkms autoinstall
        fi
    fi
    
    # Recarrega o serviço vboxdrv
    print_info "Reiniciando serviço vboxdrv..."
    sudo systemctl restart vboxdrv.service 2>/dev/null || sudo systemctl restart vboxservice.service 2>/dev/null || true
    
    # Tenta carregar manualmente os módulos
    print_info "Carregando módulos..."
    sudo modprobe vboxdrv
    
    if [[ $? -eq 0 ]]; then
        print_success "Módulo vboxdrv carregado com sucesso"
    else
        print_error "Falha ao carregar vboxdrv"
        return 1
    fi
    
    # Carrega módulos adicionais
    sudo modprobe vboxnetflt 2>/dev/null || print_warning "vboxnetflt não carregado (opcional)"
    sudo modprobe vboxnetadp 2>/dev/null || print_warning "vboxnetadp não carregado (opcional)"
    
    return 0
}

# Verifica e configura Secure Boot
check_secure_boot() {
    print_step "Verificando Secure Boot..."
    
    # Verifica se Secure Boot está ativo
    if [[ -d /sys/firmware/efi ]] && [[ "$(mokutil --sb-state 2>/dev/null | grep -i 'SecureBoot enabled' | wc -l)" -gt 0 ]]; then
        print_warning "⚠️  SECURE BOOT ESTÁ ATIVO!"
        echo ""
        print_info "O Secure Boot impede o carregamento de módulos do kernel não assinados."
        echo ""
        echo "Opções para resolver:"
        echo "  1) ASSINAR OS MÓDULOS (recomendado) - Vou te ajudar com isso"
        echo "  2) Desabilitar Secure Boot na BIOS/UEFI"
        echo "  3) Usar MOK (Machine Owner Key) para assinar permanentemente"
        echo ""
        read -p "Deseja assinar os módulos automaticamente? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            sign_modules_for_secure_boot
        else
            print_warning "Você precisará desabilitar o Secure Boot na BIOS/UEFI para usar o VirtualBox."
            print_info "Para desabilitar: Reinicie → Acesse BIOS/UEFI → Secure Boot → Disabled"
            return 1
        fi
    else
        print_success "Secure Boot não está ativo ou não detectado"
    fi
    return 0
}

# Assina módulos para Secure Boot
sign_modules_for_secure_boot() {
    print_step "Preparando assinatura dos módulos para Secure Boot..."
    
    # Instala ferramentas necessárias
    sudo dnf install -y --skip-unavailable openssl mokutil
    
    # Cria diretório para chaves
    local key_dir="/root/vbox-signing"
    sudo mkdir -p "$key_dir"
    
    # Gera chave privada e certificado
    print_info "Gerando chave de assinatura..."
    sudo openssl req -new -x509 -newkey rsa:2048 -keyout "$key_dir/MOK.priv" \
        -outform DER -out "$key_dir/MOK.der" -nodes -days 36500 \
        -subj "/CN=VirtualBox Module Signing/"
    
    # Importa a chave no MOK (Machine Owner Key)
    print_info "Importando chave para o MOK..."
    print_warning "Uma janela do MokManager será aberta na próxima inicialização!"
    print_info "Siga estes passos:"
    echo "  1) Selecione 'Enroll MOK'"
    echo "  2) Selecione 'Continue'"
    echo "  3) Selecione 'Yes' para adicionar a chave"
    echo "  4) Digite a senha temporária (pressione Enter se não definiu)"
    echo ""
    read -p "Pressione ENTER para continuar e definir a senha..." -r
    
    sudo mokutil --import "$key_dir/MOK.der"
    
    # Assina os módulos
    print_info "Assinando módulos do VirtualBox..."
    local modules=("vboxdrv" "vboxnetflt" "vboxnetadp")
    
    for module in "${modules[@]}"; do
        local module_path=$(modinfo -n "$module" 2>/dev/null || find /lib/modules/$(uname -r) -name "${module}.ko.xz" 2>/dev/null | head -1)
        
        if [[ -n "$module_path" && -f "$module_path" ]]; then
            print_info "Assinando: $module_path"
            
            # Descomprime se for .xz
            if [[ "$module_path" == *.xz ]]; then
                sudo unxz "$module_path"
                module_path="${module_path%.xz}"
                sudo /usr/src/kernels/$(uname -r)/scripts/sign-file sha256 "$key_dir/MOK.priv" "$key_dir/MOK.der" "$module_path"
                sudo xz "$module_path"
            else
                sudo /usr/src/kernels/$(uname -r)/scripts/sign-file sha256 "$key_dir/MOK.priv" "$key_dir/MOK.der" "$module_path"
            fi
            print_success "✓ $module assinado"
        else
            print_warning "Módulo $module não encontrado para assinar"
        fi
    done
    
    print_warning "⚠️  REINICIAÇÃO NECESSÁRIA!"
    print_info "Após reiniciar, o MokManager será aberto para concluir o registro da chave."
    echo ""
    read -p "Deseja reiniciar agora? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_info "Reiniciando sistema..."
        sudo reboot
    else
        print_warning "Lembre-se de reiniciar manualmente depois!"
    fi
}

# Adiciona usuário ao grupo vboxusers
add_user_to_vbox_group() {
    print_step "Configurando permissões de usuário..."
    
    if groups "$USER" | grep -q "vboxusers"; then
        print_success "Usuário já está no grupo vboxusers"
    else
        print_info "Adicionando usuário $USER ao grupo vboxusers..."
        sudo usermod -aG vboxusers "$USER"
        print_success "Usuário adicionado ao grupo vboxusers"
        print_warning "Você precisará fazer LOGOUT e LOGIN novamente para que as permissões tenham efeito!"
    fi
}

# Verifica se os módulos foram carregados corretamente
verify_modules() {
    print_step "Verificando módulos carregados..."
    
    if lsmod | grep -q "vboxdrv"; then
        print_success "✓ vboxdrv: CARREGADO"
        print_info "  $(lsmod | grep vboxdrv)"
    else
        print_error "✗ vboxdrv: NÃO CARREGADO"
    fi
    
    if lsmod | grep -q "vboxnetflt"; then
        print_success "✓ vboxnetflt: CARREGADO"
    else
        print_warning "✗ vboxnetflt: NÃO CARREGADO (não crítico)"
    fi
    
    if lsmod | grep -q "vboxnetadp"; then
        print_success "✓ vboxnetadp: CARREGADO"
    else
        print_warning "✗ vboxnetadp: NÃO CARREGADO (não crítico)"
    fi
}

# Tenta carregar módulos e verificar novamente
emergency_fix() {
    print_step "Tentando correção de emergência..."
    
    # Tenta instalar kernel-devel específico novamente
    local kernel_version=$(uname -r)
    print_info "Tentando reinstalar kernel-devel para $kernel_version"
    sudo dnf reinstall -y --skip-unavailable "kernel-devel-$kernel_version" "kernel-headers-$kernel_version"
    
    # Tenta compilar manualmente
    print_info "Tentando compilar módulos manualmente..."
    cd /tmp
    if [[ -d /usr/share/VBox/src ]]; then
        sudo /usr/share/VBox/src/vboxhost/build_in_tmp --force
    fi
    
    # Reinicia serviços
    sudo systemctl restart vboxdrv.service 2>/dev/null || true
    
    # Tenta carregar novamente
    sudo modprobe vboxdrv
}

# Função principal
main() {
    echo ""
    echo "=========================================="
    echo "  Correção do VirtualBox para Fedora 44"
    echo "  Erro: Kernel driver not installed (rc=-1908)"
    echo "=========================================="
    echo ""
    
    check_root
    check_fedora
    check_virtualbox_installed
    check_kernel
    install_dependencies
    add_user_to_vbox_group
    check_secure_boot
    
    # Tenta recompilar e carregar módulos
    if recompile_modules; then
        verify_modules
    else
        print_warning "Falha na recompilação normal. Tentando correção de emergência..."
        emergency_fix
        verify_modules
    fi
    
    # Resultado final
    echo ""
    echo "=========================================="
    if lsmod | grep -q "vboxdrv"; then
        echo -e "${GREEN}✅ PROBLEMA RESOLVIDO COM SUCESSO!${NC}"
        echo "=========================================="
        echo ""
        echo "O VirtualBox deve funcionar normalmente agora."
        echo "Se ainda houver problemas:"
        echo "  1) Reinicie o sistema: sudo reboot"
        echo "  2) Verifique se você fez logout/login após ser adicionado ao grupo vboxusers"
        echo "  3) Execute 'vboxmanage --version' para testar"
    else
        echo -e "${RED}❌ O PROBLEMA PERSISTE${NC}"
        echo "=========================================="
        echo ""
        echo "Tente estas soluções adicionais:"
        echo ""
        echo "1. Reinicie o sistema e execute este script novamente:"
        echo "   sudo reboot"
        echo "   ./$(basename "$0")"
        echo ""
        echo "2. Se o Secure Boot estiver ativo, desabilite na BIOS/UEFI"
        echo ""
        echo "3. Reinstale completamente o VirtualBox:"
        echo "   sudo dnf remove --skip-unavailable VirtualBox akmod-VirtualBox"
        echo "   sudo dnf install --skip-unavailable VirtualBox akmod-VirtualBox"
        echo ""
        echo "4. Verifique os logs:"
        echo "   sudo dmesg | grep -i vbox"
        echo "   sudo journalctl -xe | grep -i vbox"
    fi
    
    echo ""
    print_info "Para testar o VirtualBox, execute:"
    echo "  virtualbox"
    echo ""
}

# Executa o script
main

exit 0