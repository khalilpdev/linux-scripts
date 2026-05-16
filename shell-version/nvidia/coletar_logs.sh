#!/bin/bash
echo "=== COLETANDO LOGS NVIDIA 390xx ==="
echo ""

echo "1️⃣ ARQUIVO FAILED.LOG:"
echo "------------------------"
sudo cat /var/cache/akmods/nvidia-390xx/*.failed.log 2>/dev/null | tail -50

echo ""
echo "2️⃣ MÓDULOS KERNEL:"
echo "------------------------"
ls -la /lib/modules/$(uname -r)/extra/nvidia*.ko* 2>/dev/null

echo ""
echo "3️⃣ LS MOD:"
echo "------------------------"
lsmod | grep -E "nvidia|nouveau"

echo ""
echo "4️⃣ LINK LIBGLX:"
echo "------------------------"
ls -la /usr/lib64/xorg/modules/extensions/libglx.so* 2>/dev/null

echo ""
echo "5️⃣ XORG LOG (ERROS):"
echo "------------------------"
sudo cat /var/log/Xorg.0.log 2>/dev/null | grep -i "nvidia\|error\|ee" | tail -30

echo ""
echo "6️⃣ JOURNALCTL (NVIDIA):"
echo "------------------------"
sudo journalctl -xe 2>/dev/null | grep -i nvidia | tail -20

echo ""
echo "7️⃣ KERNEL VERSION:"
echo "------------------------"
uname -r

echo ""
echo "8️⃣ DMESG (NVIDIA):"
echo "------------------------"
sudo dmesg | grep -i nvidia | tail -20

echo ""
echo "9️⃣ RPM VERIFICATION:"
echo "------------------------"
rpm -qa | grep -E "nvidia|akmod" | grep -i 390

echo ""
echo "🔟 DRACUT STATUS:"
echo "------------------------"
sudo dracut --force --verbose 2>&1 | grep -i nvidia | tail -10

echo ""
echo "=== FIM DOS LOGS ==="