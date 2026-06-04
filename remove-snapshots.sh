#!/usr/bin/env bash

set -euo pipefail

SNAPSHOT_DIR="/.snapshots"
SNAPSHOT_PREFIX="backup_root_"

print_header() {
    echo "============================================="
    echo "🧹 Btrfs Snapshot Remover"
    echo "============================================="
}

print_error() {
    echo "❌ Error: $1"
}

print_info() {
    echo "ℹ️  $1"
}

check_environment() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Please run this script with sudo."
        exit 1
    fi

    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        print_error "Snapshot directory not found: $SNAPSHOT_DIR"
        exit 1
    fi

    if [[ "$(findmnt -n -o FSTYPE / 2>/dev/null)" != "btrfs" ]]; then
        print_error "Root filesystem is not Btrfs. This script only handles Btrfs snapshots."
        exit 1
    fi
}

load_snapshots() {
    mapfile -t SNAPSHOTS < <(
        find "$SNAPSHOT_DIR" -maxdepth 1 -mindepth 1 -type d -name "${SNAPSHOT_PREFIX}*" -printf '%f\n' | sort
    )

    if [[ ${#SNAPSHOTS[@]} -eq 0 ]]; then
        print_error "No snapshots matching '${SNAPSHOT_PREFIX}*' were found."
        exit 1
    fi
}

show_snapshots() {
    print_info "Available snapshots:"
    echo "---------------------------------------------"
    for i in "${!SNAPSHOTS[@]}"; do
        printf "[%2d] %s\n" "$((i + 1))" "${SNAPSHOTS[$i]}"
    done
    echo "---------------------------------------------"
    echo "Type 'all' to remove every snapshot, or a comma-separated list like 1,3,4."
    echo "Type 'q' to exit."
}

parse_selection() {
    local choice="$1"
    SELECTED_SNAPSHOTS=()

    if [[ "$choice" =~ ^[qQ]$ ]]; then
        exit 0
    fi

    if [[ "$choice" =~ ^([aA][lL][lL]|\*)$ ]]; then
        SELECTED_SNAPSHOTS=("${SNAPSHOTS[@]}")
        return
    fi

    IFS=',' read -r -a INDICES <<< "$choice"
    local index
    for index in "${INDICES[@]}"; do
        index="${index//[[:space:]]/}"
        if [[ ! "$index" =~ ^[0-9]+$ ]] || [[ "$index" -lt 1 ]] || [[ "$index" -gt "${#SNAPSHOTS[@]}" ]]; then
            print_error "Invalid selection: $index"
            exit 1
        fi
        SELECTED_SNAPSHOTS+=("${SNAPSHOTS[$((index - 1))]}")
    done

    if [[ ${#SELECTED_SNAPSHOTS[@]} -eq 0 ]]; then
        print_error "No snapshots selected."
        exit 1
    fi
}

confirm_and_remove() {
    echo
    echo "You selected:"
    for snapshot in "${SELECTED_SNAPSHOTS[@]}"; do
        echo " - $snapshot"
    done

    read -r -p "This will permanently delete the selected snapshots. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "No changes made."
        exit 0
    fi

    for snapshot in "${SELECTED_SNAPSHOTS[@]}"; do
        print_info "Removing $snapshot..."
        btrfs subvolume delete "$SNAPSHOT_DIR/$snapshot"
    done

    echo
    print_info "Remaining snapshots:"
    if find "$SNAPSHOT_DIR" -maxdepth 1 -mindepth 1 -type d -name "${SNAPSHOT_PREFIX}*" | grep -q .; then
        find "$SNAPSHOT_DIR" -maxdepth 1 -mindepth 1 -type d -name "${SNAPSHOT_PREFIX}*" -printf '%f\n' | sort
    else
        echo "(none)"
    fi
}

main() {
    print_header
    check_environment
    load_snapshots
    show_snapshots

    read -r -p "Select snapshots to remove [all/1,2,3/q]: " choice
    parse_selection "$choice"
    confirm_and_remove
}

main
