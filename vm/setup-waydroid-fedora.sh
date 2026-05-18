#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Execute este script como usuario normal (nao root)."
  exit 1
fi

if [[ ! -f /etc/fedora-release ]]; then
  echo "Este script foi feito para Fedora."
  exit 1
fi

echo "==> Setup seguro do Waydroid (sem bypass de deteccao de emulador)"
echo "==> Fedora: $(rpm -E %fedora)"

install_if_missing() {
  local pkg="$1"
  if rpm -q "$pkg" >/dev/null 2>&1; then
    echo "[SKIP] Pacote $pkg ja instalado."
  else
    echo "[OK] Instalando pacote: $pkg"
    sudo dnf install -y "$pkg"
  fi
}

echo "==> Instalando dependencias base"
for pkg in curl lxc python3 python3-gobject python3-gobject-base dbus-x11; do
  install_if_missing "$pkg"
done

echo "==> Verificando repositorio COPR do Waydroid"
if dnf copr list --enabled 2>/dev/null | grep -q "eloitor/waydroid"; then
  echo "[SKIP] COPR eloitor/waydroid ja habilitado."
else
  echo "[OK] Habilitando COPR eloitor/waydroid"
  sudo dnf copr enable -y eloitor/waydroid
fi

echo "==> Verificando instalacao do Waydroid"
if command -v waydroid >/dev/null 2>&1; then
  echo "[SKIP] Waydroid ja instalado. Pulando instalacao e seguindo para o proximo passo."
else
  echo "[OK] Instalando Waydroid"
  sudo dnf install -y waydroid
fi

echo "==> Habilitando container do Waydroid"
sudo systemctl enable --now waydroid-container

echo "==> Verificando inicializacao do Waydroid"
if [[ -f /var/lib/waydroid/waydroid.cfg ]]; then
  echo "[SKIP] Waydroid ja inicializado."
else
  echo "[OK] Inicializando Waydroid (pode demorar alguns minutos)"
  sudo waydroid init
fi

echo "==> Aplicando ajuste opcional de usabilidade"
waydroid prop set persist.waydroid.multi_windows true || true

echo
echo "Concluido."
echo "Para iniciar sessao: waydroid session start"
echo "Para instalar APK:    waydroid app install /caminho/app.apk"
echo "Observacao: apps com anti-emulacao podem exigir dispositivo fisico."