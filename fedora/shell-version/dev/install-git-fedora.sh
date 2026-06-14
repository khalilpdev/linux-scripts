#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# install-git-fedora.sh
# Instala Git no Fedora e faz configuração básica de usuário
# ============================================================

check_root() {
  if [ "${EUID}" -eq 0 ]; then
    echo "❌ Não execute este script como root."
    echo "Use um usuário normal (o script usa sudo internamente)."
    exit 1
  fi
}

check_fedora() {
  if ! command -v rpm >/dev/null 2>&1; then
    echo "❌ Este script é destinado ao Fedora."
    exit 1
  fi
}

require_sudo() {
  if ! sudo -v; then
    echo "❌ Falha ao obter permissões sudo."
    exit 1
  fi
}

install_git() {
  echo "📦 Instalando Git..."
  sudo dnf install -y git
}

configure_git() {
  if [ -z "${GIT_USER_NAME:-}" ]; then
    read -r -p "Digite seu nome para o Git (ex: Seu Nome): " GIT_USER_NAME
  fi
  if [ -z "${GIT_USER_EMAIL:-}" ]; then
    read -r -p "Digite seu email para o Git (ex: email@example.com): " GIT_USER_EMAIL
  fi

  git config --global user.name "${GIT_USER_NAME}"
  git config --global user.email "${GIT_USER_EMAIL}"
  echo "✅ Configuração global do Git definida."
}

validate_install() {
  echo "✅ Validando instalação..."
  if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git não encontrado no PATH."
    exit 1
  fi
  git --version
}

post_notes() {
  cat <<EOF

🎉 Git instalado com sucesso.

Configurações globais:
  user.name  = $(git config --global user.name 2>/dev/null || echo "não definido")
  user.email = $(git config --global user.email 2>/dev/null || echo "não definido")

Dica: configure aliases úteis com:
  git config --global alias.co checkout
  git config --global alias.br branch
  git config --global alias.st status
  git config --global alias.lg "log --oneline --graph --all --decorate"
EOF
}

main() {
  check_root
  check_fedora
  require_sudo
  install_git
  configure_git
  validate_install
  post_notes
}

main "$@"
