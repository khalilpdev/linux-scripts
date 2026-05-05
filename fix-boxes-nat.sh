#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Configurando rede NAT para VM Windows no Boxes ===${NC}\n"

# 1. Listar VMs disponíveis
echo -e "${BLUE}VMs encontradas:${NC}"
virsh -c qemu:///session list --all
echo ""

# 2. Perguntar o nome da VM
read -p "Digite o nome exato da sua VM Windows (ex: win11-2): " VM_NAME

# Verifica se a VM existe
if ! virsh -c qemu:///session list --all | grep -q "$VM_NAME"; then
    echo -e "${RED}Erro: VM '$VM_NAME' não encontrada!${NC}"
    exit 1
fi

echo -e "\n${GREEN}VM selecionada: $VM_NAME${NC}\n"

# 3. Configurar rede default no sistema
echo -e "${BLUE}1. Configurando rede NAT no sistema...${NC}"

# Verifica se a rede default já existe
if ! sudo virsh net-list --all 2>/dev/null | grep -q "default"; then
    echo -e "${YELLOW}Criando rede default...${NC}"
    cat > /tmp/default_network.xml << EOF
<network>
  <name>default</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    sudo virsh net-define /tmp/default_network.xml
    rm /tmp/default_network.xml
fi

# Para e remove rede default se estiver com problema
if sudo virsh net-list --all 2>/dev/null | grep -q "default"; then
    sudo virsh net-destroy default 2>/dev/null
    sudo virsh net-undefine default 2>/dev/null
fi

# Recria a rede do zero
cat > /tmp/default_network.xml << EOF
<network>
  <name>default</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

sudo virsh net-define /tmp/default_network.xml
sudo virsh net-start default
sudo virsh net-autostart default
rm /tmp/default_network.xml

echo -e "${GREEN}Rede default configurada!${NC}\n"

# 4. Instalar virt-xml se não estiver disponível
if ! command -v virt-xml &> /dev/null; then
    echo -e "${YELLOW}Instalando virt-xml...${NC}"
    sudo dnf install -y virt-install
fi

# 5. Parar a VM
echo -e "${BLUE}2. Preparando a VM...${NC}"
if virsh -c qemu:///session domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
    echo -e "${YELLOW}Desligando a VM $VM_NAME...${NC}"
    virsh -c qemu:///session destroy "$VM_NAME"
    sleep 3
fi

# 6. Verificar snapshots e remover se necessário
echo -e "${BLUE}3. Verificando snapshots...${NC}"
SNAPSHOT_COUNT=$(virsh -c qemu:///session snapshot-list "$VM_NAME" 2>/dev/null | grep -c "active" || echo "0")

if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}A VM possui snapshots. Removendo para permitir modificação...${NC}"
    virsh -c qemu:///session snapshot-list "$VM_NAME" | grep -v "^$" | tail -n +3 | while read -r line; do
        SNAP_NAME=$(echo "$line" | awk '{print $1}')
        if [ -n "$SNAP_NAME" ] && [ "$SNAP_NAME" != "Name" ]; then
            echo -e "Removendo snapshot: $SNAP_NAME"
            virsh -c qemu:///session snapshot-delete "$VM_NAME" "$SNAP_NAME" --metadata
        fi
    done
fi

# 7. Usando virt-xml para configurar rede (método correto)
echo -e "${BLUE}4. Configurando rede NAT com virt-xml...${NC}"

# Remove todas as interfaces de rede existentes
echo -e "${YELLOW}Removendo interfaces de rede antigas...${NC}"
while virsh -c qemu:///session domiflist "$VM_NAME" 2>/dev/null | grep -q "network"; do
    virt-xml -c qemu:///session "$VM_NAME" --remove-all-devices --device network 2>/dev/null || break
done

# Adiciona nova interface NAT
echo -e "${YELLOW}Adicionando interface NAT...${NC}"
virt-xml -c qemu:///session "$VM_NAME" --add-device --network network=default,model=e1000e

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Rede NAT configurada com sucesso!${NC}"
else
    echo -e "${RED}Falha ao configurar rede. Tentando método alternativo...${NC}"
    
    # Método alternativo: editar XML manualmente com cuidado
    virsh -c qemu:///session dumpxml "$VM_NAME" > /tmp/vm_original.xml
    
    # Usa Python para manipular XML corretamente
    python3 << EOF
import xml.etree.ElementTree as ET

tree = ET.parse('/tmp/vm_original.xml')
root = tree.getroot()

# Remove todas as interfaces existentes
for device in root.findall('devices'):
    for interface in device.findall('interface'):
        device.remove(interface)
    
    # Adiciona nova interface NAT
    interface = ET.SubElement(device, 'interface', type='network')
    source = ET.SubElement(interface, 'source', network='default')
    model = ET.SubElement(interface, 'model', type='e1000e')

tree.write('/tmp/vm_nova.xml', encoding='utf-8', xml_declaration=True)
EOF
    
    virsh -c qemu:///session undefine "$VM_NAME"
    virsh -c qemu:///session define /tmp/vm_nova.xml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Rede configurada pelo método alternativo!${NC}"
    else
        echo -e "${RED}Erro crítico. Restaurando backup...${NC}"
        virsh -c qemu:///session define /tmp/vm_original.xml
        exit 1
    fi
fi

# 8. Iniciar a VM
echo -e "\n${BLUE}5. Iniciando a VM...${NC}"
virsh -c qemu:///session start "$VM_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ VM iniciada com sucesso!${NC}"
else
    echo -e "${RED}Erro ao iniciar a VM${NC}"
    exit 1
fi

# 9. Aguardar e verificar IP
echo -e "\n${YELLOW}Aguardando 15 segundos para a VM inicializar...${NC}"
sleep 15

echo -e "\n${BLUE}6. Verificando conectividade de rede...${NC}"
echo -e "${YELLOW}IPs atribuídos pela rede NAT:${NC}"
sudo virsh net-dhcp-leases default 2>/dev/null | grep -E "($VM_NAME|--|expiry-time)" || echo -e "${YELLOW}Nenhum IP encontrado ainda.${NC}"

echo -e "\n${BLUE}Comandos úteis para diagnóstico:${NC}"
echo -e "  ${YELLOW}sudo virsh net-dhcp-leases default${NC} - Ver IPs da rede NAT"
echo -e "  ${YELLOW}virsh -c qemu:///session domifaddr \"$VM_NAME\"${NC} - Ver IP da VM"
echo -e "  ${YELLOW}sudo virsh net-list --all${NC} - Ver status da rede"

echo -e "\n${GREEN}=== CONFIGURAÇÃO CONCLUÍDA ===${NC}"
echo -e "\n${BLUE}Se o Windows não tiver internet:${NC}"
echo -e "1. Baixe os drivers VirtIO:"
echo -e "   ${YELLOW}wget -O /tmp/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso${NC}"
echo -e "2. Adicione o CD-ROM (com VM ligada):"
echo -e "   ${YELLOW}virsh -c qemu:///session attach-disk $VM_NAME /tmp/virtio-win.iso hdc --type cdrom --mode readonly${NC}"
echo -e "3. No Windows, instale o driver da pasta ${YELLOW}NetKVM\\w10\\amd64${NC} no CD-ROM"