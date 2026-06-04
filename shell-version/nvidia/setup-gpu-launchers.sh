#!/usr/bin/env bash

set -euo pipefail

echo "AVISO: os launchers NVIDIA foram descontinuados."
echo "O driver 390xx foi descartado para evitar que o sistema entre pela NVIDIA."
echo "Use a GPU padrao Intel e, se necessario, rode primeiro:"
echo "  bash shell-version/nvidia/restore-intel-x11.sh"
