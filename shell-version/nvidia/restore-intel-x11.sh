#!/usr/bin/env bash

# Descarta o fluxo NVIDIA 390xx e volta o sistema para Intel + Plasma X11.
# Use TARGET_ROOT=/caminho/do/sistema quando rodar a partir de um live CD.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_ROOT="${TARGET_ROOT:-/}"
TARGET_USER="${TARGET_USER:-}"
declare -a CLEANUP_MOUNTS=()

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

is_live_target() {
    [[ "$TARGET_ROOT" != "/" ]]
}

require_execution_mode() {
    if is_live_target; then
        if [[ $EUID -ne 0 ]]; then
            print_error "No live CD, rode como root e informe TARGET_ROOT."
            print_error "Exemplo: sudo TARGET_ROOT=/run/media/liveuser/fedora/root bash restore-intel-x11.sh"
            exit 1
        fi
    elif [[ $EUID -eq 0 ]]; then
        print_error "Este script nao deve ser executado como root no sistema ativo."
        print_error "Execute como usuario normal; o script usa sudo quando necessario."
        exit 1
    fi
}

check_fedora() {
    local os_release

    os_release="$TARGET_ROOT/etc/fedora-release"
    if [[ ! -f "$os_release" ]]; then
        print_error "O alvo informado nao parece ser um Fedora valido: $TARGET_ROOT"
        exit 1
    fi
}

resolve_target_user() {
    if [[ -n "$TARGET_USER" ]]; then
        return
    fi

    TARGET_USER="$(
        awk -F: '$3 >= 1000 && $1 != "nobody" { print $1; exit }' "$TARGET_ROOT/etc/passwd"
    )"

    if [[ -z "$TARGET_USER" ]]; then
        print_error "Nao foi possivel identificar o usuario principal do sistema alvo."
        print_error "Defina TARGET_USER manualmente."
        exit 1
    fi
}

