#!/usr/bin/env bash

set -euo pipefail

echo "AVISO: os logs do fluxo 390xx nao sao mais suportados."
echo "O driver 390xx foi descartado para evitar boot/sessao pela NVIDIA."
echo "Se precisar recuperar o sistema, use:"
echo "  bash shell-version/nvidia/restore-intel-x11.sh"
