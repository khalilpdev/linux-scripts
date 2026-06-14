#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
    local script_path="$1"
    case "$(basename "$script_path")" in
        fix-ssh-permission.sh|setup-nvidia-fedora.sh)
            sudo bash "$script_path"
            ;;
        *)
            bash "$script_path"
            ;;
    esac
}

load_scripts() {
    mapfile -t ALL_SCRIPTS < <(find "$ROOT_DIR" -type f -name '*.sh' ! -name 'menu.sh' | sort)
}

build_modules() {
    declare -gA MODULE_COUNTS=()
    declare -ga MODULE_LIST=()

    local script rel module
    for script in "${ALL_SCRIPTS[@]}"; do
        rel="${script#"$ROOT_DIR"/}"
        if [[ "$rel" == */* ]]; then
            module="${rel%%/*}"
        else
            module="raiz"
        fi

        if [[ -z "${MODULE_COUNTS[$module]+x}" ]]; then
            MODULE_LIST+=("$module")
            MODULE_COUNTS["$module"]=0
        fi
        MODULE_COUNTS["$module"]=$((MODULE_COUNTS["$module"] + 1))
    done
}

show_modules() {
    echo
    echo "=== Shell Version ==="
    echo "Escolha um modulo:"
    echo
    local i=1 module
    for module in "${MODULE_LIST[@]}"; do
        printf '  %d) %s (%d itens)\n' "$i" "$module" "${MODULE_COUNTS[$module]}"
        i=$((i + 1))
    done
    printf '  %d) Sair\n' "$i"
}

module_scripts() {
    local selected_module="$1"
    local script rel module
    SCRIPTS_IN_MODULE=()
    for script in "${ALL_SCRIPTS[@]}"; do
        rel="${script#"$ROOT_DIR"/}"
        if [[ "$rel" == */* ]]; then
            module="${rel%%/*}"
        else
            module="raiz"
        fi
        if [[ "$module" == "$selected_module" ]]; then
            SCRIPTS_IN_MODULE+=("$script")
        fi
    done
}

show_scripts() {
    local selected_module="$1"
    echo
    echo "=== Modulo: $selected_module ==="
    echo "Escolha um script:"
    echo
    local i=1 script rel
    for script in "${SCRIPTS_IN_MODULE[@]}"; do
        rel="${script#"$ROOT_DIR"/}"
        printf '  %d) %s\n' "$i" "$rel"
        i=$((i + 1))
    done
    printf '  %d) Voltar\n' "$i"
}

main() {
    load_scripts
    build_modules

    if [[ ${#ALL_SCRIPTS[@]} -eq 0 ]]; then
        echo "Nenhum script .sh encontrado em $ROOT_DIR"
        exit 1
    fi

    while true; do
        show_modules
        read -r -p "Opcao: " module_choice
        if ! [[ "$module_choice" =~ ^[0-9]+$ ]]; then
            echo "Opcao invalida."
            continue
        fi

        if [[ "$module_choice" -eq 0 ]]; then
            continue
        fi

        local exit_choice=$(( ${#MODULE_LIST[@]} + 1 ))
        if [[ "$module_choice" -eq "$exit_choice" ]]; then
            exit 0
        fi

        if [[ "$module_choice" -lt 1 || "$module_choice" -gt "${#MODULE_LIST[@]}" ]]; then
            echo "Opcao invalida."
            continue
        fi

        local selected_module="${MODULE_LIST[$((module_choice - 1))]}"
        module_scripts "$selected_module"

        while true; do
            show_scripts "$selected_module"
            read -r -p "Opcao: " script_choice
            if ! [[ "$script_choice" =~ ^[0-9]+$ ]]; then
                echo "Opcao invalida."
                continue
            fi
            local back_choice=$(( ${#SCRIPTS_IN_MODULE[@]} + 1 ))
            if [[ "$script_choice" -eq "$back_choice" ]]; then
                break
            fi
            if [[ "$script_choice" -lt 1 || "$script_choice" -gt "${#SCRIPTS_IN_MODULE[@]}" ]]; then
                echo "Opcao invalida."
                continue
            fi

            local script_path="${SCRIPTS_IN_MODULE[$((script_choice - 1))]}"
            echo
            echo "Executando: ${script_path#"$ROOT_DIR"/}"
            run_script "$script_path"
            echo
            read -r -p "Pressione Enter para continuar..." _
        done
    done
}

main
