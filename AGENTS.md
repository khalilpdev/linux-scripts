# AGENTS.md

## Repo Overview
Collection of Bash scripts for Fedora Linux system setup (package installs, driver config, SSH permissions). No build system, no test suite.

## Critical Rules
- Most scripts **must not run as root**: They use `sudo` internally. Root execution triggers `check_root` and exits immediately (exceptions: `fix-ssh-permission.sh`, `setup-nvidia-fedora.sh`).
- Scripts modify system state: Install packages, add repos (e.g, VS Code Microsoft repo), edit `/etc` configs. Run with caution.

## Script-Specific Notes
- `fix-ssh-permission.sh`: Minimal, no validation (no Fedora/root checks, no `set -e`), runs `chmod` on `~/.ssh`
- `install-dotnet10-fedora.sh`: Supports Fedora 42+ (warns on older versions)
- `dev/install-go-vscode-fedora.sh`: Installs Go from Fedora repos, sets `GOPATH=~/go`, adds `~/go/bin` to `PATH`, installs `gopls`/`dlv`, and updates VS Code user settings
- `install-gnome-tweaks-extentions.sh`, `install-vscode-dotnet10-fedora.sh`: Target Fedora 44 (warns on version mismatch)
- `shell-version/nvidia/install-nvidia-fedora-390xx-kernel-7.sh`: Installs/Repara NVIDIA 390xx and disables Nouveau/Wayland; `shell-version/nvidia/install-nvidia-fedora-390xx-x11.sh`: installs 390xx and activates Plasma X11; `shell-version/nvidia/setup-gpu-launchers.sh`: creates per-user Intel/NVIDIA app launchers without changing boot behavior
- On Fedora KDE, the Plasma X11 session file is `plasmax11.desktop` (not `plasma-x11.desktop`); writing the wrong session name to `/var/lib/sddm/state.conf` causes SDDM login/session startup failures.
- `remove-snapshots.sh`: Interactively removes selected Btrfs snapshots from `/.snapshots`; run it with `sudo`
