#!/bin/bash
# =============================================================================
# Script: fix_wine_exception.sh
# Descrição: Corrige o erro c0000409 no Wine (exception handler)
# Problema: wine-staging 11.0 tem bug na implementação do vcruntime
# Solução: Instala versão corrigida ou aplica winetricks workaround
# Autor: Leandro Khalil
# Data: $(date +%Y-%m-%d)
# =============================================================================

set -e  # Sai se qualquer comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de logging
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

# Verifica se está rodando como root
check_root() {
    if [ "$EUID" -eq 0 ]; then 
        log_warning "Este script está rodando como root. Recomendo executar como usuário normal."
        log_warning "O Wine deve ser instalado pelo usuário, não pelo root."
        read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

# Detecta versão do Fedora
detect_fedora_version() {
    if [ -f /etc/fedora-release ]; then
        FEDORA_VERSION=$(rpm -E %fedora)
        log_info "Fedora versão $FEDORA_VERSION detectada"
    else
        log_error "Sistema não parece ser Fedora. Abortando."
        exit 1
    fi
}

# Verifica se wine está instalado
check_wine_installed() {
    if command -v wine &> /dev/null; then
        CURRENT_WINE=$(wine --version 2>/dev/null | head -1)
        log_info "Wine atual: $CURRENT_WINE"
        
        if [[ "$CURRENT_WINE" == *"11.0"* && "$CURRENT_WINE" =~ [Ss]taging ]]; then
            log_warning "Versão problemática (staging 11.0) detectada!"
            return 0
        else
            log_info "Sua versão do Wine pode já estar corrigida."
            read -p "Deseja reinstalar/atualizar mesmo assim? (s/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                log_info "Script abortado pelo usuário."
                exit 0
            fi
        fi
    else
        log_info "Wine não está instalado. Instalando do zero..."
    fi
}

# Backup do prefixo Wine
backup_wine_prefix() {
    if [ -d "$HOME/.wine" ]; then
        read -p "Deseja fazer backup da pasta ~/.wine antes de continuar? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            log_info "Backup da pasta ~/.wine ignorado por escolha do usuário"
            return 0
        fi

        BACKUP_DIR="$HOME/.wine.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Fazendo backup do prefixo Wine para: $BACKUP_DIR"
        mv "$HOME/.wine" "$BACKUP_DIR"
        log_success "Backup concluído"
    else
        log_info "Nenhum prefixo Wine encontrado para backup"
    fi
}

# Retorna sucesso (0) se a versão problemática estiver ativa
is_problematic_wine() {
    local version
    version=$(wine --version 2>/dev/null | head -1)

    if [[ "$version" == *"11.0"* && "$version" =~ [Ss]taging ]]; then
        return 0
    fi

    return 1
}

# Método 1: Instalar Wine corrigido via WineHQ
install_wine_corrected() {
    log_info "Método 1: Instalando versão corrigida do Wine via WineHQ"
    
    # Adiciona repositório WineHQ se não existir
    if [ ! -f /etc/yum.repos.d/winehq.repo ]; then
        log_info "Adicionando repositório WineHQ..."
        sudo dnf config-manager --add-repo "https://dl.winehq.org/wine-builds/fedora/$FEDORA_VERSION/winehq.repo"
    fi
    
    # Atualiza cache
    sudo dnf makecache
    
    # Remove versões antigas problemáticas (pacotes Fedora e WineHQ)
    log_info "Removendo versões antigas do Wine..."
    sudo dnf remove -y 'wine*' 'winehq*' 2>/dev/null || true
    
    # Instala versão estável mais recente (recomendada)
    log_info "Instalando WineHQ Stable (versão corrigida)..."
    if ! sudo dnf install -y winehq-stable; then
        log_warning "Falha ao instalar winehq-stable. Tentando winehq-devel..."
        sudo dnf install -y winehq-devel
    fi
    
    # Verifica instalação
    if command -v wine &> /dev/null; then
        NEW_VERSION=$(wine --version 2>/dev/null | head -1)
        log_success "Wine instalado: $NEW_VERSION"
        
        # Verifica se a versão não é a problemática 11.0
        if [[ "$NEW_VERSION" =~ ([0-9]+)\.([0-9]+) ]]; then
            MAJOR=${BASH_REMATCH[1]}
            MINOR=${BASH_REMATCH[2]}

            # Se caiu na 11.0 Staging, tenta trocar para devel automaticamente
            if is_problematic_wine; then
                log_warning "Wine 11.0 detectado após instalação. Tentando WineHQ Devel..."
                sudo dnf remove -y 'wine*' 'winehq*' 2>/dev/null || true
                sudo dnf install -y winehq-devel

                NEW_VERSION=$(wine --version 2>/dev/null | head -1)
                log_info "Versão após fallback para Devel: $NEW_VERSION"

                if [[ "$NEW_VERSION" =~ ([0-9]+)\.([0-9]+) ]]; then
                    MAJOR=${BASH_REMATCH[1]}
                    MINOR=${BASH_REMATCH[2]}
                fi
            fi

            if is_problematic_wine; then
                log_warning "Versão problemática ainda ativa: $NEW_VERSION"
                return 1
            fi

            if [ "$MAJOR" -gt 11 ] || ([ "$MAJOR" -eq 11 ] && [ "$MINOR" -gt 0 ]); then
                log_success "Versão corrigida instalada com sucesso!"
                return 0
            else
                log_warning "Versão ainda pode ter o bug. Versão: $NEW_VERSION"
                return 1
            fi
        fi
    else
        log_error "Falha na instalação do Wine"
        return 1
    fi
}

# Método 1.5: Tenta instalar Wine 10.x automaticamente
install_wine_10_fallback() {
    local version
    local candidate
    local has_candidate
    local compat_version

    log_info "Tentando instalar Wine 10.x automaticamente..."

    # Garante que o repositório WineHQ esteja configurado
    if [ ! -f /etc/yum.repos.d/winehq.repo ]; then
        log_info "Adicionando repositório WineHQ para buscar Wine 10.x..."
        sudo dnf config-manager --add-repo "https://dl.winehq.org/wine-builds/fedora/$FEDORA_VERSION/winehq.repo"
    fi

    sudo dnf makecache

    # Remove qualquer Wine instalado para evitar conflito de dependências
    sudo dnf remove -y 'wine*' 'winehq*' 2>/dev/null || true

    # Tenta padrões de pacotes 10.x, do mais específico ao mais amplo
    for candidate in 'winehq-stable-10*' 'winehq-devel-10*' 'wine-10*'; do
        has_candidate=$(dnf -q list --available "$candidate" 2>/dev/null | grep -E '^wine' | head -n 1 || true)
        if [ -z "$has_candidate" ]; then
            continue
        fi

        log_info "Tentando instalar pacote: $candidate"
        if sudo dnf install -y --allowerasing --skip-unavailable "$candidate"; then
            if command -v wine &> /dev/null; then
                version=$(wine --version 2>/dev/null | head -1)
                log_info "Versão detectada após tentativa: $version"

                if [[ "$version" =~ ^wine-10\. ]]; then
                    log_success "Wine 10.x instalado com sucesso!"
                    return 0
                fi
            fi
        fi
    done

    # Plano B: tenta devel sem fixar major, caso 10.x não exista no repositório
    log_warning "Nenhum pacote 10.x disponível nos repositórios atuais. Tentando winehq-devel..."
    if sudo dnf install -y --allowerasing winehq-devel; then
        if command -v wine &> /dev/null; then
            version=$(wine --version 2>/dev/null | head -1)
            log_info "Versão detectada após plano B (devel): $version"
            if ! is_problematic_wine; then
                log_success "Wine alternativo instalado com sucesso (winehq-devel)."
                return 0
            fi
        fi
    fi

    # Plano C: os pacotes WineHQ compilados contra FFmpeg 6.x não instalam no Fedora 44+
    # (libavcodec.so.61 não existe, só libavcodec.so.62+). Usamos Flatpak como último
    # recurso — ele traz suas próprias libs e ignora o FFmpeg do sistema.
    log_warning "Pacotes WineHQ requerem libavcodec.so.61 (FFmpeg 6.x) ausente no Fedora ${FEDORA_VERSION}."
    log_warning "Plano C: instalando Wine via Flatpak (runtime isolado, sem conflito de FFmpeg)..."

    if ! command -v flatpak &> /dev/null; then
        log_info "Instalando flatpak..."
        sudo dnf install -y flatpak
    fi

    # Garante repositório Flathub
    if ! flatpak remotes | grep -q flathub; then
        log_info "Adicionando repositório Flathub..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    log_info "Instalando Wine via Flatpak (org.winehq.Wine)..."
    if flatpak install -y flathub org.winehq.Wine; then
        log_success "Wine instalado via Flatpak com sucesso!"
        echo ""
        log_info "Para usar o Wine Flatpak, substitua 'wine' por:"
        echo "  flatpak run org.winehq.Wine seu_programa.exe"
        echo ""
        log_info "Atalho: adicione ao ~/.bashrc:"
        echo "  alias wine='flatpak run org.winehq.Wine'"
        return 0
    fi

    log_warning "Não foi possível instalar Wine 10.x automaticamente com os repositórios atuais."
    return 1
}

# Método 2: Workaround com winetricks (se o método 1 falhar)
apply_winetricks_workaround() {
    log_info "Método 2: Aplicando workaround com winetricks"
    
    # Instala winetricks se não existir
    if ! command -v winetricks &> /dev/null; then
        log_info "Instalando winetricks..."
        sudo dnf install -y winetricks
    fi
    
    # Verifica/cria prefixo
    if [ ! -d "$HOME/.wine" ]; then
        log_info "Criando novo prefixo Wine..."
        wineboot -u 2>/dev/null || true
        sleep 2
    fi
    
    # Instala vcrun2022 (contém a DLL corrigida)
    log_info "Instalando vcrun2022 (Visual C++ 2022 Runtime)..."
    winetricks -q vcrun2022
    
    if [ $? -eq 0 ]; then
        log_success "vcrun2022 instalado com sucesso"
        
        # Configura para usar DLL nativa
        log_info "Configurando Wine para usar DLL nativa..."
        cat > "$HOME/.wine/user.reg.patch" << 'EOF'
[Software\\Wine\\DllOverrides] 1668358782
"vcruntime140"="native,builtin"
"vcruntime140_1"="native,builtin"
"msvcp140"="native,builtin"
EOF
        log_success "Workaround aplicado com sucesso"
        return 0
    else
        log_error "Falha ao instalar vcrun2022"
        return 1
    fi
}

# Limpa cache de DLL problemáticas
clean_wine_cache() {
    log_info "Limpando cache do Wine..."
    
    # Remove cache de DLL compiladas
    rm -rf "$HOME/.wine/drive_c/windows/system32/wbem/logs/" 2>/dev/null || true
    rm -rf "$HOME/.wine/dosdevices/z:/tmp/.wine-*" 2>/dev/null || true
    
    # Força recriação do registro
    wineboot -u 2>/dev/null || true
    
    log_success "Cache limpo"
}

# Função principal
main() {
    echo "==========================================================================="
    echo "        Correção do Erro c0000409 no Wine (Exception Handler)            "
    echo "==========================================================================="
    echo ""
    
    check_root
    detect_fedora_version
    check_wine_installed
    
    echo ""
    log_warning "Este script irá:"
    echo "  1. Remover versões problemáticas do Wine"
    echo "  2. Perguntar se deve fazer backup do seu prefixo ~/.wine (se existir)"
    echo "  3. Instalar versão corrigida do Wine"
    echo "  4. Aplicar workaround como fallback"
    echo ""
    
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Script abortado pelo usuário."
        exit 0
    fi
    
    # Faz backup do prefixo
    backup_wine_prefix
    
    # Tenta instalar versão corrigida
    if install_wine_corrected; then
        log_success "Wine corrigido instalado!"
        clean_wine_cache
        
        # Cria prefixo novo
        log_info "Configurando novo prefixo Wine..."
        winecfg 2>/dev/null &
        sleep 3
        
        log_success "Correção aplicada com sucesso!"
        log_info "Recomendo testar seu aplicativo agora."
        
    else
        log_warning "Falha na instalação da versão corrigida. Tentando workaround..."
        
        if apply_winetricks_workaround; then
            clean_wine_cache
            if is_problematic_wine; then
                log_warning "Workaround aplicado, mas o Wine continua em 11.0 Staging."

                if install_wine_10_fallback; then
                    clean_wine_cache
                    log_success "Fallback automático aplicado com sucesso!"
                else
                    log_warning "Tente instalar manualmente uma versão diferente (winehq-devel ou wine-10.x)."
                    exit 1
                fi
            fi

            log_success "Workaround aplicado com sucesso!"
        else
            log_error "Não foi possível corrigir o problema automaticamente."
            echo ""
            echo "Soluções manuais:"
            echo "  1. Use uma versão mais antiga do Wine (ex: 9.0):"
            echo "     sudo dnf install wine-9.0"
            echo ""
            echo "  2. Execute o programa com WINEDLLOVERRIDES:"
            echo "     WINEDLLOVERRIDES=\"vcruntime140=n,b\" wine seu_programa.exe"
            echo ""
            echo "  3. Reporte o problema em: https://bugs.winehq.org"
            exit 1
        fi
    fi
    
    echo ""
    log_success "Script finalizado!"
    log_info "Para testar, execute seu programa com: wine seu_programa.exe"
}

# Executa função principal
main "$@"