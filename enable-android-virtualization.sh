#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Execute este script como usuario normal (nao root)."
  exit 1
fi

echo "==> Verificando suporte de virtualizacao da CPU"
if ! grep -E -q "(vmx|svm)" /proc/cpuinfo; then
  echo "Sua CPU nao reporta VT-x/AMD-V (vmx/svm)."
  echo "Ative virtualizacao na BIOS/UEFI e tente novamente."
  exit 1
fi

echo "==> Instalando pacotes KVM/libvirt (Fedora)"
sudo dnf install -y --skip-unavailable qemu-kvm libvirt virt-install virt-manager bridge-utils cpu-checker

echo "==> Habilitando libvirtd"
sudo systemctl enable --now libvirtd

echo "==> Adicionando usuario ao grupo libvirt"
sudo usermod -aG libvirt "${USER}"

echo "==> Verificando modulo KVM carregado"
if lsmod | grep -q "kvm"; then
  echo "Modulo KVM carregado com sucesso."
else
  echo "Modulo KVM nao carregado automaticamente."
  echo "Tentando carregar modulo generico kvm..."
  sudo modprobe kvm || true

  if grep -qi "GenuineIntel" /proc/cpuinfo; then
    sudo modprobe kvm_intel || true
  elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    sudo modprobe kvm_amd || true
  fi
fi

echo "==> Validando aceleracao"
if command -v kvm-ok >/dev/null 2>&1; then
  kvm-ok || true
else
  echo "Comando kvm-ok indisponivel; pulando validacao detalhada."
fi

echo
if id -nG "${USER}" | grep -qw libvirt; then
  echo "Usuario ja esta no grupo libvirt."
else
  echo "Usuario adicionado ao grupo libvirt."
  echo "Faca logout/login para aplicar o novo grupo."
fi

echo "Pronto. Depois do logout/login, abra o Android Emulator novamente."
