#!/bin/bash
# =============================================================================
# Script: wine-2-fix-and-install-v9.sh
# Descricao: Instala o Wine (serie 10.x por padrao) compilando do codigo-fonte oficial
# Fonte: https://dl.winehq.org/wine/source/
# Autor: Leandro Khalil
# =============================================================================

set -e
set -o pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variaveis padrao (podem ser alteradas por flags)
WINE_SERIES="10"
WINE_VERSION=""
WINE_SOURCE_BASE_URL=""
BUILD_ROOT="$HOME/src"
INSTALL_PREFIX="/opt/wine10"
SOURCE_ARCHIVE=""
SOURCE_DIR=""
WIN64_ONLY="0"

# Funcoes de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

show_help() {
    cat << 'EOF'
Uso: ./wine-2-fix-and-install-v9.sh [opcoes]

Opcoes:
    --series <numero>    Serie do Wine no source (ex: 9, 10). Padrao: 10
    --version <versao>   Instala uma versao especifica (ex: 10.0)
    --prefix <caminho>   Prefixo de instalacao (padrao: /opt/wine10)
  --build-root <dir>   Pasta de trabalho para codigo-fonte (padrao: ~/src)
    --win64-only         Compila apenas 64-bit (dispensa libs 32-bit)
  -h, --help           Mostra esta ajuda

Exemplos:
    ./wine-2-fix-and-install-v9.sh
    ./wine-2-fix-and-install-v9.sh --series 10
    ./wine-2-fix-and-install-v9.sh --version 10.0
    ./wine-2-fix-and-install-v9.sh --prefix /opt/wine-10.0
    ./wine-2-fix-and-install-v9.sh --win64-only
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --series)
                shift
                if [[ -z "$1" ]]; then
                    log_error "Voce precisa informar um numero apos --series"
                    exit 1
                fi
                if [[ ! "$1" =~ ^[0-9]+$ ]]; then
                    log_error "Serie invalida: $1 (use apenas numero, ex: 10)"
                    exit 1
                fi
                WINE_SERIES="$1"
                ;;
            --version)
                shift
                if [[ -z "$1" ]]; then
                    log_error "Voce precisa informar uma versao apos --version"
                    exit 1
                fi
                WINE_VERSION="$1"
                ;;
            --prefix)
                shift
                if [[ -z "$1" ]]; then
                    log_error "Voce precisa informar um caminho apos --prefix"
                    exit 1
                fi
                INSTALL_PREFIX="$1"
                ;;
            --build-root)
                shift
                if [[ -z "$1" ]]; then
                    log_error "Voce precisa informar um caminho apos --build-root"
                    exit 1
                fi
                BUILD_ROOT="$1"
                ;;
            --win64-only)
                WIN64_ONLY="1"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Opcao desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Verifica se esta rodando como root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Este script esta rodando como root. Recomendo executar como usuario normal."
        log_warning "O script usa sudo quando necessario."
        read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

# Detecta versao do Fedora
detect_fedora_version() {
    if [ -f /etc/fedora-release ]; then
        FEDORA_VERSION=$(rpm -E %fedora)
        log_info "Fedora versao $FEDORA_VERSION detectada"
    else
        log_error "Sistema nao parece ser Fedora. Abortando."
        exit 1
    fi
}

install_build_dependencies() {
    log_info "Instalando dependencias de compilacao do Wine..."

    sudo dnf install -y --skip-unavailable \
        gcc gcc-c++ make flex bison \
        libX11-devel freetype-devel fontconfig-devel \
        libXext-devel libXrender-devel libXrandr-devel \
        libXi-devel libXcursor-devel libXinerama-devel \
        libXcomposite-devel libXdamage-devel \
        mesa-libGL-devel mesa-libOSMesa-devel \
        alsa-lib-devel pulseaudio-libs-devel \
        dbus-devel libv4l-devel \
        cups-devel samba-winbind-clients \
        ncurses-devel \
        gettext-devel libxml2-devel \
        zlib-devel libpng-devel libjpeg-turbo-devel \
        gstreamer1-devel gstreamer1-plugins-base-devel \
        mingw32-gcc mingw64-gcc \
        libunwind-devel \
        curl wget tar xz

    log_success "Dependencias instaladas"
}

install_multilib_dependencies() {
    log_info "Instalando dependencias 32-bit necessarias para build WoW64..."

    sudo dnf install -y --skip-unavailable \
        glibc-devel.i686 \
        libgcc.i686 \
        libstdc++-devel.i686 \
        zlib-devel.i686 \
        libX11-devel.i686 \
        freetype-devel.i686 \
        fontconfig-devel.i686 \
        libXext-devel.i686 \
        libXrender-devel.i686 \
        libXrandr-devel.i686 \
        libXi-devel.i686 \
        libXcursor-devel.i686 \
        libXinerama-devel.i686 \
        libXcomposite-devel.i686 \
        libXdamage-devel.i686 \
        mesa-libGL-devel.i686 \
        alsa-lib-devel.i686 \
        pulseaudio-libs-devel.i686 \
        ncurses-devel.i686

    log_success "Dependencias 32-bit processadas"
}

