#!/bin/bash

VM_NAME="win11-2"

echo "=== Configurando VM para usar rede USER (NAT simples) ==="

# 1. Desliga a VM completamente
echo "Desligando VM..."
virsh -c qemu:///session destroy "$VM_NAME" 2>/dev/null
sleep 3

# 2. Remove TODAS as interfaces existentes
echo "Removendo todas as interfaces..."
virsh -c qemu:///session detach-interface "$VM_NAME" --type bridge --mac 52:54:00:be:08:7f 2>/dev/null
virsh -c qemu:///session detach-interface "$VM_NAME" --type network --mac 52:54:00:7f:64:c3 2>/dev/null
virsh -c qemu:///session detach-interface "$VM_NAME" --type network --mac 52:54:00:8a:eb:5a 2>/dev/null
sleep 2

# 3. Cria dump XML atual
virsh -c qemu:///session dumpxml "$VM_NAME" > /tmp/vm_current.xml

# 4. Remove qualquer interface remanescente e adiciona interface USER
python3 << 'PYTHON_SCRIPT'
import xml.etree.ElementTree as ET

tree = ET.parse('/tmp/vm_current.xml')
root = tree.getroot()

# Remove todas as interfaces existentes
for device in root.findall('devices'):
    for interface in device.findall('interface'):
        device.remove(interface)
    
    # Adiciona interface tipo 'user' (SLIRP)
    interface = ET.SubElement(device, 'interface', type='user')
    model = ET.SubElement(interface, 'model', type='e1000e')

tree.write('/tmp/vm_new.xml', encoding='utf-8', xml_declaration=True)
PYTHON_SCRIPT

# 5. Aplica a nova configuração
virsh -c qemu:///session undefine "$VM_NAME"
virsh -c qemu:///session define /tmp/vm_new.xml

# 6. Inicia a VM
echo "Iniciando VM..."
virsh -c qemu:///session start "$VM_NAME"

# 7. Verifica resultado
echo ""
echo "=== Interfaces da VM ==="
virsh -c qemu:///session domiflist "$VM_NAME"

echo ""
echo "=== Status da VM ==="
virsh -c qemu:///session list --all

echo ""
echo "✓ VM configurada com rede USER!"
echo "O Windows deve ter internet automaticamente (não precisa de drivers especiais)"