#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "AVISO: o fluxo NVIDIA 390xx foi descartado para nao puxar o sistema pela NVIDIA."
echo "Executando a restauracao suportada para Intel + Plasma X11..."

exec bash "$SCRIPT_DIR/restore-intel-x11.sh" "$@"
