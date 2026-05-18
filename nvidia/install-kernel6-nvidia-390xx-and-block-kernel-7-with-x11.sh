#!/bin/bash

# Cores para o terminal
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0;m'

echo -e "${AZUL}[1/6] Verificando privilégios de superusuário...${SEM_COR}"
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute o script usando sudo: sudo bash $0${SEM_COR}"
  exit 1
fi

echo -e "${AZUL}[2/6] Bloqueando a chegada do Kernel 7 no DNF...${SEM_COR}"
if ! grep -q "exclude=kernel\*-7\*" /etc/dnf/dnf.conf; then
    echo "exclude=kernel*-7*" >> /etc/dnf/dnf.conf
    echo -e "${VERDE}Sucesso: Parede de bloqueio adicionada ao dnf.conf!${SEM_COR}"
else
    echo -e "${AMARELO}Aviso: dnf.conf já estava configurado para bloquear o Kernel 7.${SEM_COR}"
fi

echo -e "${AZUL}[3/6] Ativando repositório Copr e instalando o X11 do KDE Plasma 6...${SEM_COR}"
# Ativa o repositório oficial da comunidade para trazer o X11 de volta no Fedora moderno
dnf install -y 'dnf-command(copr)'
dnf copr enable -y @kdesig/plasma6-x11-unsupported
dnf install -y plasma-workspace-x11 kwin-x11

echo -e "${AZUL}[4/6] Configurando o Kernel 6 como Boot Padrão...${SEM_COR}"
VERSAO_ATUAL=$(uname -r)
INDICE_ALVO=$(grubby --info=ALL | grep -B1 "$VERSAO_ATUAL" | grep "index=" | cut -d'=' -f2)

if [ ! -z "$INDICE_ALVO" ]; then
    grubby --set-default-index=$INDICE_ALVO
    echo -e "${VERDE}Sucesso: Definido Kernel 6 (Índice $INDICE_ALVO) no GRUB.${SEM_COR}"
else
    grubby --set-default=/boot/vmlinuz-$VERSAO_ATUAL
fi

echo -e "${AZUL}[5/6] Forçando o sistema a iniciar em Modo X11 Automaticamente...${SEM_COR}"
# Identifica o usuário real que rodou o sudo
USUARIO_REAL=${SUDO_USER:-$USER}

# Cria a pasta de configurações do SDDM se não existir
mkdir -p /var/lib/sddm

# Define o "plasma-x11" como a última sessão usada globalmente, forçando o login automático nela
cat <<EOF > /var/lib/sddm/state.conf
[Last]
Session=plasma-x11.desktop
User=$USUARIO_REAL
EOF

echo -e "${VERDE}Sucesso: Interface configurada para abrir em X11 por padrão!${SEM_COR}"

echo -e "${AZUL}[6/6] Recompilando o driver NVIDIA 390xx para o Kernel Atual...${SEM_COR}"
echo -e "${AMARELO}Isso pode levar de 2 a 5 minutos. Não feche o terminal...${SEM_COR}"
dnf remove -y kmod-nvidia-390xx-$(uname -r) >/dev/null 2>&1
akmods --force
dracut --force

echo -e "${VERDE}====================================================${SEM_COR}"
echo -e "${VERDE}       TODO O SISTEMA FOI AJUSTADO COM SUCESSO!${SEM_COR}"
echo -e "${VERDE}====================================================${SEM_COR}"
echo -e "O Kernel 7 foi bloqueado, o X11 foi instalado e ativado por padrão."
echo -e "Reinicie o computador agora para aplicar as mudanças: ${AMARELO}sudo reboot${SEM_COR}"
