#!/usr/bin/env bash
set -euo pipefail

BLOCK_START="# >>> fedora-scripts go env >>>"
BLOCK_END="# <<< fedora-scripts go env <<<"

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

install_dependencies() {
  echo "Instalando Go, Git e jq..."
  sudo dnf install -y golang git jq
}

update_bashrc() {
  local gopath="$1"
  local bashrc_file="${HOME}/.bashrc"
  local filtered_file
  local new_file

  touch "${bashrc_file}"

  filtered_file="$(mktemp)"
  new_file="$(mktemp)"

  awk -v start="${BLOCK_START}" -v end="${BLOCK_END}" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "${bashrc_file}" > "${filtered_file}"

  cat "${filtered_file}" > "${new_file}"
  {
    printf '\n%s\n' "${BLOCK_START}"
    printf 'export GOPATH="%s"\n' "${gopath}"
    printf 'case ":$PATH:" in\n'
    printf '  *":$GOPATH/bin:"*) ;;\n'
    printf '  *) export PATH="$GOPATH/bin:$PATH" ;;\n'
    printf 'esac\n'
    printf '%s\n' "${BLOCK_END}"
  } >> "${new_file}"

  mv "${new_file}" "${bashrc_file}"
  rm -f "${filtered_file}"
}

configure_go_workspace() {
  local gopath="${HOME}/go"

  echo "Configurando GOPATH em ${gopath}..."
  mkdir -p "${gopath}/bin" "${gopath}/pkg" "${gopath}/src"

  export GOPATH="${gopath}"
  export PATH="${GOPATH}/bin:${PATH}"

  go env -w GOPATH="${gopath}"
  update_bashrc "${gopath}"
}

install_go_tools() {
  echo "Instalando ferramentas do VS Code para Go..."
  go install golang.org/x/tools/gopls@latest
  go install github.com/go-delve/delve/cmd/dlv@latest
}

configure_vscode() {
  local settings_dir="${HOME}/.config/Code/User"
  local settings_file="${settings_dir}/settings.json"
  local base_file
  local temp_file
  local timestamp

  echo "Configurando VS Code para Go..."
  mkdir -p "${settings_dir}"

  base_file="$(mktemp)"
  temp_file="$(mktemp)"

  if [ -f "${settings_file}" ]; then
    timestamp="$(date +%Y%m%d_%H%M%S)"
    cp "${settings_file}" "${settings_file}.backup.${timestamp}"
    cp "${settings_file}" "${base_file}"
  else
    printf '{}\n' > "${base_file}"
  fi

  jq \
    --arg gopath "${HOME}/go" \
    --arg gopath_bin "${HOME}/go/bin" \
    '
      .["go.useLanguageServer"] = true
      | .["go.toolsManagement.autoUpdate"] = true
      | .["go.gopath"] = $gopath
      | .["go.toolsEnvVars"] = ((.["go.toolsEnvVars"] // {}) + {
          "GOPATH": $gopath,
          "PATH": ($gopath_bin + ":" + (.["go.toolsEnvVars"].PATH // env.PATH))
        })
      | .["terminal.integrated.env.linux"] = ((.["terminal.integrated.env.linux"] // {}) + {
          "GOPATH": $gopath,
          "PATH": ($gopath_bin + ":${env:PATH}")
        })
    ' "${base_file}" > "${temp_file}"

  mv "${temp_file}" "${settings_file}"
  rm -f "${base_file}"

  if command -v code >/dev/null 2>&1; then
    echo "Instalando extensao Go no VS Code..."
    code --install-extension golang.Go --force
  else
    echo "AVISO: comando 'code' nao encontrado; a configuracao foi salva, mas a extensao Go nao foi instalada automaticamente."
  fi
}

validate_install() {
  echo "Validando instalacao..."
  export GOPATH="${HOME}/go"
  export PATH="${GOPATH}/bin:${PATH}"

  if ! command -v go >/dev/null 2>&1; then
    echo "ERRO: comando 'go' nao encontrado no PATH."
    exit 1
  fi

  if ! command -v gopls >/dev/null 2>&1; then
    echo "ERRO: comando 'gopls' nao encontrado no PATH."
    exit 1
  fi

  if ! command -v dlv >/dev/null 2>&1; then
    echo "ERRO: comando 'dlv' nao encontrado no PATH."
    exit 1
  fi

  go version
  echo "GOPATH configurado: $(go env GOPATH)"
}

post_notes() {
  cat <<'EOF'

Concluido.

O script instalou o Go, criou o workspace em ~/go, adicionou GOPATH/bin ao PATH
no ~/.bashrc e ajustou o settings.json do VS Code para usar esse ambiente.

Proximos passos:
1. Feche e abra o VS Code.
2. Reabra o terminal ou rode: source ~/.bashrc
3. Dentro do projeto Go, rode:
   go mod tidy
   go run .
EOF
}

main() {
  check_root
  check_fedora
  require_sudo
  install_dependencies
  configure_go_workspace
  install_go_tools
  configure_vscode
  validate_install
  post_notes
}

main "$@"
