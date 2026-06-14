#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/../shell-version/nvidia/restore-intel-x11.sh"

echo "AVISO: o fluxo NVIDIA 390xx foi descartado para nao puxar o sistema pela NVIDIA."
echo "Executando a restauracao suportada para Intel + Plasma X11..."

exec bash "$TARGET" "$@"
