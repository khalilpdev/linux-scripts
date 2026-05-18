eu quero instalar o driver mas nao usá-lo, vc me sugeriu o nouveau,Compreendo perfeitamente o seu objetivo. Você quer ter os arquivos do driver proprietário 390xx instalados no sistema para alguma finalidade (ou caso queira usá-lo no futuro), mas manter o Nouveau ativo como o driver principal agora para não quebrar a sua sessão do KDE com Wayland.No entanto, o gerenciador de pacotes do Fedora (dnf) possui um comportamento automático: assim que você instala o pacote xorg-x11-drv-nvidia-390xx, ele joga um arquivo de configuração dentro do sistema que bloqueia (desativa) o Nouveau imediatamente no próximo boot.Para fazer exatamente o que você quer (instalar o driver mas deixá-lo "adormecido"), nós precisamos instalar os pacotes e, logo em seguida, remover manualmente o bloqueio do Nouveau e bloquear o driver da NVIDIA.Script para Instalar o Driver 390xx, mas mantê-lo INATIVO (Usando Nouveau + Wayland)Este script instala o driver proprietário, mas desconfigura a inicialização dele, garantindo que o sistema continue usando o Nouveau e o Wayland normalmente.Abra o terminal.Crie o arquivo do script:bashnano instalar-nvidia-adormecido.sh
Use o código com cuidado.Cole o seguinte código:bash#!/usr/bin/env bash

set -e

echo "=========================================================="
echo "📦 Instalando Driver NVIDIA 390xx em Modo Adormecido..."
echo "⚙️ O sistema continuará usando NOUVEAU + WAYLAND."
echo "=========================================================="

# 1. Verificar privilégios de root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Erro: Execute este script usando sudo."
    exit 1
fi

# 2. Ativar repositórios RPM Fusion (necessários para o driver)
echo "-> Verificando repositórios RPM Fusion..."
dnf install -y https://rpmfusion.org \
               https://rpmfusion.org

# 3. Instalar os pacotes do driver 390xx
echo "-> Baixando e instalando os pacotes do driver 390xx..."
dnf install -y xorg-x11-drv-nvidia-390xx akmod-nvidia-390xx

# 4. Desfazer o bloqueio automático que a instalação faz no Nouveau
echo "-> Forçando a liberação do Nouveau..."
# Remove os arquivos de blacklist criados pelo pacote da NVIDIA
rm -f /etc/modprobe.d/blacklist-nouveau.conf
rm -f /usr/lib/modprobe.d/nvidia-installer-disable-nouveau.conf

# 5. Criar um bloqueio para o driver da NVIDIA não carregar no Boot
echo "-> Bloqueando o driver proprietário NVIDIA para manter o Nouveau ativo..."
cat <<EOF > /etc/modprobe.d/blacklist-nvidia-proprietario.conf
blacklist nvidia
blacklist nvidia-drm
blacklist nvidia-modeset
blacklist nvidia-uvm
EOF

# 6. Atualizar a imagem de boot (Initramfs) para aplicar as regras
echo "-> Atualizando imagem de boot initramfs (Aguarde)..."
dracut --force --verbose

echo "=========================================================="
echo "✅ CONCLUÍDO COM SUCESSO!"
echo "📌 O driver 390xx está instalado no seu disco."
echo "🔄 O Nouveau continua ativo e seu Wayland funcionará normal."
echo "=========================================================="

read -p "Deseja reiniciar para testar o sistema agora? (S/n): " REBOOT_CHOICE
if [[ ! "$REBOOT_CHOICE" =~ ^[nN]$ ]]; then
    reboot
fi
Use o código com cuidado.Como ExecutarSalve o arquivo (Ctrl+O, Enter, Ctrl+X).Dê permissão de execução:bashchmod +x instalar-nvidia-adormecido.sh
Use o código com cuidado.Execute o instalador:bashsudo ./instalar-nvidia-adormecido.sh
Use o código com cuidado.Como isso funciona na prática?Os arquivos e bibliotecas do driver proprietário estarão salvos no seu HD/SSD. Porém, graças ao arquivo criado na etapa 5, o Kernel do Linux vai ignorar a existência deles na hora que você ligar o computador. Quem vai subir controlando a sua placa de vídeo é o Nouveau, permitindo que você use o KDE Plasma com Wayland sem nenhuma falha de vídeo.Se você reiniciar o computador, me avise:O sistema iniciou diretamente na sua área de trabalho em Wayland?Você quer um comando rápido para verificar se o Nouveau realmente continua no comando após o boot?
