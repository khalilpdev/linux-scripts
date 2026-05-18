#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

echo "============================================="
echo "🕒 Creating Fast Btrfs Restore Point..."
echo "============================================="

# 1. Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Please run this script with sudo."
    echo "Example: sudo ./create-restore-point.sh"
    exit 1
fi

# 2. Define snapshot paths and timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_DIR="/.snapshots"
SNAPSHOT_PATH="$SNAPSHOT_DIR/backup_root_$TIMESTAMP"

# 3. Create the hidden snapshot directory if it doesn't exist
if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "-> Creating snapshot directory at $SNAPSHOT_DIR..."
    mkdir -p "$SNAPSHOT_DIR"
fi

# 4. Create the read-only Btrfs snapshot of the root filesystem
echo "-> Creating instant system snapshot..."
btrfs subvolume snapshot -r / "$SNAPSHOT_PATH"

# 5. Verify the snapshot was created successfully
if [ -d "$SNAPSHOT_PATH" ]; then
    echo "============================================="
    echo "✅ Success! Restore point created in under 1s."
    echo "📂 Location: $SNAPSHOT_PATH"
    echo "============================================="
else
    echo "❌ Error: Failed to create Btrfs snapshot."
    exit 1
fi
