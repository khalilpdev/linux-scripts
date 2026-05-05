#!/bin/bash

# Script de instalação do Waydroid no Fedora (incluindo Fedora 44+)
# Uso: chmod +x script.sh && sudo ./script.sh

set -e  # Para o script em caso de erro crítico (opcional)

echo "=== Iniciando instalação/configuração do Waydroid ==="

# Verificar versão do Fedora
FEDORA_VERSION=$(rpm -E %fedora)
echo "Detectado Fedora versão: $FEDORA_VERSION"

# 1. Verificar se Waydroid já está instalado
if command -v waydroid &> /dev/null; then
    echo "[SKIP] Waydroid já instalado. Pulando instalação."
else
    echo "Instalando dependências e Waydroid..."
    
    # Lista de pacotes com nomes corrigidos para Fedora 44
    # pygobject3 no Fedora 44 é python3-gobject / python3-gobject-base
    for pkg in curl wget git lxc python3 jinja2 python3-gobject python3-gobject-base dbus-x11; do
        if rpm -q $pkg &> /dev/null; then
            echo "[SKIP] Pacote $pkg já instalado."
        else
            echo "Instalando $pkg..."
            sudo dnf install -y $pkg || echo "[AVISO] Falha ao instalar $pkg, continuando..."
        fi
    done

    # O repositório correto para Fedora 44 é o do eloitor ou yanqiyu (com suporte a kernels 5.15+)
    # Ambos possuem builds para Fedora 44
    if dnf repolist 2>/dev/null | grep -q "eloitor/waydroid"; then
        echo "[SKIP] Repositório eloitor/waydroid já adicionado."
    else
        echo "Adicionando repositório COPR (eloitor/waydroid)..."
        sudo dnf copr enable -y eloitor/waydroid
    fi

    # Instalar Waydroid
    echo "Instalando Waydroid..."
    sudo dnf install -y waydroid
fi

# 2. Verificar módulos do kernel (Fedora 44 com kernel 6.x+)
echo "Verificando módulos do kernel..."
# No Fedora 44, binder/ashmem podem já estar no kernel padrão como módulos
# Verificar se binder está disponível
if [ -e /dev/binder ] || [ -e /dev/binderfs/binder ]; then
    echo "[SKIP] Dispositivo binder já disponível."
else
    echo "Carregando módulos do kernel..."
    # Para kernels 5.15+, binder/ashmem podem estar disponíveis via módulo
    sudo modprobe ashmem_linux 2>/dev/null || echo "ashmem_linux não encontrado (normal em kernels novos)"
    sudo modprobe binder_linux 2>/dev/null || echo "binder_linux não encontrado, tentando binder..."
    sudo modprobe binder 2>/dev/null || echo "AVISO: Módulos binder não encontrados"
fi

# 3. Configurar permissões do binder (se necessário)
if [ ! -e /dev/binderfs/binder ]; then
    echo "Configurando binderfs..."
    sudo mkdir -p /dev/binderfs
    sudo mount -t binder binder /dev/binderfs 2>/dev/null || echo "AVISO: Não foi possível montar binderfs"
fi

# 4. Inicializar o container Waydroid (se não inicializado)
if [ -d "/var/lib/waydroid" ] && [ -f "/var/lib/waydroid/waydroid.cfg" ]; then
    echo "[SKIP] Waydroid já inicializado."
else
    echo "Inicializando Waydroid (pode demorar alguns minutos)..."
    sudo systemctl enable --now waydroid-container
    
    # Usar as URLs oficiais do Waydroid (recomendado para Fedora 44)
    sudo waydroid init -c https://ota.waydro.id/system -v https://ota.waydro.id/vendor
fi

# 5. Configurar firewall
echo "Configurando firewall..."
if sudo systemctl is-active --quiet firewalld; then
    for porta in 8000 8001 8002 8003 8004 8005; do
        if sudo firewall-cmd --list-ports 2>/dev/null | grep -q "$porta/tcp"; then
            echo "[SKIP] Porta $porta já liberada."
        else
            echo "Liberando porta $porta..."
            sudo firewall-cmd --add-port=$porta/tcp --permanent
        fi
    done
    sudo firewall-cmd --reload
else
    echo "[SKIP] Firewall não está ativo."
fi

# 6. Configuração SELinux para Fedora 44
if getenforce 2>/dev/null | grep -q "Enforcing"; then
    if getsebool domain_can_mmap_files 2>/dev/null | grep -q "on"; then
        echo "[SKIP] SELinux boolean já ativado."
    else
        echo "Configurando SELinux..."
        setsebool -P domain_can_mmap_files 1 2>/dev/null || echo "AVISO: Não foi possível configurar SELinux"
    fi
    # Configuração específica para o eloitor/waydroid (funciona com SELinux enforcing)
    echo "Repositório eloitor/waydroid é compatível com SELinux Enforcing."
else
    echo "[SKIP] SELinux não está em modo Enforcing."
fi

echo ""
echo "=== Instalação concluída! ==="
echo ""
echo "Para iniciar o Waydroid:"
echo "  waydroid session start"
echo ""
echo "Para instalar um APK:"
echo "  waydroid app install /caminho/do/app.apk"
echo ""
echo "Para abrir as configurações do Android:"
echo "  waydroid app start com.android.settings"
echo ""
echo "NOTA: Se tiver problemas com GPU ou Wayland, execute:"
echo "  waydroid prop set persist.waydroid.multi_windows true"