#!/bin/bash

# Script para instalar dependências do OSX-KVM no Fedora 44 (DNF5 nativo)
# Baseado nos requisitos do repositório: https://github.com/kholia/OSX-KVM
# Execute como root (sudo)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}### Iniciando configuração do ambiente para OSX-KVM no Fedora 44 ###${NC}"

# 1. Atualização do sistema
echo -e "${YELLOW}[1/8] Atualizando sistema...${NC}"
dnf update -y

# 2. Instalação de pacotes de desenvolvimento individuais (alternativa aos grupos)
echo -e "${YELLOW}[2/8] Instalando ferramentas de desenvolvimento...${NC}"
dnf install -y \
    gcc \
    gcc-c++ \
    make \
    automake \
    autoconf \
    libtool \
    cmake \
    git \
    wget \
    curl \
    patch \
    rpm-build

# 3. Instalação dos pacotes principais do OSX-KVM
echo -e "${YELLOW}[3/8] Instalando QEMU, KVM e ferramentas de virtualização...${NC}"
dnf install -y \
    qemu-system-x86 \
    qemu-img \
    libvirt \
    libvirt-daemon-driver-qemu \
    virt-manager \
    virt-viewer \
    edk2-ovmf \
    seabios

# 4. Instalação de utilitários necessários
echo -e "${YELLOW}[4/8] Instalando utilitários e ferramentas auxiliares...${NC}"
dnf install -y \
    dmg2img \
    p7zip \
    p7zip-plugins \
    genisoimage \
    libguestfs-tools \
    tesseract \
    tesseract-langpack-eng \
    net-tools \
    screen \
    vim \
    nano \
    python3 \
    python3-pip \
    wget \
    unzip \
    xorriso

# 5. Verificação da virtualização da CPU
echo -e "${YELLOW}[5/8] Verificando suporte à virtualização de hardware...${NC}"
if grep -E "vmx" /proc/cpuinfo > /dev/null; then
    CPU_TYPE="intel"
    echo -e "${GREEN}✓ CPU Intel com VT-x detectado.${NC}"
elif grep -E "svm" /proc/cpuinfo > /dev/null; then
    CPU_TYPE="amd"
    echo -e "${GREEN}✓ CPU AMD com SVM detectado.${NC}"
else
    echo -e "${RED}✗ ERRO: Seu processador não suporta virtualização de hardware.${NC}"
    echo -e "${YELLOW}Verifique se a virtualização está ativada na BIOS/UEFI.${NC}"
    exit 1
fi

# 6. Configuração do módulo KVM
echo -e "${YELLOW}[6/8] Configurando módulo KVM...${NC}"

# Cria arquivo de configuração do KVM
if [ "$CPU_TYPE" = "intel" ]; then
    cat > /etc/modprobe.d/kvm.conf << EOF
# Configuração para Intel VT-x
options kvm_intel nested=1
options kvm ignore_msrs=1
EOF
else
    cat > /etc/modprobe.d/kvm.conf << EOF
# Configuração para AMD SVM
options kvm_amd nested=1
options kvm ignore_msrs=1
EOF
fi

# Remove módulos antigos se carregados
modprobe -r kvm_intel 2>/dev/null || true
modprobe -r kvm_amd 2>/dev/null || true
modprobe -r kvm 2>/dev/null || true

# Carrega o módulo KVM
modprobe kvm

# Carrega o módulo específico da CPU
if [ "$CPU_TYPE" = "intel" ]; then
    modprobe kvm_intel
else
    modprobe kvm_amd
fi

# Verifica se ignore_msrs está ativo
sleep 1
if [ -f /sys/module/kvm/parameters/ignore_msrs ]; then
    echo 1 > /sys/module/kvm/parameters/ignore_msrs 2>/dev/null || true
    echo -e "${GREEN}✓ KVM configurado com ignore_msrs=1${NC}"
fi

# 7. Configuração de usuário e grupos
echo -e "${YELLOW}[7/8] Configurando permissões de usuário...${NC}"

# Detecta o usuário real (mesmo quando usando sudo)
REAL_USER="${SUDO_USER:-$USER}"
echo -e "${BLUE}Configurando para usuário: $REAL_USER${NC}"

