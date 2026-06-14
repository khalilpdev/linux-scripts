#!/bin/bash

# Script simples de limpeza temporária

echo "=== LIMPEZA DE ARQUIVOS TEMPORÁRIOS ==="
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Locais para verificar
declare -A LOCATIONS=(
    ["/tmp"]="Temporários do sistema"
    ["/var/tmp"]="Temporários persistentes"
    ["$HOME/.cache"]="Cache do usuário"
    ["$HOME/.local/share/Trash"]="Lixeira"
    ["/var/cache/dnf"]="Cache do DNF"
)

echo "Verificando arquivos temporários..."
echo ""

# Listar itens encontrados
ITEMS=()
for dir in "${!LOCATIONS[@]}"; do
    if [ -d "$dir" ] && [ "$(ls -A $dir 2>/dev/null)" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓${NC} ${LOCATIONS[$dir]}: $dir - ${YELLOW}$size${NC}"
        ITEMS+=("$dir")
    fi
done

echo ""

if [ ${#ITEMS[@]} -eq 0 ]; then
    echo -e "${GREEN}Nenhum arquivo temporário encontrado!${NC}"
    exit 0
fi

echo ""

# Perguntar um por um
for dir in "${ITEMS[@]}"; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo -e "${YELLOW}📁 ${LOCATIONS[$dir]}${NC}"
    echo -e "   Local: $dir"
    echo -e "   Tamanho: $size"
    read -p "   Limpar? (s/N): " answer
    if [[ $answer =~ ^[Ss]$ ]]; then
        echo -e "   ${GREEN}🧹 Limpando...${NC}"
        rm -rf "$dir"/* 2>/dev/null
        echo -e "   ${GREEN}✅ Limpo!${NC}"
    else
        echo -e "   ${RED}⏭️  Pulando${NC}"
    fi
    echo ""
done

echo -e "${GREEN}✨ Limpeza concluída!${NC}"