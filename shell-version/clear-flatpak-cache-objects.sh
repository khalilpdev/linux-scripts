#!/bin/bash

# Script para remover com segurança o conteúdo da pasta objects do flatpak
# Localização típica: /var/lib/flatpak/repo/objects

set -e  # Sai do script se algum comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script precisa ser executado como root (sudo)"
    echo "Execute: sudo $0"
    exit 1
fi

# Caminho da pasta objects do flatpak
OBJECTS_PATH="/var/lib/flatpak/repo/objects"

# Verificar se a pasta existe
if [[ ! -d "$OBJECTS_PATH" ]]; then
    log_error "Pasta não encontrada: $OBJECTS_PATH"
    log_info "Verificando localizações alternativas..."
    
    # Verificar localizações alternativas
    ALTERNATIVE_PATHS=(
        "/var/lib/flatpak/repo/objects"
        "/var/lib/flatpak/.ro/objects"
        "$HOME/.local/share/flatpak/repo/objects"
    )
    
    for path in "${ALTERNATIVE_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            OBJECTS_PATH="$path"
            log_info "Encontrado em: $OBJECTS_PATH"
            break
        fi
    done
    
    if [[ ! -d "$OBJECTS_PATH" ]]; then
        log_error "Nenhuma pasta objects do flatpak encontrada"
        exit 1
    fi
fi

# Mostrar informações atuais
log_info "=== INFORMAÇÕES ATUAIS ==="
log_info "Localização: $OBJECTS_PATH"
log_info "Tamanho atual: $(du -sh "$OBJECTS_PATH" 2>/dev/null | cut -f1 || echo 'N/A')"
log_info "Número de itens: $(find "$OBJECTS_PATH" -type f 2>/dev/null | wc -l)"

echo ""
log_warn "!!! ATENÇÃO !!!"
log_warn "Isso removerá o cache de objetos do flatpak"
log_warn "Os aplicativos flatpak ainda funcionarão, mas"
log_warn "podem levar mais tempo para iniciar na primeira vez"
echo ""

# Confirmar com o usuário
read -p "Deseja continuar? (sim/nao): " confirmation

if [[ "$confirmation" != "sim" ]]; then
    log_info "Operação cancelada pelo usuário"
    exit 0
fi

# Criar backup da estrutura (apenas pastas vazias)
BACKUP_DIR="/tmp/flatpak_objects_backup_$(date +%Y%m%d_%H%M%S)"
log_info "Criando backup da estrutura em: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Salvar estrutura de diretórios (sem os arquivos)
find "$OBJECTS_PATH" -type d > "$BACKUP_DIR/directory_structure.txt"

# Parar serviços flatpak relacionados (se existirem)
log_info "Parando serviços flatpak..."
systemctl stop flatpak-system-helper.service 2>/dev/null || true
systemctl stop flatpak-update.service 2>/dev/null || true
systemctl stop flatpak-add-fedora-repo.service 2>/dev/null || true

# Método seguro: remover apenas arquivos, manter diretórios
log_info "Removendo arquivos objects de forma segura..."

# Remover apenas arquivos, não diretórios
find "$OBJECTS_PATH" -type f -delete 2>/dev/null

# Verificar se a remoção foi bem sucedida
if [[ $? -eq 0 ]]; then
    log_info "Arquivos removidos com sucesso!"
else
    log_error "Erro ao remover alguns arquivos"
fi

# Contar diretórios vazios restantes (opcional, não remover)
EMPTY_DIRS=$(find "$OBJECTS_PATH" -type d -empty 2>/dev/null | wc -l)
log_info "Diretórios vazios: $EMPTY_DIRS (mantidos intencionalmente)"

# Mostrar informações após remoção
echo ""
log_info "=== INFORMAÇÕES APÓS LIMPEZA ==="
log_info "Tamanho atual: $(du -sh "$OBJECTS_PATH" 2>/dev/null | cut -f1 || echo '0')"
log_info "Itens restantes: $(find "$OBJECTS_PATH" -type f 2>/dev/null | wc -l)"

# Reiniciar serviços
log_info "Reiniciando serviços flatpak..."
systemctl start flatpak-system-helper.service 2>/dev/null || true

# Verificar integridade do flatpak (opcional)
log_info "Verificando instalação do flatpak..."
if command -v flatpak &> /dev/null; then
    flatpak repair --user 2>/dev/null || log_warn "Reparo do flatpak user falhou"
    flatpak repair --system 2>/dev/null || log_warn "Reparo do flatpak system falhou"
fi

echo ""
log_info "=== LIMPEZA CONCLUÍDA ==="
log_info "Backup da estrutura salvo em: $BACKUP_DIR"
log_info "Para restaurar a estrutura (não os dados), use:"
log_info "  xargs mkdir -p < $BACKUP_DIR/directory_structure.txt"
echo ""
log_warn "Recomendação: Reinicie o sistema para garantir que tudo funcione corretamente"

# Perguntar se quer reiniciar
read -p "Deseja reiniciar o sistema agora? (sim/nao): " restart_choice
if [[ "$restart_choice" == "sim" ]]; then
    log_info "Reiniciando sistema em 5 segundos..."
    sleep 5
    reboot
else
    log_info "Lembre-se de reiniciar o sistema quando possível"
fi

exit 0