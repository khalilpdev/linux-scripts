#!/bin/bash

# Script para instalar todos os codecs no Fedora
# Inclui suporte para RV40 (RealVideo), MP3, H.264, H.265, e muito mais
# Com --skip-unavailable para pular pacotes não disponíveis

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Função para verificar sucesso
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        echo -e "${YELLOW}⚠️  Continuando...${NC}"
    fi
}

# Verificar se está como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Por favor, execute como root:${NC}"
    echo -e "${YELLOW}   sudo ./install-codecs-all.sh${NC}"
    exit 1
fi

print_header "INSTALADOR DE CODECS PARA FEDORA (com --skip-unavailable)"

echo -e "${CYAN}Este script instalará:${NC}"
echo "  ✓ Codecs de áudio (MP3, AAC, FLAC, etc.)"
echo "  ✓ Codecs de vídeo (H.264, H.265, MPEG4, etc.)"
echo "  ✓ Codecs proprietários (RealVideo RV40, WMV, etc.)"
echo "  ✓ Plugins para VLC, GStreamer, FFmpeg"
echo "  ✓ Suporte a DVDs criptografados"
echo ""
echo -e "${YELLOW}⚠️  Observação: Pacotes não disponíveis serão pulados automaticamente${NC}"
echo ""
echo -e "${YELLOW}⚠️  Isenção de responsabilidade: Este script instala codecs proprietários.${NC}"
echo -e "${YELLOW}   Certifique-se de que você tem o direito legal de usá-los no seu país.${NC}"
echo ""
read -p "Deseja continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Instalação cancelada.${NC}"
    exit 0
fi

echo ""

# 1. Atualizar sistema
print_header "📦 ATUALIZANDO SISTEMA"
echo -e "${YELLOW}Atualizando pacotes...${NC}"
dnf update -y --skip-broken
check_success "Sistema atualizado"

# 2. Adicionar RPM Fusion
print_header "➕ ADICIONANDO REPOSITÓRIOS RPM FUSION"

echo -e "${YELLOW}Adicionando RPM Fusion Free...${NC}"
dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    --skip-broken 2>/dev/null
check_success "RPM Fusion Free adicionado"

echo -e "${YELLOW}Adicionando RPM Fusion Non-Free...${NC}"
dnf install -y \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    --skip-broken 2>/dev/null
check_success "RPM Fusion Non-Free adicionado"

# 3. Remover VLC do Flatpak (se instalado) e instalar via RPM
print_header "🎬 REMOVENDO VLC FLATPAK E INSTALANDO VIA RPM"

if flatpak list 2>/dev/null | grep -qi vlc; then
    echo -e "${YELLOW}Removendo VLC do Flatpak...${NC}"
    flatpak uninstall -y org.videolan.VLC 2>/dev/null || \
        flatpak uninstall -y --system org.videolan.VLC 2>/dev/null || \
        echo -e "${YELLOW}⚠️  Não foi possível remover via flatpak, tentando via dnf...${NC}"
    flatpak uninstall -y --unused 2>/dev/null
    check_success "VLC Flatpak removido"
else
    echo -e "${CYAN}VLC Flatpak não encontrado.${NC}"
fi

echo -e "${YELLOW}Instalando VLC via RPM...${NC}"
dnf install -y vlc vlc-extras vlc-plugin-ffmpeg vlc-plugin-bittorrent --skip-unavailable --skip-broken
check_success "VLC RPM instalado"

# 4. Instalando codecs principais
print_header "🎵 INSTALANDO CODECS DE ÁUDIO"

echo -e "${YELLOW}Instalando codecs de áudio (MP3, AAC, etc.)...${NC}"
dnf install -y \
    lame \
    lame-mp3x \
    flac \
    faad2 \
    faac \
    libmad \
    libid3tag \
    libogg \
    libvorbis \
    speex \
    wavpack \
    --skip-unavailable --skip-broken
check_success "Codecs de áudio instalados"

# 5. Instalando codecs de vídeo
print_header "🎬 INSTALANDO CODECS DE VÍDEO"

echo -e "${YELLOW}Instalando codecs de vídeo (H.264, H.265, etc.)...${NC}"
dnf install -y \
    x264 \
    x264-libs \
    x265 \
    x265-libs \
    libavcodec \
    libavformat \
    libavutil \
    libpostproc \
    libswscale \
    libavdevice \
    libavfilter \
    --skip-unavailable --skip-broken
check_success "Codecs de vídeo instalados"

# 6. Codecs específicos para RealVideo (RV40)
print_header "🎥 INSTALANDO CODECS REALVIDEO (RV40)"

