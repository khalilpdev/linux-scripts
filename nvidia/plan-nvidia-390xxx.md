# Guia Definitivo: Nvidia 390xx Silenciosa e Estável no Fedora (KDE)

Este guia consolida a configuração necessária para manter o driver legado **Nvidia 390xx** funcionando perfeitamente na ramificação do **Kernel 6** (bloqueando o Kernel 7), garantindo que a placa de vídeo permaneça completamente desligada/silenciosa até que um jogo seja iniciado via Steam.

---

## 🛠️ Passo 1: Travar o Sistema no Kernel 6 e Instalar o Driver

### 1. Inicie no Kernel 6
Reinicie o computador e, na tela do menu do **GRUB**, selecione manualmente a última versão disponível do **Kernel 6.x**.

### 2. Remova o Kernel 7 e Bloqueie Atualizações
Abra o terminal e execute os comandos abaixo para limpar o Kernel 7 e impedir que o Fedora tente instalá-lo novamente:
```bash
# Remove pacotes do Kernel 7
sudo dnf remove kernel*7.*

# Bloqueia permanentemente atualizações de Kernel no DNF
sudo dnf config-manager --save --setopt=exclude="kernel*"
```

### 3. Instalação Limpa do Driver 390xx
Limpe qualquer resquício anterior e force a compilação do driver para o Kernel 6 atual:
```bash
# Remove instalações parciais anteriores
sudo dnf remove \*nvidia\* --exclude nvidia-gpu-firmware

# Instala o driver v390xx do RPM Fusion
sudo dnf install xorg-x11-drv-nvidia-390xx akmod-nvidia-390xx

# Força a compilação imediata do módulo
sudo akmods --force
```

---

## 🤫 Passo 2: Configurar o Silenciamento da GPU (Gerenciamento de Energia)

Para garantir que a ventoinha e o chip da Nvidia fiquem desligados enquanto você usa o KDE e a Intel integrada, aplique as regras de suspensão PCI:

### 1. Habilitar Gerenciamento no Driver
```bash
sudo nano /etc/modprobe.d/nvidia-power-management.conf
```
Cole a linha abaixo dentro do arquivo, salve (`Ctrl+O`, `Enter`) e saia (`Ctrl+X`):
```text
options nvidia NVreg_DynamicPowerManagement=0x02
```

### 2. Criar Regra de Hardware (Udev)
```bash
sudo nano /etc/udev/rules.d/80-nvidia-pm.rules
```
Cole o seguinte bloco de código, salve e saia:
```text
# Desliga a GPU Nvidia quando estiver ociosa
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="auto"
```

### 3. Atualizar o Sistema e Reiniciar
```bash
sudo dracut --force
sudo reboot
```

---

## 🎮 Passo 3: Executar Jogos na Nvidia (PRIME Offload)

A placa ficará dormindo. Para acordá-la apenas para o seu jogo na **Steam** (Ex: Ultra Street Fighter IV):
1. Abra a Steam, clique com o botão direito no jogo e vá em **Propriedades**.
2. Em **Opções de Inicialização** (Launch Options), cole exatamente:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

---

## 🤖 Prompts de IA Prontos para Diagnóstico e Suporte

Se algo der errado no futuro, não formate a máquina. Copie e cole os prompts abaixo em uma IA para obter a solução exata baseada nos logs do seu terminal:

### Prompt 1: Se o comando `akmods` falhar ou o driver não carregar
> "Estou usando o Fedora com Kernel 6 e tentando compilar o driver legado Nvidia 390xx via akmod. O comando `sudo akmods --force` falhou. Vou te enviar a saída do comando `sudo akmods --view-log` e os logs de erro do terminal. Analise o erro de compilação e me diga quais pacotes, cabeçalhos de kernel (headers) ou patches específicos eu preciso aplicar para corrigir a sintaxe do código."

### Prompt 2: Se a placa continuar barulhenta/quente (Não silenciar)
> "Instalei o driver Nvidia 390xx no Fedora Kernel 6 e configurei as regras de udev e modprobe para `NVreg_DynamicPowerManagement=0x02`. No entanto, a placa parece não estar entrando em modo de suspensão de energia profunda (D3) e a ventoinha continua girando rápido. O comando `cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status` (substitua pelo endereço da sua placa se souber) retorna [COLE O RETORNO AQUI]. O que está impedindo a GPU de dormir?"

### Prompt 3: Se o jogo fechar sozinho ou não abrir com PRIME Offload
> "Estou tentando rodar um jogo na Steam via Proton usando o comando de inicialização `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%` em uma placa Nvidia antiga (driver 390xx) no Fedora. O jogo fecha imediatamente ao abrir. Vou te mandar as últimas 50 linhas do log de erro da Steam obtido rodando `steam` pelo terminal. Identifique se o problema é uma quebra de biblioteca de 32 bits (multilib), falha de Direct3D/Vulkan ou se o driver não foi encontrado pelo Wine/Proton."
