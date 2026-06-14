#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# install-java-sdk-21-linux-mint.sh
# Instala Oracle JDK 21 no Linux Mint 21 e configura JAVA_HOME/PATH
# ============================================================

check_root() {
  if [ "${EUID}" -eq 0 ]; then
    echo "❌ Não execute este script como root."
    echo "Use um usuário normal (o script usa sudo internamente)."
    exit 1
  fi
}

check_linux_mint() {
  if [ ! -f /etc/os-release ]; then
    echo "❌ Não foi possível identificar o sistema operacional."
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [ "${ID:-}" != "linuxmint" ]; then
    echo "❌ Este script é destinado ao Linux Mint."
    exit 1
  fi

  local mint_major_version="${VERSION_ID%%.*}"
  echo "ℹ️ Sistema detectado: Linux Mint ${VERSION_ID:-desconhecido}"

  if [ "${mint_major_version}" != "21" ]; then
    echo "⚠️ Este script foi criado para o Linux Mint 21."
    read -r -p "Deseja continuar mesmo assim? (s/N): " reply
    if [[ ! "${reply}" =~ ^[Ss]$ ]]; then
      exit 1
    fi
  fi
}

require_sudo() {
  if ! sudo -v; then
    echo "❌ Falha ao obter permissões sudo."
    exit 1
  fi
}

install_dependencies() {
  echo "📦 Instalando dependências..."
  sudo apt-get update
  sudo apt-get install -y wget ca-certificates
}

install_oracle_jdk21() {
  local jdk_url="https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb"
  local tmp_deb="/tmp/jdk-21_linux-x64_bin.deb"
  local jdk_link="/opt/java/jdk-21"

  echo "⬇️ Baixando Oracle JDK 21..."
  wget --progress=bar:force -O "${tmp_deb}" "${jdk_url}"

  echo "📦 Instalando Oracle JDK 21 via DEB..."
  if ! sudo dpkg -i "${tmp_deb}"; then
    echo "ℹ️ Resolvendo dependências pendentes do pacote..."
    sudo apt-get install -f -y
  fi

  rm -f "${tmp_deb}"

  local jdk_real
  jdk_real="$(dirname "$(dirname "$(readlink -f /usr/bin/javac)")")"

  if [ -z "${jdk_real}" ] || [ ! -d "${jdk_real}" ]; then
    echo "❌ Não foi possível detectar o diretório do JDK instalado."
    exit 1
  fi

  echo "🔗 Criando link simbólico ${jdk_link} -> ${jdk_real}..."
  sudo mkdir -p /opt/java
  sudo ln -sfn "${jdk_real}" "${jdk_link}"

  echo "🌍 Configurando JAVA_HOME global..."
  sudo tee /etc/profile.d/java.sh >/dev/null <<'EOF'
export JAVA_HOME=/opt/java/jdk-21
export PATH=$JAVA_HOME/bin:$PATH
EOF
  sudo chmod 0644 /etc/profile.d/java.sh
}

validate_install() {
  echo "✅ Validando instalação..."
  export JAVA_HOME=/opt/java/jdk-21
  export PATH="${JAVA_HOME}/bin:${PATH}"

  if ! command -v java >/dev/null 2>&1; then
    echo "❌ java não encontrado no PATH."
    exit 1
  fi

  if ! command -v javac >/dev/null 2>&1; then
    echo "❌ javac não encontrado no PATH."
    exit 1
  fi

  if ! command -v jar >/dev/null 2>&1; then
    echo "❌ jar não encontrado no PATH."
    exit 1
  fi

  java -version
  javac -version
  jar --version
}

post_notes() {
  cat <<'EOF'

🎉 Oracle JDK 21 instalado com sucesso.

Próximos passos:
1) Reabra o terminal (ou rode: source /etc/profile.d/java.sh)
2) Teste:
   echo $JAVA_HOME
   which java
   which jar

3) Build MAUI Android (forçando JDK correto):
   dotnet build src/TrendNews.App/TrendNews.App.csproj -f net10.0-android -c Release -p:JavaSdkDirectory=/opt/java/jdk-21

Se você usa script run-android-linux.sh, inclua:
   export JAVA_HOME=/opt/java/jdk-21
   export PATH="$JAVA_HOME/bin:$PATH"
e no dotnet build/publish:
   -p:JavaSdkDirectory="$JAVA_HOME"
EOF
}

main() {
  check_root
  check_linux_mint
  require_sudo
  install_dependencies
  install_oracle_jdk21
  validate_install
  post_notes
}

main "$@"