echo -e "${YELLOW}Instalando suporte a RealVideo...${NC}"
dnf install -y \
    gstreamer1-libav \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    ffmpeg-libs \
    ffmpeg \
    --skip-unavailable --skip-broken
check_success "Codecs RealVideo instalados"

# 7. Instalando plugins completos do GStreamer
print_header "🎚️ INSTALANDO PLUGINS GSTREAMER"

echo -e "${YELLOW}Instalando plugins GStreamer (good, bad, ugly)...${NC}"
dnf install -y \
    gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras \
    gstreamer1-plugins-ugly \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-libav \
    --skip-unavailable --skip-broken
check_success "Plugins GStreamer instalados"

# 8. Instalar codecs adicionais e suporte a DVDs
print_header "💿 INSTALANDO CODECS ADICIONAIS E DVD"

echo -e "${YELLOW}Instalando suporte a DVDs criptografados...${NC}"
dnf install -y \
    libdvdcss \
    libdvdread \
    libdvdnav \
    lsdvd \
    --skip-unavailable --skip-broken
check_success "Suporte a DVDs instalado"

# 9. Instalar codecs de vídeo adicionais (WMV, QuickTime, etc.)
print_header "🔧 INSTALANDO CODECS LEGADOS"

echo -e "${YELLOW}Instalando codecs para formatos legados...${NC}"
dnf install -y \
    libavcodec-freeworld \
    libquicktime \
    w32codec \
    w64codec \
    xvidcore \
    dirac-libs \
    schroedinger-libs \
    --skip-unavailable --skip-broken
check_success "Codecs legados instalados"

# 10. Instalar codecs adicionais via grupo de pacotes
print_header "📦 INSTALANDO GRUPOS DE MULTIMÍDIA"

echo -e "${YELLOW}Instalando grupo de pacotes de multimídia...${NC}"
dnf group install -y multimedia --skip-broken --skip-unavailable 2>/dev/null
dnf group upgrade -y --with-optional Multimedia --skip-broken --skip-unavailable 2>/dev/null
check_success "Grupos multimídia processados"

# 11. Limpar e atualizar cache de fontes de mídia
print_header "🧹 LIMPANDO E ATUALIZANDO CACHE"

echo -e "${YELLOW}Atualizando cache de bibliotecas...${NC}"
ldconfig
check_success "Cache atualizado"

# 12. Informar sobre reinicialização de aplicativos
print_header "✅ INSTALAÇÃO CONCLUÍDA!"

echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Todos os codecs disponíveis foram instalados!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📌 Para que as mudanças tenham efeito:${NC}"
echo "   • Se você está usando o VLC, feche-o completamente e abra novamente"
echo "   • Se você está usando um navegador, reinicie-o"
echo "   • Para maior certeza, reinicie sua sessão ou o sistema"

echo ""
echo -e "${CYAN}📋 Verifique se os codecs foram instalados:${NC}"
echo "   ffmpeg -codecs | grep -i rv40"
echo "   vlc --list | grep -i real"
echo "   gst-inspect-1.0 | grep -i rv40"

echo ""
echo -e "${YELLOW}⚠️  Se ainda encontrar problemas com o RV40:${NC}"
echo "   O codec pode precisar ser baixado separadamente:"
echo "   sudo dnf install --nogpgcheck https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
echo "   sudo dnf install ffmpeg-libs --skip-unavailable"
echo ""
echo "   Ou converta o vídeo para um formato mais comum:"
echo "   ffmpeg -i video.rv40 -c:v libx264 -c:a aac output.mp4"

echo ""
echo -e "${GREEN}✨ Divirta-se com seus vídeos! ✨${NC}"
echo ""

# Bônus: Verificar instalação
print_header "🔍 VERIFICANDO INSTALAÇÃO"

echo -e "${CYAN}Verificando codec RV40 (RealVideo)...${NC}"
if ffmpeg -codecs 2>/dev/null | grep -qi rv40; then
    echo -e "${GREEN}✅ RV40 detectado!${NC}"
else
    echo -e "${YELLOW}⚠️  RV40 não detectado no ffmpeg.${NC}"
    echo -e "${CYAN}Verificando no GStreamer...${NC}"
    if gst-inspect-1.0 2>/dev/null | grep -qi rv40; then
        echo -e "${GREEN}✅ RV40 detectado no GStreamer!${NC}"
    else
        echo -e "${YELLOW}⚠️  RV40 não encontrado. Tentando método alternativo...${NC}"
        echo -e "${CYAN}Instalando codecs adicionais...${NC}"
        dnf install -y gstreamer1-plugins-bad-nonfree --skip-unavailable 2>/dev/null
    fi
fi

echo ""
echo -e "${YELLOW}Pressione Enter para sair...${NC}"
read