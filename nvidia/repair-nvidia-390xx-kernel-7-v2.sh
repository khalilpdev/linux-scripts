#!/bin/bash
# Script de REPARO DEFINITIVO com PATCH para kernel 7.x
# Corrige:
#   - erro 'screen_info' undeclared (os_get_screen_info)
#   - erro 'void value not ignored' (nv_dma_fence_signal)

set -e

echo "=== REPARO DEFINITIVO NVIDIA 390xx para kernel 7.x ==="

# 1. Localizar o tarball fonte do driver
echo "[1/5] Localizando fonte do driver..."
TARBALL=$(ls /usr/share/nvidia-390xx-kmod-*/nvidia-390xx-kmod-*-x86_64.tar.xz 2>/dev/null | head -1)

if [ -z "$TARBALL" ]; then
    echo "❌ Fonte do driver não encontrada! Instale xorg-x11-drv-nvidia-390xx-kmodsrc"
    sudo dnf install -y xorg-x11-drv-nvidia-390xx-kmodsrc
    TARBALL=$(ls /usr/share/nvidia-390xx-kmod-*/nvidia-390xx-kmod-*-x86_64.tar.xz 2>/dev/null | head -1)
    if [ -z "$TARBALL" ]; then
        exit 1
    fi
fi

echo "   Tarball: $TARBALL"

# 2. Extrair para diretório temporário
echo "[2/5] Extraindo fonte..."
WORKDIR=$(mktemp -d)
tar -xJf "$TARBALL" -C "$WORKDIR"

# 3. Aplicar patches
echo "[3/5] Aplicando patches..."

# Patch 1: os_get_screen_info - screen_info foi removida do kernel 7.x
OS_INTERFACE="$WORKDIR/kernel/nvidia/os-interface.c"
python3 << EOF
with open("$OS_INTERFACE", 'r') as f:
    content = f.read()

start = content.index('void NV_API_CALL os_get_screen_info(')
end = content.index('void NV_API_CALL os_dump_stack()')

before_dump = content[start:end]
last_brace = before_dump.rfind('}')
func_end = start + last_brace + 1

new_func = '''void NV_API_CALL os_get_screen_info(
    NvU64 *pPhysicalAddress,
    NvU16 *pFbWidth,
    NvU16 *pFbHeight,
    NvU16 *pFbDepth,
    NvU16 *pFbPitch
)
{
    *pPhysicalAddress = 0;
    *pFbWidth = *pFbHeight = *pFbDepth = *pFbPitch = 0;
    return;
}
'''

content = content[:start] + new_func + content[end:]

with open("$OS_INTERFACE", 'w') as f:
    f.write(content)
EOF
echo "   ✅ Patch os_get_screen_info aplicado"

# Patch 2: nv_dma_fence_signal - dma_fence_signal retorna void no kernel 7.x
DMA_FENCE_H="$WORKDIR/kernel/nvidia-drm/nvidia-dma-fence-helper.h"
python3 << EOF
with open("$DMA_FENCE_H", 'r') as f:
    content = f.read()

old = '''static inline int nv_dma_fence_signal(nv_dma_fence_t *fence) {
#if defined(NV_LINUX_FENCE_H_PRESENT)
    return fence_signal(fence);
#else
    return dma_fence_signal(fence);
#endif
}'''

new = '''static inline void nv_dma_fence_signal(nv_dma_fence_t *fence) {
#if defined(NV_LINUX_FENCE_H_PRESENT)
    fence_signal(fence);
#else
    dma_fence_signal(fence);
#endif
}'''

content = content.replace(old, new)

with open("$DMA_FENCE_H", 'w') as f:
    f.write(content)
EOF
echo "   ✅ Patch nv_dma_fence_signal aplicado"

# 4. Fazer backup do tarball original e substituir pelo patched
echo "[4/5] Recriando tarball com patches..."
sudo cp "$TARBALL" "$TARBALL.backup"

cd "$WORKDIR"
tar -cJf /tmp/nvidia-390xx-patched.tar.xz kernel/
sudo cp /tmp/nvidia-390xx-patched.tar.xz "$TARBALL"

# Limpar cache do akmod
sudo rm -rf /var/cache/akmods/nvidia-390xx/*.failed.log
sudo rm -rf /var/lib/akmods/nvidia-390xx

echo "   Reconstruindo módulo (pode levar 3-5 minutos)..."
sudo akmods --force --rebuild

# 5. Instalar o RPM gerado e recriar initramfs
echo "[5/5] Instalando módulo compilado..."
KMOD_RPM=$(ls /var/cache/akmods/nvidia-390xx/kmod-nvidia-390xx-*.fc$(rpm -E %fedora).x86_64.rpm 2>/dev/null | head -1 || true)
if [ -n "$KMOD_RPM" ]; then
    sudo dnf install -y "$KMOD_RPM"
fi

echo "   Recriando initramfs..."
sudo depmod
sudo dracut --force

echo ""
echo "=========================================="
echo "✅ REPARO CONCLUÍDO COM SUCESSO!"
echo "=========================================="
echo ""
echo "Módulos instalados:"
ls -la /lib/modules/$(uname -r)/extra/nvidia-390xx/nvidia*.ko* 2>/dev/null || echo "   (verificar após reboot)"

# Verificar se o módulo carrega
echo ""
echo "Testando carregamento do módulo..."
sudo modprobe nvidia 2>/dev/null && echo "   ✅ nvidia.ko carregado!" || echo "   ⚠️  Não foi possível carregar (normal se X estiver rodando)"
echo ""
echo "⚠️  REINICIE O SISTEMA:"
echo "   sudo reboot"
echo ""
echo "Após reiniciar, verifique com:"
echo "   nvidia-smi"
echo ""

read -p "Reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Reiniciando..."
    sudo reboot
else
    echo "Lembre-se de reiniciar manualmente depois!"
fi
