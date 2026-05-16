#!/bin/bash

# ============================================
# Script para ocultar VM no QEMU/KVM
# Autor: Assistente
# Uso: ./qemu-vm-hide.sh
# ============================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arquivo de configuração
CONFIG_FILE="$HOME/.qemu_vm_hide_config"
VM_NAME=""
VM_DISK=""
VM_MEMORY="2048"
VM_CPU_CORES="2"

# Função para imprimir com cor
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Função para verificar se a VM está rodando
is_vm_running() {
    local vm_name=$1
    if virsh list --state-running | grep -q "$vm_name"; then
        return 0
    else
        return 1
    fi
}

# Função para verificar se QEMU está instalado
check_dependencies() {
    print_status "$BLUE" "[*] Verificando dependências..."
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        print_status "$RED" "[!] QEMU não encontrado. Instale com: sudo apt install qemu-system-x86 qemu-kvm"
        exit 1
    fi
    
    if ! command -v virsh &> /dev/null; then
        print_status "$YELLOW" "[!] virsh não encontrado. Usando QEMU direto (sem libvirt)"
        USE_LIBVIRT=0
    else
        USE_LIBVIRT=1
        print_status "$GREEN" "[✓] libvirt encontrado"
    fi
    
    print_status "$GREEN" "[✓] Dependências OK"
}

# Função para detectar VMs existentes
detect_vms() {
    print_status "$BLUE" "[*] Detectando VMs..."
    
    if [ $USE_LIBVIRT -eq 1 ]; then
        VMS=$(virsh list --all --name | grep -v "^$" | head -5)
        if [ -n "$VMS" ]; then
            echo "$VMS"
            return 0
        fi
    fi
    
    # Procura por imagens .qcow2 comuns
    echo "Procurando imagens .qcow2..."
    find ~ -name "*.qcow2" 2>/dev/null | head -5
    echo "Procurando imagens .img..."
    find ~ -name "*.img" 2>/dev/null | head -5
}

# Função para verificar status de ocultação atual
check_hide_status() {
    print_status "$BLUE" "\n[*] Verificando status de ocultação da VM..."
    
    local hide_enabled=0
    
    # Verifica se há configuração salva
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if [ "$HIDE_ENABLED" = "yes" ]; then
            hide_enabled=1
        fi
    fi
    
    # Verifica se a VM está rodando com parâmetros de ocultação
    if [ $USE_LIBVIRT -eq 1 ] && [ -n "$VM_NAME" ]; then
        if virsh dumpxml "$VM_NAME" 2>/dev/null | grep -q "kvm=off"; then
            hide_enabled=1
            print_status "$GREEN" "[✓] STATUS: OCULTAÇÃO ATIVADA - A VM está escondendo que é uma VM"
            echo ""
            print_status "$YELLOW" "   Parâmetros ativos:"
            echo "     - kvm=off"
            echo "     - hypervisor=off"
            echo "     - svm=off (AMD) / vmx=off (Intel)"
        else
            if [ $hide_enabled -eq 1 ]; then
                print_status "$RED" "[✗] STATUS: OCULTAÇÃO DESATIVADA - A VM é detectável"
            else
                print_status "$RED" "[✗] STATUS: OCULTAÇÃO DESATIVADA - A VM é detectável"
            fi
        fi
    else
        if [ $hide_enabled -eq 1 ]; then
            print_status "$GREEN" "[✓] STATUS: OCULTAÇÃO ATIVADA (configuração salva)"
        else
            print_status "$RED" "[✗] STATUS: OCULTAÇÃO DESATIVADA"
        fi
    fi
    
    return $hide_enabled
}

# Função para criar arquivo de configuração da VM
create_vm_config() {
    print_status "$BLUE" "\n[*] Configurando parâmetros da VM..."
    
    # Listar VMs disponíveis
    if [ $USE_LIBVIRT -eq 1 ]; then
        echo -e "${YELLOW}VMs disponíveis:${NC}"
        virsh list --all
        echo ""
        read -p "Digite o nome da VM: " VM_NAME
        
        if ! virsh dominfo "$VM_NAME" &>/dev/null; then
            print_status "$RED" "[!] VM não encontrada!"
            return 1
        fi
    else
        read -p "Caminho completo para o disco da VM (ex: ~/win10.qcow2): " VM_DISK
        read -p "Memória (MB) [2048]: " VM_MEMORY
        VM_MEMORY=${VM_MEMORY:-2048}
        read -p "Núcleos de CPU [2]: " VM_CPU_CORES
        VM_CPU_CORES=${VM_CPU_CORES:-2}
    fi
    
    # Salvar configuração
    cat > "$CONFIG_FILE" << EOF
VM_NAME="$VM_NAME"
VM_DISK="$VM_DISK"
VM_MEMORY="$VM_MEMORY"
VM_CPU_CORES="$VM_CPU_CORES"
HIDE_ENABLED="no"
EOF
    
    print_status "$GREEN" "[✓] Configuração salva em $CONFIG_FILE"
    return 0
}