resolve_wine_version() {
    WINE_SOURCE_BASE_URL="https://dl.winehq.org/wine/source/${WINE_SERIES}.x"

    if [[ -n "$WINE_VERSION" ]]; then
        if [[ ! "$WINE_VERSION" =~ ^${WINE_SERIES}\.[0-9]+$ ]]; then
            log_error "Versao invalida: $WINE_VERSION (use formato ${WINE_SERIES}.x)"
            exit 1
        fi
        log_info "Versao solicitada manualmente: $WINE_VERSION"
        return 0
    fi

    log_info "Buscando a versao ${WINE_SERIES}.x mais recente em: $WINE_SOURCE_BASE_URL/"
    WINE_VERSION=$(curl -fsSL "$WINE_SOURCE_BASE_URL/" \
        | grep -oE "wine-${WINE_SERIES}\.[0-9]+\.tar\.xz" \
        | sed 's/^wine-//; s/\.tar\.xz$//' \
        | sort -V \
        | tail -n 1)

    if [[ -z "$WINE_VERSION" ]]; then
        log_error "Nao foi possivel detectar uma versao ${WINE_SERIES}.x automaticamente."
        log_error "Tente novamente com --version <${WINE_SERIES}.x>."
        exit 1
    fi

    log_success "Versao detectada: $WINE_VERSION"
}

download_source() {
    local source_url
    source_url="$WINE_SOURCE_BASE_URL/wine-$WINE_VERSION.tar.xz"

    mkdir -p "$BUILD_ROOT"
    SOURCE_ARCHIVE="$BUILD_ROOT/wine-$WINE_VERSION.tar.xz"
    SOURCE_DIR="$BUILD_ROOT/wine-$WINE_VERSION"

    log_info "Baixando fonte do Wine: $source_url"
    curl -fL "$source_url" -o "$SOURCE_ARCHIVE"

    log_info "Extraindo codigo-fonte em: $BUILD_ROOT"
    tar -xf "$SOURCE_ARCHIVE" -C "$BUILD_ROOT"

    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Pasta de codigo-fonte nao encontrada apos extracao: $SOURCE_DIR"
        exit 1
    fi

    log_success "Fonte pronto para compilacao"
}

build_and_install() {
    local build_dir
    local configure_log
    local configure_cmd
    build_dir="$SOURCE_DIR/build64"
    configure_log="$build_dir/configure.log"

    mkdir -p "$build_dir"
    cd "$build_dir"

    configure_cmd=("../configure" "--prefix=$INSTALL_PREFIX")
    if [[ "$WIN64_ONLY" == "1" ]]; then
        configure_cmd+=("--enable-win64")
    fi

    log_info "Configurando build com prefixo: $INSTALL_PREFIX"
    if ! "${configure_cmd[@]}" 2>&1 | tee "$configure_log"; then
        if grep -q "Cannot build a 32-bit program" "$configure_log" && [[ "$WIN64_ONLY" != "1" ]]; then
            log_warning "Faltam libs 32-bit para compilar WoW64."
            install_multilib_dependencies

            log_info "Tentando configure novamente apos instalar dependencias 32-bit..."
            if ! ../configure --prefix="$INSTALL_PREFIX" 2>&1 | tee "$configure_log"; then
                log_warning "Ainda falhou com suporte 32-bit."
                log_warning "Tentando modo 64-bit apenas (--enable-win64)..."
                if ! ../configure --prefix="$INSTALL_PREFIX" --enable-win64 2>&1 | tee "$configure_log"; then
                    log_error "Falha no configure mesmo em modo 64-bit. Veja: $configure_log"
                    exit 1
                fi
            fi
        else
            log_error "Falha no configure. Veja detalhes em: $configure_log"
            exit 1
        fi
    fi

    log_info "Compilando Wine (isso pode levar bastante tempo)..."
    make -j"$(nproc)"

    log_info "Instalando em $INSTALL_PREFIX"
    sudo make install

    log_success "Wine $WINE_VERSION instalado com sucesso em $INSTALL_PREFIX"
}

print_post_install_notes() {
    echo ""
    log_info "Para usar esta instalacao, execute:"
    echo "  $INSTALL_PREFIX/bin/wine --version"
    echo ""
    log_info "Opcional: adicionar ao PATH no ~/.bashrc:"
    echo "  export PATH=\"$INSTALL_PREFIX/bin:\$PATH\""
    echo ""
    log_info "Exemplo de uso:"
    echo "  $INSTALL_PREFIX/bin/wine seu_programa.exe"
}

# Funcao principal
main() {
    echo "==========================================================================="
    echo "          Instalador do Wine (codigo-fonte oficial WineHQ)                "
    echo "==========================================================================="
    echo ""

    parse_args "$@"
    check_root
    detect_fedora_version

    log_warning "Este script ira:"
    echo "  1. Instalar dependencias de compilacao"
    echo "  2. Baixar o Wine ${WINE_SERIES}.x de https://dl.winehq.org/wine/source/${WINE_SERIES}.x/"
    echo "  3. Compilar e instalar em $INSTALL_PREFIX"
    echo ""

    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Script abortado pelo usuario."
        exit 0
    fi

    install_build_dependencies
    resolve_wine_version
    download_source
    build_and_install
    print_post_install_notes

    echo ""
    log_success "Script finalizado!"
}

# Executa funcao principal
main "$@"