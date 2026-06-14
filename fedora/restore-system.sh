#!/usr/bin/env bash

# Exit immediately if a critical command fails unexpectedly
set -e

echo "============================================="
echo "🔄 Btrfs System Recovery Interactive Tool"
echo "============================================="

# 1. Enforce root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Please run this script with sudo."
    echo "Example: sudo ./restore-system.sh"
    exit 1
fi

SNAPSHOT_DIR="/.snapshots"

# 2. Check if the snapshot directory exists and has snapshots
if [ ! -d "$SNAPSHOT_DIR" ] || [ -z "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
    echo "❌ Error: No system restore points found in $SNAPSHOT_DIR."
    echo "Create one first using your create-restore-point script."
    exit 1
fi

# 3. Read snapshots into an array
mapfile -t SNAPSHOTS < <(ls -1 "$SNAPSHOT_DIR" | grep "backup_root_")

if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
    echo "❌ Error: No snapshots matching the format 'backup_root_*' were found."
    exit 1
fi

# 4. Interactive Selection Menu
echo "Available system restore points:"
echo "---------------------------------------------"
for i in "${!SNAPSHOTS[@]}"; do
    printf "[%2d] %s\n" "$((i+1))" "${SNAPSHOTS[$i]}"
done
echo "[ q] Exit without changing anything"
echo "---------------------------------------------"

read -p "Select a restore point number to recover [1-${#SNAPSHOTS[@]} or q]: " CHOICE

if [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]]; then
    echo "👋 Exiting. No changes made to your system."
    exit 0
fi

# Validate user numeric input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#SNAPSHOTS[@]}" ]; then
    echo "❌ Invalid selection. Exiting."
    exit 1
fi

# Get the chosen snapshot name
SELECTED_SNAPSHOT="${SNAPSHOTS[$((CHOICE-1))]}"
SELECTED_PATH="$SNAPSHOT_DIR/$SELECTED_SNAPSHOT"

echo ""
echo "⚠️  WARNING: You selected: $SELECTED_SNAPSHOT"
echo "This will replace your current broken system state with this snapshot."
read -p "Are you absolutely sure you want to proceed? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "❌ Rollback canceled by user."
    exit 0
fi

echo ""
echo "-> Starting automated rollback sequence..."

# 5. Detect the main Btrfs drive partition automatically
# This finds the drive mapped to the root directory '/'
ROOT_DEVICE=$(findmnt -n -o SOURCE /)

# 6. Mount the top-level Btrfs volume to a temporary area
MUNT_DIR=$(mktemp -d)
echo "-> Mounting top-level Btrfs volume to temporary directory..."
mount "$ROOT_DEVICE" "$MUNT_DIR" -o subvol=/

TIMESTAMP_BACKUP=$(date +"%Y%m%d_%H%M%S")

# 7. Perform the safe subvolume swap
echo "-> Archiving your current broken root to root_broken_$TIMESTAMP_BACKUP..."
mv "$MUNT_DIR/root" "$MUNT_DIR/root_broken_$TIMESTAMP_BACKUP"

echo "-> Deploying selected clean restore point..."
# Create a writable copy of the read-only snapshot as the new active root
btrfs subvolume snapshot "$MUNT_DIR/.snapshots/$SELECTED_SNAPSHOT" "$MUNT_DIR/root"

# Clean up top-level mount
umount "$MUNT_DIR"
rm -rf "$MUNT_DIR"

echo "============================================="
echo "✅ SUCCESS: System rollback completed!"
echo "🔄 A system reboot is required immediately."
echo "============================================="

read -p "Reboot your computer now? (Y/n): " REBOOT_CHOICE
if [[ ! "$REBOOT_CHOICE" =~ ^[nN]$ ]]; then
    echo "Rebooting..."
    reboot
else
    echo "Please remember to manually reboot your system as soon as possible."
fi