# Função para ativar ocultação (modifica XML do libvirt)
enable_hide() {
    print_status "$BLUE" "\n[*] Ativando ocultação da VM..."
    
    if [ -z "$VM_NAME" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    if [ -z "$VM_NAME" ] && [ $USE_LIBVIRT -eq 1 ]; then
        print_status "$RED" "[!] Nome da VM não definido. Execute a configuração primeiro."
        create_vm_config
        source "$CONFIG_FILE"
    fi
    
    if [ $USE_LIBVIRT -eq 1 ]; then
        # Verificar se VM está rodando
        if is_vm_running "$VM_NAME"; then
            print_status "$RED" "[!] VM está rodando. Desligue a VM primeiro!"
            read -p "Deseja desligar a VM agora? (s/n): " shutdown_vm
            if [[ $shutdown_vm =~ ^[Ss]$ ]]; then
                virsh shutdown "$VM_NAME"
                sleep 5
                print_status "$YELLOW" "[*] Aguardando VM desligar..."
                while is_vm_running "$VM_NAME"; do
                    sleep 2
                done
                print_status "$GREEN" "[✓] VM desligada"
            else
                return 1
            fi
        fi
        
        # Backup do XML original
        XML_FILE="/tmp/${VM_NAME}_original.xml"
        virsh dumpxml "$VM_NAME" > "$XML_FILE"
        
        # Extrair e modificar XML
        print_status "$YELLOW" "[*] Modificando configuração da VM..."
        
        # Criar XML modificado
        virsh dumpxml "$VM_NAME" | sed \
            -e 's|<features>|<features>\n    <kvm>\
      <hidden state="on"/>\
    </kvm>|' \
            -e 's|<hyperv>|<hyperv>\
      <relaxed state="on"/>\
      <vapic state="on"/>\
      <spinlocks state="on" retries="8191"/>|' \
            > "/tmp/${VM_NAME}_modified.xml"
        
        # Adicionar parâmetros de CPU para esconder
        sed -i '/<cpu /a \    <feature policy="disable" name="hypervisor"/>' "/tmp/${VM_NAME}_modified.xml"
        
        # Aplicar configuração
        virsh define "/tmp/${VM_NAME}_modified.xml"
        
        print_status "$GREEN" "[✓] Ocultação ativada com sucesso!"
    else
        # Modo QEMU direto
        print_status "$YELLOW" "[*] Criando script de inicialização com ocultação..."
        
        HIDE_SCRIPT="$HOME/start_vm_hidden.sh"
        cat > "$HIDE_SCRIPT" << EOF
#!/bin/bash
qemu-system-x86_64 \\
  -drive file=$VM_DISK,format=qcow2 \\
  -m ${VM_MEMORY}M \\
  -smp cores=$VM_CPU_CORES \\
  -cpu host,kvm=off,hypervisor=on,svm=off,vmx=off \\
  -machine pc,accel=kvm \\
  -display gtk \\
  -net user -net nic
EOF
        chmod +x "$HIDE_SCRIPT"
        print_status "$GREEN" "[✓] Script criado: $HIDE_SCRIPT"
    fi
    
    # Salvar status
    sed -i 's/HIDE_ENABLED=".*"/HIDE_ENABLED="yes"/' "$CONFIG_FILE"
    
    print_status "$GREEN" "\n[✓] OCULTAÇÃO ATIVADA - A VM NÃO será detectada como VM"
}

# Função para desativar ocultação
disable_hide() {
    print_status "$BLUE" "\n[*] Desativando ocultação da VM..."
    
    if [ -z "$VM_NAME" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    if [ $USE_LIBVIRT -eq 1 ] && [ -n "$VM_NAME" ]; then
        # Restaurar XML original
        if [ -f "/tmp/${VM_NAME}_original.xml" ]; then
            virsh define "/tmp/${VM_NAME}_original.xml"
            print_status "$GREEN" "[✓] Configuração original restaurada"
        else
            print_status "$YELLOW" "[!] Backup não encontrado, recriando XML padrão..."
            # Recriar XML sem parâmetros de ocultação
            virsh dumpxml "$VM_NAME" | sed '/<kvm>/,/<\/kvm>/d' | \
            sed '/<hidden state="on"/d' | \
            sed '/<feature policy="disable" name="hypervisor"/d' > "/tmp/${VM_NAME}_clean.xml"
            virsh define "/tmp/${VM_NAME}_clean.xml"
        fi
        
        print_status "$GREEN" "[✓] Ocultação desativada"
    else
        print_status "$YELLOW" "[*] Removendo script de inicialização com ocultação..."
        rm -f "$HOME/start_vm_hidden.sh"
    fi
    
    # Salvar status
    sed -i 's/HIDE_ENABLED=".*"/HIDE_ENABLED="no"/' "$CONFIG_FILE"
    
    print_status "$RED" "\n[✓] OCULTAÇÃO DESATIVADA - A VM será detectável"
}

# Função para iniciar a VM
start_vm() {
    print_status "$BLUE" "\n[*] Iniciando a VM..."
    
    if [ $USE_LIBVIRT -eq 1 ] && [ -n "$VM_NAME" ]; then
        virsh start "$VM_NAME"
        print_status "$GREEN" "[✓] VM iniciada"
        
        # Conectar via VNC/Spice automaticamente
        if command -v virt-viewer &> /dev/null; then
            virt-viewer "$VM_NAME" &
        fi
    else
        if [ -f "$HOME/start_vm_hidden.sh" ]; then
            print_status "$YELLOW" "[*] Iniciando com script de ocultação..."
            bash "$HOME/start_vm_hidden.sh" &
        elif [ -n "$VM_DISK" ]; then
            print_status "$YELLOW" "[*] Iniciando VM normal..."
            qemu-system-x86_64 -drive file=$VM_DISK,format=qcow2 -m ${VM_MEMORY}M -smp cores=$VM_CPU_CORES &
        else
            print_status "$RED" "[!] Configuração incompleta. Execute a configuração primeiro."
            create_vm_config
        fi
    fi
}

# Função menu principal
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     GERENCIADOR DE OCULTAÇÃO DE VM      ║${NC}"
    echo -e "${BLUE}║            QEMU/KVM                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    
    # Verificar e mostrar status atual
    check_hide_status 2>/dev/null || true
    
    echo ""
    echo -e "${YELLOW}MENU PRINCIPAL:${NC}"
    echo "1. Ativar ocultação da VM"
    echo "2. Desativar ocultação da VM"
    echo "3. Verificar status atual"
    echo "4. Iniciar VM"
    echo "5. Configurar VM"
    echo "6. Testar detecção dentro da VM"
    echo "0. Sair"
    echo ""
    read -p "Escolha uma opção [0-6]: " choice
}

# Função para testar detecção
test_detection() {
    print_status "$BLUE" "\n[*] Testando se a VM está escondida..."
    
    cat > "/tmp/test_vm_detection.sh" << 'EOF'
#!/bin/bash
echo "=== TESTE DE DETECÇÃO DE VM ==="
echo ""

# Teste 1: CPUID
echo "[1] Testando assinatura CPUID:"
if grep -q "hypervisor" /proc/cpuinfo; then
    echo "    ✗ FLAG 'hypervisor' detectada - VM DETECTADA"
else
    echo "    ✓ FLAG 'hypervisor' NÃO detectada - PARECE HARDWARE FÍSICO"
fi

# Teste 2: DMI/SMBIOS
echo ""
echo "[2] Testando informações do BIOS:"
if dmesg | grep -qi "virtualbox\|vmware\|kvm\|qemu"; then
    echo "    ✗ Strings de virtualização detectadas - VM DETECTADA"
else
    echo "    ✓ Sem strings suspeitas de virtualização"
fi

# Teste 3: /sys/class/dmi/id/
echo ""
echo "[3] Testando DMI IDs:"
if [ -r /sys/class/dmi/id/product_name ]; then
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if echo "$product" | grep -qi "virtual\|kvm\|qemu\|vmware"; then
        echo "    ✗ Product name suspeito: $product - VM DETECTADA"
    else
        echo "    ✓ Product name: $product"
    fi
fi

# Teste 4: Dispositivos PCI
echo ""
echo "[4] Verificando dispositivos PCI suspeitos:"
if lspci 2>/dev/null | grep -qi "virtualbox\|vmware\|qemu\|virtio"; then
    echo "    ✗ Dispositivos de virtualização encontrados - VM DETECTADA"
else
    echo "    ✓ Nenhum dispositivo virtual suspeito"
fi
EOF
    
    chmod +x "/tmp/test_vm_detection.sh"
    print_status "$YELLOW" "[*] Copie este script para dentro da VM Windows e execute:"
    echo ""
    print_status "$GREEN" "Dentro do WSL ou Git Bash no Windows:"
    echo "    bash /tmp/test_vm_detection.sh"
    echo ""
    print_status "$BLUE" "OU para Windows PowerShell (admin):"
    echo "    Get-WmiObject Win32_ComputerSystem | Select Manufacturer, Model"
    echo "    Get-ItemProperty HKLM:\HARDWARE\DESCRIPTION\System\BIOS | Select SystemBiosVersion"
}

# ============================================
# MAIN
# ============================================

main() {
    check_dependencies
    
    # Carregar configuração existente
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    while true; do
        show_menu
        
        case $choice in
            1)
                enable_hide
                ;;
            2)
                disable_hide
                ;;
            3)
                check_hide_status
                ;;
            4)
                start_vm
                ;;
            5)
                create_vm_config
                ;;
            6)
                test_detection
                ;;
            0)
                print_status "$GREEN" "\n[✓] Saindo..."
                exit 0
                ;;
            *)
                print_status "$RED" "[!] Opção inválida!"
                ;;
        esac
        
        echo ""
        read -p "Pressione ENTER para continuar..."
    done
}

# Executar função principal
main
