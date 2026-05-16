#!/bin/bash

VM_NAME="win11-2"
DISK_PATH="$HOME/.local/share/gnome-boxes/images/$VM_NAME"
TARGET_SIZE="70G"

echo "=== Redimensionando disco da VM $VM_NAME para $TARGET_SIZE ==="

# 1. Verifica se a VM existe
if [ ! -f "$DISK_PATH" ]; then
    echo "Erro: Disco não encontrado em $DISK_PATH"
    exit 1
fi

# 2. Verifica tamanho atual
echo "Tamanho atual:"
qemu-img info "$DISK_PATH" | grep "virtual size"

# 3. Desliga a VM se estiver rodando
if virsh -c qemu:///session domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
    echo "Desligando VM..."
    virsh -c qemu:///session shutdown "$VM_NAME"
    sleep 5
    # Força desligamento se necessário
    if virsh -c qemu:///session domstate "$VM_NAME" | grep -q "running"; then
        virsh -c qemu:///session destroy "$VM_NAME"
    fi
fi

# 4. Faz backup do disco
echo "Fazendo backup em ${DISK_PATH}.backup..."
cp "$DISK_PATH" "${DISK_PATH}.backup"
echo "Backup concluído!"

# 5. Redimensiona para 70G
echo "Redimensionando para $TARGET_SIZE..."
qemu-img resize "$DISK_PATH" "$TARGET_SIZE"

# 6. Verifica o novo tamanho
echo ""
echo "Novo tamanho:"
qemu-img info "$DISK_PATH" | grep "virtual size"

echo ""
echo "=== ✅ DISCO REDIMENSIONADO COM SUCESSO! ==="
echo ""
echo "⚠️  PRÓXIMOS PASSOS (dentro do Windows):"
echo ""
echo "1. Inicie a VM pelo Boxes"
echo "2. No Windows, abra o Gerenciamento de Discos:"
echo "   - Pressione Win + X"
echo "   - Clique em 'Gerenciamento de Disco'"
echo "   - Ou digite 'diskmgmt.msc' no Executar (Win + R)"
echo ""
echo "3. Você verá o espaço não alocado ao lado do volume C:"
echo "   - Clique com botão direito no volume C:"
echo "   - Selecione 'Estender Volume'"
echo "   - Siga o assistente (usar todo o espaço disponível)"
echo ""
echo "4. Pronto! Seu C: terá os 70GB completos"
echo ""
echo "📌 Backup salvo em: ${DISK_PATH}.backup"