cleanup() {
    local mountpoint_path

    if [[ ${#CLEANUP_MOUNTS[@]} -eq 0 ]]; then
        return
    fi

    for (( idx=${#CLEANUP_MOUNTS[@]}-1; idx>=0; idx-- )); do
        mountpoint_path="${CLEANUP_MOUNTS[$idx]}"
        if mountpoint -q "$mountpoint_path"; then
            umount "$mountpoint_path" || true
        fi
    done
}

register_mount() {
    CLEANUP_MOUNTS+=("$1")
}

bind_mount() {
    local source="$1"
    local target="$2"

    mkdir -p "$target"
    if ! mountpoint -q "$target"; then
        mount --bind "$source" "$target"
        register_mount "$target"
    fi
}

mount_proc() {
    local target="$1"

    mkdir -p "$target"
    if ! mountpoint -q "$target"; then
        mount -t proc proc "$target"
        register_mount "$target"
    fi
}

mount_from_fstab() {
    local mount_path="$1"
    local spec
    local device
    local target_path

    spec="$(awk -v mp="$mount_path" '$2 == mp { print $1; exit }' "$TARGET_ROOT/etc/fstab")"
    [[ -n "$spec" ]] || return

    device="$(findfs "$spec" 2>/dev/null || true)"
    [[ -n "$device" ]] || return

    target_path="$TARGET_ROOT$mount_path"
    mkdir -p "$target_path"
    if ! mountpoint -q "$target_path"; then
        mount "$device" "$target_path"
        register_mount "$target_path"
    fi
}

prepare_live_chroot() {
    print_info "Preparando chroot no sistema montado..."

    trap cleanup EXIT

    bind_mount /dev "$TARGET_ROOT/dev"
    bind_mount /sys "$TARGET_ROOT/sys"
    bind_mount /run "$TARGET_ROOT/run"
    mount_proc "$TARGET_ROOT/proc"
    mount_from_fstab /boot
    mount_from_fstab /boot/efi

}

run_target_cmd() {
    if is_live_target; then
        chroot "$TARGET_ROOT" /bin/bash -lc "$1"
    else
        sudo /bin/bash -lc "$1"
    fi
}

remove_390xx_packages() {
    local -a packages=()

    mapfile -t packages < <(
        run_target_cmd "rpm -qa | grep -E '^(akmod-nvidia-390xx|xorg-x11-drv-nvidia-390xx|xorg-x11-drv-nvidia-390xx-cuda|xorg-x11-drv-nvidia-390xx-libs|xorg-x11-drv-nvidia-390xx-kmodsrc|kmod-nvidia-390xx)' || true"
    )

    if [[ ${#packages[@]} -eq 0 ]]; then
        print_info "Nenhum pacote 390xx instalado foi encontrado."
        return
    fi

    print_info "Removendo pacotes 390xx instalados..."
    if is_live_target; then
        chroot "$TARGET_ROOT" dnf remove -y "${packages[@]}"
    else
        sudo dnf remove -y "${packages[@]}"
    fi
}

remove_390xx_config() {
    print_info "Removendo configuracoes que puxavam o boot/sessao pela NVIDIA..."

    run_target_cmd "rm -f \
        /etc/modprobe.d/blacklist-nouveau.conf \
        /etc/modprobe.d/blacklist-nvidia-390xx.conf \
        /etc/modprobe.d/nvidia-optimus.conf \
        /usr/lib/modprobe.d/nvidia-installer-disable-nouveau.conf \
        /etc/X11/xorg.conf.d/10-nvidia-390xx.conf \
        /etc/sddm.conf.d/10-nvidia-x11.conf"

    run_target_cmd "mkdir -p /etc/modprobe.d && cat > /etc/modprobe.d/blacklist-nvidia-discarded.conf <<'EOF'
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
EOF"
}

ensure_x11_defaults() {
    print_info "Garantindo Plasma X11 com sessao padrao sem forcar NVIDIA..."

    if is_live_target; then
        chroot "$TARGET_ROOT" dnf install -y plasma-workspace-x11 kwin-x11 xorg-x11-server-Xorg mesa-dri-drivers
    else
        sudo dnf install -y plasma-workspace-x11 kwin-x11 xorg-x11-server-Xorg mesa-dri-drivers
    fi

    run_target_cmd "mkdir -p /etc/sddm.conf.d && cat > /etc/sddm.conf.d/10-x11.conf <<'EOF'
[General]
DisplayServer=x11

[X11]
SessionDir=/usr/share/xsessions
EOF"

    run_target_cmd "mkdir -p /var/lib/sddm && cat > /var/lib/sddm/state.conf <<EOF
[Last]
Session=plasmax11.desktop
User=${TARGET_USER}
EOF"
}

rebuild_initramfs() {
    print_info "Recriando initramfs para remover referencias ao 390xx..."
    run_target_cmd "if [[ -d /boot/efi ]]; then
        machine_id=\$(cat /etc/machine-id 2>/dev/null || true)
        if [[ -n \$machine_id ]]; then
            for kernel_version in /lib/modules/*; do
                kernel_version=\${kernel_version##*/}
                mkdir -p \"/boot/efi/\$machine_id/\$kernel_version\"
            done
        fi
    fi"
    run_target_cmd "dracut --force --regenerate-all"
}

main() {
    require_execution_mode
    check_fedora
    resolve_target_user

    if is_live_target; then
        prepare_live_chroot
    fi

    echo "============================================="
    echo "🧹 Discarding NVIDIA 390xx and Restoring Intel/X11"
    echo "============================================="
    echo "Target root: $TARGET_ROOT"
    echo "Target user: $TARGET_USER"

    remove_390xx_packages
    remove_390xx_config
    ensure_x11_defaults
    rebuild_initramfs

    echo
    print_success "Fluxo NVIDIA 390xx descartado."
    echo "O sistema ficou configurado para iniciar em Plasma X11 sem forcar a GPU NVIDIA."
    echo
    echo "Reinicie para aplicar:"
    echo "  sudo reboot"
}

main "$@"
