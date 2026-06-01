#!/usr/bin/env bash
set -euo pipefail

check_root() {
  if [ "${EUID}" -eq 0 ]; then
    echo "ERRO: nao execute este script como root."
    echo "Use um usuario normal; o script usa sudo internamente."
    exit 1
  fi
}

check_fedora() {
  if [ ! -f /etc/fedora-release ] || ! command -v rpm >/dev/null 2>&1; then
    echo "ERRO: este script foi feito para Fedora."
    exit 1
  fi
}

require_sudo() {
  if ! sudo -v; then
    echo "ERRO: falha ao obter permissoes sudo."
    exit 1
  fi
}

add_docker_repo() {
  echo "Adicionando repositorio oficial do Docker..."
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
}

install_docker_cli() {
  echo "Instalando Docker CLI e plugins (apenas o runtime, sem o daemon)..."
  sudo dnf install -y docker-ce-cli docker-compose-plugin
}

configure_user() {
  if getent group docker >/dev/null 2>&1; then
    echo "Adicionando usuario ao grupo 'docker'..."
    sudo usermod -aG docker "${USER}"
  fi
}

validate_install() {
  echo "Validando instalacao..."
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERRO: comando 'docker' nao encontrado."
    exit 1
  fi
  docker --version
  docker compose version
}

post_notes() {
  cat <<'EOF'

Concluido.

Apenas o Docker CLI foi instalado (sem o daemon). Isso e o suficiente para
usar o socket Docker do host mapeado no container.

Para que as alteracoes de grupo tenham efeito:
  exec sg docker -c "bash --login"

Lembre-se de montar o socket ao iniciar o container:
  -v /var/run/docker.sock:/var/run/docker.sock

Teste com: docker ps
EOF
}

main() {
  check_root
  check_fedora
  require_sudo
  add_docker_repo
  install_docker_cli
  configure_user
  validate_install
  post_notes
}

main "$@"