# Adiciona aos grupos necessários
usermod -aG kvm "$REAL_USER"
usermod -aG libvirt "$REAL_USER"
usermod -aG input "$REAL_USER"

# Habilita e inicia o libvirt
systemctl enable libvirtd
systemctl start libvirtd

# 8. Clone e preparação do repositório
echo -e "${YELLOW}[8/8] Clonando o repositório OSX-KVM...${NC}"
cd "/home/$REAL_USER"

if [ -d "OSX-KVM" ]; then
    echo -e "${BLUE}Diretório OSX-KVM já existe. Atualizando...${NC}"
    cd OSX-KVM
    sudo -u "$REAL_USER" git pull --rebase 2>/dev/null || true
else
    echo -e "${BLUE}Clonando repositório fresco...${NC}"
    sudo -u "$REAL_USER" git clone --depth 1 --recursive https://github.com/kholia/OSX-KVM.git
    cd OSX-KVM
fi

# Cria um script de ativação rápida
cat > "/home/$REAL_USER/start-osx-kvm.sh" << 'EOF'
#!/bin/bash
# Script rápido para iniciar o OSX-KVM

cd ~/OSX-KVM

# Verifica se o módulo KVM está carregado
if ! lsmod | grep -q kvm; then
    echo "Carregando módulo KVM..."
    sudo modprobe kvm
    if grep -q vmx /proc/cpuinfo; then
        sudo modprobe kvm_intel
    else
        sudo modprobe kvm_amd
    fi
    sudo sh -c "echo 1 > /sys/module/kvm/parameters/ignore_msrs"
fi

# Inicia a VM
./OpenCore-Boot.sh
EOF

chmod +x "/home/$REAL_USER/start-osx-kvm.sh"
chown "$REAL_USER:$REAL_USER" "/home/$REAL_USER/start-osx-kvm.sh"

echo -e "${GREEN}### ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ###${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📋 PRÓXIMOS PASSOS OBRIGATÓRIOS:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "1️⃣  FAÇA LOGOUT E LOGIN NOVAMENTE (importante!)"
echo "   ↳ As permissões de grupo só serão aplicadas após relogar"
echo ""
echo "2️⃣  Entre no diretório do projeto:"
echo "   cd ~/OSX-KVM"
echo ""
echo "3️⃣  Baixe o macOS desejado:"
echo "   ./fetch-macOS-v2.py"
echo "   ↳ Recomendado: Sonoma (opção 7) ou Ventura (opção 6)"
echo ""
echo "4️⃣  Converta a imagem base:"
echo "   dmg2img -i BaseSystem.dmg BaseSystem.img"
echo ""
echo "5️⃣  Crie o disco virtual (256GB recomendado):"
echo "   qemu-img create -f qcow2 mac_hdd_ng.img 256G"
echo ""
echo "6️⃣  Inicie a instalação:"
echo "   ./OpenCore-Boot.sh"
echo "   ↳ OU use o atalho: ~/start-osx-kvm.sh"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚠️  DICAS IMPORTANTES:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "🔹 Primeira inicialização pode levar vários minutos - tenha paciência!"
echo "🔹 Use as SETAS do teclado para navegar no menu do OpenCore"
echo "🔹 Pressione ENTER quando chegar no menu de boot do OpenCore"
echo "🔹 Se o mouse/touchpad travar: Ctrl+Alt+G para liberar"
echo "🔹 Para mudar resolução: use OVMF_VARS-1920x1080.fd (edite o script)"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "❌ Erro 'KVM not found':"
echo "   → Execute: sudo modprobe kvm"
echo ""
echo "❌ Erro 'ignore_msrs not set':"
echo "   → Execute: sudo sh -c 'echo 1 > /sys/module/kvm/parameters/ignore_msrs'"
echo ""
echo "❌ VM não inicia ou trava:"
echo "   → Verifique virtualização na BIOS: VT-x (Intel) ou SVM (AMD)"
echo "   → Execute: egrep -c '(vmx|svm)' /proc/cpuinfo (resultado deve ser >0)"
echo ""
echo "❌ Rede não funciona no macOS:"
echo "   → Leia o arquivo: ~/OSX-KVM/networking-qemu-kvm-howto.txt"
echo ""
echo -e "${GREEN}✨ BOM TRABALHO! ✨${NC}"