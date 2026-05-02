# AGENTS.md

## Repo Overview
Collection of Bash scripts for Fedora Linux system setup (package installs, driver config, SSH permissions). No build system, no test suite.

## Critical Rules
- Most scripts **must not run as root**: They use `sudo` internally. Root execution triggers `check_root` and exits immediately (exceptions: `fix-ssh-permission.sh`, `setup-nvidia-fedora.sh`).
- Scripts modify system state: Install packages, add repos (e.g, VS Code Microsoft repo), edit `/etc` configs. Run with caution.

## Script-Specific Notes
- `fix-ssh-permission.sh`: Minimal, no validation (no Fedora/root checks, no `set -e`), runs `chmod` on `~/.ssh`
- `install-dotnet10-fedora.sh`: Supports Fedora 42+ (warns on older versions)
- `install-gnome-tweaks-extentions.sh`, `install-vscode-dotnet10-fedora.sh`: Target Fedora 44 (warns on version mismatch)
- `setup-nvidia-fedora.sh`: Installs NVIDIA 390xx drivers (GeForce GT 630M/620M), disables Wayland, uses `sudo` directly (no root check)
