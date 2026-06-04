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
| `shell-version/dev/install-java-sdk-21.sh` | Installs Oracle JDK 21 on Fedora and configures global `JAVA_HOME`/`PATH` | Run as a normal user on Fedora; creates `/opt/java/jdk-21` symlink |
| `shell-version/dev/install-java-sdk-21-linux-mint.sh` | Installs Oracle JDK 21 on Linux Mint 21 and configures global `JAVA_HOME`/`PATH` | Run as a normal user on Linux Mint; warns outside Mint 21 and creates `/opt/java/jdk-21` symlink |
| `install-gnome-tweaks-extentions.sh` | Installs GNOME Tweaks and common extensions | Targets Fedora 44, warns on version mismatch |
| `install-vscode-dotnet10-fedora.sh` | Sets up VS Code with .NET 10 support, adds Microsoft VS Code repo | Targets Fedora 44, warns on version mismatch |
| `shell-version/nvidia/restore-intel-x11.sh` | Removes the NVIDIA 390xx flow, restores Intel + Plasma X11 defaults, and rebuilds initramfs | Run as a normal user on the installed system, or with `TARGET_ROOT=/mounted/root` from a Fedora live CD |
| `shell-version/nvidia/install-nvidia-fedora-390xx-kernel-7.sh` | Deprecated wrapper that now redirects to `restore-intel-x11.sh` | 390xx was discarded to avoid forcing boot/session through NVIDIA |
| `shell-version/nvidia/install-nvidia-fedora-390xx-x11.sh` | Deprecated wrapper that now redirects to `restore-intel-x11.sh` | 390xx was discarded to avoid forcing boot/session through NVIDIA |
| `shell-version/nvidia/setup-gpu-launchers.sh` | Deprecated notice; the NVIDIA launcher flow was removed with 390xx | Keeps users on the Intel default path |
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

The NVIDIA 390xx flow has been discarded in this repository. The supported recovery path is `shell-version/nvidia/restore-intel-x11.sh`, and old 390xx scripts now redirect to it. From a Fedora live CD, run it with `TARGET_ROOT=/mounted/root`.

## Important Notes
- Scripts modify system state: install packages, add third-party repositories, edit `/etc` configuration files. Review scripts before running.
- Most scripts include a `check_root` function that exits immediately if run as root (exceptions: `fix-ssh-permission.sh`, `setup-nvidia-fedora.sh`).
- This is a personal project with no test suite or CI. Use at your own risk.
