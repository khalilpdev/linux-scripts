# fedora-scripts

Personal collection of Bash scripts for automating Fedora Linux system setup, tailored for my C# development workflow and NVIDIA GeForce GT 630M GPU.

## Prerequisites
- Fedora Linux (version support varies per script, see details below)
- `sudo` privileges (most scripts use `sudo` internally, do not run as root unless explicitly noted)

## Available Scripts
| Script | Description | Requirements/Notes |
|--------|-------------|-------------------|
| `fix-ssh-permission.sh` | Fixes SSH key permissions in `~/.ssh` | **Must run as root** (no root check, minimal validation) |
| `install-dotnet10-fedora.sh` | Installs .NET 10 SDK for C# development | Supports Fedora 42+, warns on older versions |
| `dev/install-go-vscode-fedora.sh` | Installs Go and fixes VS Code Go PATH/GOPATH setup | Configures `~/go`, updates `~/.bashrc`, installs `gopls`/`dlv`, updates VS Code settings |
| `install-gnome-tweaks-extentions.sh` | Installs GNOME Tweaks and common extensions | Targets Fedora 44, warns on version mismatch |
| `install-vscode-dotnet10-fedora.sh` | Sets up VS Code with .NET 10 support, adds Microsoft VS Code repo | Targets Fedora 44, warns on version mismatch |
| `shell-version/nvidia/install-nvidia-fedora-390xx-kernel-7.sh` | Installs/Repara NVIDIA 390xx and disables Nouveau/Wayland | Runs with `sudo` internally, supports GeForce GT 630M/620M |
| `shell-version/nvidia/install-nvidia-fedora-390xx-nouveau.sh` | Installs NVIDIA 390xx packages but keeps Nouveau active | Runs with `sudo` internally, Fedora 42+ |
| `remove-snapshots.sh` | Interactively removes selected Btrfs restore points from `/.snapshots` | Must run with `sudo`, root filesystem must be Btrfs |

## Usage
1. (Optional) Make scripts executable:
   ```bash
   chmod +x <script-name>.sh
   ```
2. Run non-root scripts as a regular user (they handle `sudo` internally):
   ```bash
   ./install-dotnet10-fedora.sh
   ```
3. Run root-required scripts with `sudo`:
   ```bash
   sudo bash shell-version/fix-ssh-permission.sh
   ```

## Versions

### Go version
The first Go version scans the repository tree and renders a graphical home screen where folders become modules and files become items.

Run it with:
```bash
./go-run.sh
```

Or directly:
```bash
go run ./cmd/fedora-browser
```

Useful environment variables:
```bash
FEDORA_SCRIPTS_NO_BROWSER=1 go run ./cmd/fedora-browser
FEDORA_SCRIPTS_ADDR=127.0.0.1:8080 go run ./cmd/fedora-browser
```

### Shell version
The original Bash scripts now live under `shell-version/`, grouped by folder as modules. A terminal menu is available at:
```bash
./go-shell.sh
```

Or directly:
```bash
bash shell-version/menu.sh
```

The menu shows each folder as a module and each script as an item. Scripts that need elevated permissions still call `sudo` when required.

## Important Notes
- Scripts modify system state: install packages, add third-party repositories, edit `/etc` configuration files. Review scripts before running.
- Most scripts include a `check_root` function that exits immediately if run as root (exceptions: `fix-ssh-permission.sh`, `setup-nvidia-fedora.sh`).
- This is a personal project with no test suite or CI. Use at your own risk.
