#!/bin/bash

# Cores para o terminal
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0;m'

echo -e "${AZUL}[1/4] Verificando privilégios de superusuário...${SEM_COR}"
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Erro: Execute o script usando sudo: sudo bash $0${SEM_COR}"
  exit 1
fi

echo -e "${AZUL}[2/4] Garantindo pacotes do GNOME X11 e ferramentas NVIDIA...${SEM_COR}"
# Instala o suporte X11 para o GNOME e garante o pacote CUDA que traz o 'nvidia-smi'
dnf install -y gnome-session-xsession xorg-x11-drv-nvidia-390xx-cuda akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx

echo -e "${AZUL}[3/4] Forçando o GDM (Gerenciador do GNOME) a entrar em modo X11...${SEM_COR}"
USUARIO_REAL=${SUDO_USER:-$USER}

# Configura a sessão padrão do seu usuário para o GNOME sob X11 (em vez de Wayland)
mkdir -p /var/lib/AccountsService/users/
cat <<EOF > /var/lib/AccountsService/users/$USUARIO_REAL
[User]
Session=gnome-xorg
Icon=/home/$USUARIO_REAL/.face
SystemAccount=false
EOF

echo -e "${VERDE}Sucesso: GNOME configurado para iniciar via Xorg (X11).${SEM_COR}"

echo -e "${AZUL}[4/4] Recompilando o módulo do driver 390xx no Kernel atual...${SEM_COR}"
echo -e "${AMARELO}Este processo reconstrói o driver. Aguarde de 2 a 5 minutos...${SEM_COR}"
dnf remove -y kmod-nvidia-390xx-$(uname -r) >/dev/null 2>&1
akmods --force
dracut --force

echo -e "${VERDE}====================================================${SEM_COR}"
echo -e "${VERDE}       CONCLUÍDO! O GNOME AGORA ESTÁ SEGURO.${SEM_COR}"
echo -e "${VERDE}====================================================${SEM_COR}"
echo -e "O bloqueio do Kernel 7 continua ativo no seu dnf.conf."
echo -e "Reinicie o computador ag
