#!/bin/bash

# Script para resolver problema de lock do Oh My Bash
# Autor: Leandro Khalil
# Data: $(date +%Y-%m-%d)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
OH_MY_BASH_DIR="$HOME/.oh-my-bash"
LOCK_FILE="$OH_MY_BASH_DIR/log/update.lock"

echo -e "${BLUE}=== Oh My Bash - Solucionador de Problemas de Lock ===${NC}\n"

# Função para verificar se Oh My Bash está instalado
check_installation() {
    if [ ! -d "$OH_MY_BASH_DIR" ]; then
        echo -e "${RED}❌ Oh My Bash não encontrado em: $OH_MY_BASH_DIR${NC}"
        echo -e "${YELLOW}Por favor, verifique se o Oh My Bash está instalado corretamente.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Oh My Bash encontrado${NC}"
}

# Função para verificar processos conflitantes
check_processes() {
    echo -e "\n${BLUE}Verificando processos relacionados ao Oh My Bash...${NC}"
    
    # Procura por processos bash com oh-my-bash em execução
    PROCESSOS=$(ps aux | grep -E "oh-my-bash|check_for_upgrade" | grep -v grep | grep -v "$0")
    
    if [ -n "$PROCESSOS" ]; then
        echo -e "${YELLOW}⚠️  Processos encontrados:${NC}"
        echo "$PROCESSOS"
        echo -e "\n${YELLOW}Deseja finalizar estes processos? (s/N)${NC}"
        read -r resposta
        if [[ "$resposta" =~ ^[Ss]$ ]]; then
            echo "$PROCESSOS" | awk '{print $2}' | xargs kill -9 2>/dev/null
            echo -e "${GREEN}✅ Processos finalizados${NC}"
        fi
    else
        echo -e "${GREEN}✅ Nenhum processo conflitante encontrado${NC}"
    fi
}

# Função para remover o arquivo de lock
remove_lock_file() {
    echo -e "\n${BLUE}Removendo arquivo de lock...${NC}"
    
    if [ -f "$LOCK_FILE" ]; then
        # Tenta remover normalmente
        if rm "$LOCK_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ Arquivo de lock removido com sucesso${NC}"
        else
            # Se falhar, tenta com sudo
            echo -e "${YELLOW}⚠️  Sem permissão, tentando com sudo...${NC}"
            if sudo rm "$LOCK_FILE" 2>/dev/null; then
                echo -e "${GREEN}✅ Arquivo de lock removido com sudo${NC}"
            else
                echo -e "${RED}❌ Falha ao remover o arquivo de lock${NC}"
                echo -e "${YELLOW}Tente remover manualmente: sudo rm $LOCK_FILE${NC}"
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Arquivo de lock não existe (já está limpo)${NC}"
    fi
    return 0
}

# Função para criar diretório log se não existir
ensure_log_dir() {
    local LOG_DIR="$OH_MY_BASH_DIR/log"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "\n${BLUE}Criando diretório log...${NC}"
        mkdir -p "$LOG_DIR"
        echo -e "${GREEN}✅ Diretório log criado${NC}"
    fi
}

# Função para verificar integridade do Oh My Bash
check_integrity() {
    echo -e "\n${BLUE}Verificando integridade do Oh My Bash...${NC}"
    
    cd "$OH_MY_BASH_DIR" || return 1
    
    # Verifica se é um repositório git válido
    if [ -d ".git" ]; then
        echo -e "${GREEN}✅ Repositório git válido${NC}"
        
        # Verifica se há conflitos de merge
        if git status --porcelain | grep -q "^UU"; then
            echo -e "${YELLOW}⚠️  Conflitos de merge detectados${NC}"
            echo -e "${YELLOW}Deseja resolver abortando o merge? (s/N)${NC}"
            read -r resposta
            if [[ "$resposta" =~ ^[Ss]$ ]]; then
                git merge --abort 2>/dev/null
                echo -e "${GREEN}✅ Merge abortado${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Não é um repositório git válido${NC}"
    fi
}

# Função para desabilitar verificações automáticas (opcional)
disable_auto_update() {
    BASHRC="$HOME/.bashrc"
    
    if grep -q "DISABLE_AUTO_UPDATE" "$BASHRC"; then
        echo -e "\n${GREEN}✅ AUTO_UPDATE já configurado no .bashrc${NC}"
    else
        echo -e "\n${BLUE}Deseja desabilitar verificações automáticas de atualização? (s/N)${NC}"
        echo -e "${YELLOW}Isso evitará problemas futuros com lock${NC}"
        read -r resposta
        if [[ "$resposta" =~ ^[Ss]$ ]]; then
            echo -e "\n# Desabilitar verificações automáticas do Oh My Bash" >> "$BASHRC"
            echo "export DISABLE_AUTO_UPDATE=\"true\"" >> "$BASHRC"
            echo -e "${GREEN}✅ Verificações automáticas desabilitadas${NC}"
            echo -e "${YELLOW}⚠️  Recarregue o terminal para aplicar as mudanças${NC}"
        fi
    fi
}

# Função para recarregar configuração
reload_shell() {
    echo -e "\n${BLUE}Deseja recarregar o shell agora? (s/N)${NC}"
    read -r resposta
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}Recarregando shell...${NC}"
        exec bash
    else
        echo -e "${YELLOW}Lembre-se de executar: source ~/.bashrc${NC}"
    fi
}

# Função principal
main() {
    check_installation
    check_processes
    ensure_log_dir
    remove_lock_file || exit 1
    check_integrity
    disable_auto_update
    reload_shell
    
    echo -e "\n${GREEN}✅ Problema resolvido com sucesso!${NC}"
}

# Executa o script
main
