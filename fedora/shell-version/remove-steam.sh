#!/bin/bash

# Script para remover completamente o Steam e seus jogos do Fedora
# Execute com sudo ou como root

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}   REMOÇÃO COMPLETA DO STEAM - FEDORA   ${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}Este script precisa ser executado como root.${NC}" 
   echo -e "Use: sudo $0"
   exit 1
fi

# Função para confirmar ação
confirmar() {
    read -p "$1 (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Operação cancelada.${NC}"
        exit 1
    fi
}

echo -e "${RED}⚠️  ATENÇÃO: Este script irá remover:${NC}"
echo "  • Pacotes do Steam"
echo "  • Todos os jogos instalados via Steam"
echo "  • Configurações do Steam"
echo "  • Dados de cache e compatibilidade (Proton)"
echo "  • Diretórios de instalação dos jogos"
echo ""

confirmar "Deseja realmente continuar com a remoção?"

# 1. Matar processos do Steam
echo -e "\n${GREEN}[1/7] Finalizando processos do Steam...${NC}"
killall steam 2>/dev/null
killall steamwebhelper 2>/dev/null
sleep 2

# 2. Remover pacotes do Steam
echo -e "\n${GREEN}[2/7] Removendo pacotes do Steam...${NC}"
dnf remove -y steam steam-devices steam-libs

# Limpar dependências não utilizadas
echo -e "\n${GREEN}[3/7] Limpando dependências órfãs...${NC}"
dnf autoremove -y

# 3. Encontrar e remover diretórios de jogos
echo -e "\n${GREEN}[4/7] Localizando diretórios de jogos...${NC}"

# Diretórios comuns onde podem estar os jogos
STEAM_DIRS=(
    "$HOME/.steam"
    "$HOME/.local/share/Steam"
    "$HOME/Steam"
    "/usr/local/games/Steam"
    "/opt/steam"
)

# Verificar bibliotecas adicionais configuradas pelo usuário
if [ -f "$HOME/.local/share/Steam/config/libraryfolders.vdf" ]; then
    echo -e "${YELLOW}Bibliotecas Steam adicionais encontradas:${NC}"
    grep -E '"path"' "$HOME/.local/share/Steam/config/libraryfolders.vdf" | sed 's/.*"path"[[:space:]]*"\(.*\)"/\1/'
fi

echo -e "\n${YELLOW}Deseja remover TODOS os diretórios de jogos listados acima?${NC}"
confirmar "Remover jogos e dados do Steam?"

# Remover diretórios principais
for dir in "${STEAM_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Removendo: $dir"
        rm -rf "$dir"
    fi
done

# 4. Limpar configurações do usuário
echo -e "\n${GREEN}[5/7] Removendo configurações do Steam...${NC}"
rm -rf "$HOME/.steam"
rm -rf "$HOME/.steampath"
rm -rf "$HOME/.steampid"
rm -rf "$HOME/.local/share/Steam"
rm -rf "$HOME/.config/steam"
rm -rf "$HOME/.cache/steam"
rm -rf "$HOME/.steam-debian"

# 5. Limpar Proton e compatibilidade
echo -e "\n${GREEN}[6/7] Removendo dados de compatibilidade (Proton)...${NC}"
rm -rf "$HOME/.proton"
rm -rf "$HOME/.cache/Proton"
rm -rf "$HOME/.local/share/Steam/steamapps/compatdata"
rm -rf "$HOME/.local/share/Steam/steamapps/shadercache"

# 6. Limpar cache do sistema
echo -e "\n${GREEN}[7/7] Limpando cache do sistema...${NC}"
dnf clean all

# Opcional: Remover repositórios adicionais do Steam
echo -e "\n${YELLOW}Deseja remover repositórios do Steam adicionados manualmente?${NC}"
confirmar "Remover repositórios?"

if [ -f "/etc/yum.repos.d/steam.repo" ]; then
    rm -f "/etc/yum.repos.d/steam.repo"
    echo "Repositório steam.repo removido"
fi

# Verificar pacotes RPM Fusion
if dnf repolist | grep -q "rpmfusion-nonfree-steam"; then
    dnf config-manager --set-disabled rpmfusion-nonfree-steam 2>/dev/null
    echo "Repositório RPM Fusion Steam desabilitado"
fi

# Relatório final
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}          REMOÇÃO CONCLUÍDA!            ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Resumo da remoção:${NC}"
echo "✓ Pacotes Steam removidos"
echo "✓ Jogos e diretórios removidos"
echo "✓ Configurações removidas"
echo "✓ Cache limpo"
echo ""

# Verificar espaço liberado (aproximado)
echo -e "${GREEN}Para verificar o espaço em disco atual:${NC}"
df -h "$HOME"

echo -e "\n${YELLOW}⚠️  Recomenda-se reiniciar o sistema para completar a limpeza.${NC}"
echo -e "${YELLOW}⚠️  Uma reinicialização também atualizará os atalhos do menu de aplicações.${NC}"
echo -e "\n${GREEN}Obrigado por usar este script!${NC}"