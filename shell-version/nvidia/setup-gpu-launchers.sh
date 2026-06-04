#!/bin/bash

# Cria launchers KDE para rodar apps com GPU Intel (padrão) ou NVIDIA 390xx.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script não deve ser executado como root."
        print_error "Execute como usuário normal; o script cria arquivos no seu HOME."
        exit 1
    fi
}

need_kdialog() {
    if ! command -v kdialog >/dev/null 2>&1; then
        print_warning "kdialog não encontrado. Os atalhos vão abrir um prompt básico no terminal."
    fi
}

create_helper() {
    local helper_dir="$HOME/.local/bin"
    local helper_file="$helper_dir/fedora-gpu-launch"

    mkdir -p "$helper_dir"

    cat > "$helper_file" <<'EOF'
#!/bin/bash
set -euo pipefail

MODE="${1:-}"
shift || true

run_command() {
    local cmd="$1"
    python3 - <<'PY' "$MODE" "$cmd"
import os, shlex, subprocess, sys
mode = sys.argv[1]
cmd = sys.argv[2].strip()
if not cmd:
    raise SystemExit(1)
args = shlex.split(cmd)
env = os.environ.copy()
if mode == "nvidia":
    env["__NV_PRIME_RENDER_OFFLOAD"] = "1"
    env["__GLX_VENDOR_LIBRARY_NAME"] = "nvidia"
    env["__VK_LAYER_NV_optimus"] = "NVIDIA_only"
subprocess.run(args, env=env, check=True)
PY
}

prompt_and_run() {
    local title="$1"
    local cmd=""

    if command -v kdialog >/dev/null 2>&1; then
        cmd="$(kdialog --title "$title" --inputbox "Digite o comando do app:" "" || true)"
    else
        read -r -p "Digite o comando do app: " cmd
    fi

    [[ -n "$cmd" ]] || exit 0
    run_command "$cmd"
}

if [[ $# -gt 0 ]]; then
    run_command "$*"
else
    prompt_and_run "Fedora GPU Launch ($MODE)"
fi
EOF

    chmod +x "$helper_file"
    print_success "Helper criado: $helper_file"
}

create_desktop_entries() {
    local desktop_dir="$HOME/.local/share/applications"
    local helper_file="$HOME/.local/bin/fedora-gpu-launch"
    mkdir -p "$desktop_dir"

    cat > "$desktop_dir/fedora-gpu-launch-intel.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Run App with Intel GPU
Comment=Start an application using the default GPU
Exec=${helper_file} intel
Terminal=false
Categories=Utility;
Icon=applications-system
EOF

    cat > "$desktop_dir/fedora-gpu-launch-nvidia.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Run App with NVIDIA 390xx
Comment=Start an application using the NVIDIA 390xx GPU
Exec=${helper_file} nvidia
Terminal=false
Categories=Utility;
Icon=video-display
PrefersNonDefaultGPU=true
EOF

    chmod +x "$desktop_dir/fedora-gpu-launch-intel.desktop" "$desktop_dir/fedora-gpu-launch-nvidia.desktop"
    print_success "Atalhos criados em: $desktop_dir"
}

main() {
    check_root
    need_kdialog
    create_helper
    create_desktop_entries

    echo
    print_success "Launchers criados."
    echo "Use os atalhos:"
    echo "  - Run App with Intel GPU"
    echo "  - Run App with NVIDIA 390xx"
}

main
