# Linux Scripts

Personal collection of Bash and Go scripts for automating Linux system setup, with a focus on Fedora, Ubuntu, and Linux Mint. Tailored for C# development and GPU management.

## Supported Distributions

| Distribution | Status | Scripts Location |
|--------------|--------|-----------------|
| **Fedora** | ✅ Primary (Fedora 42+) | `fedora/` & `fedora/shell-version/` |
| **Ubuntu** | ✅ Supported | `ubuntu/` |
| **Linux Mint** | ✅ Supported (Mint 21) | `linux-mint/` |

## Prerequisites

- Linux system (Fedora, Ubuntu, or Linux Mint)
- `sudo` privileges for most scripts (they handle `sudo` internally)
- Bash 4.0+ or Go 1.18+ (depending on which scripts you use)

## Repository Structure

```
.
├── fedora/                          # Fedora-specific scripts
│   ├── shell-version/              # Original Bash script collection
│   │   ├── dev/                    # Development tools (Java, .NET, Git, etc.)
│   │   ├── nvidia/                 # GPU setup & restoration
│   │   ├── vm/                     # Virtualization tools
│   │   ├── wine/                   # Wine & Proton setup
│   │   └── menu.sh                 # Interactive terminal menu
│   ├── dev/                        # Root-level dev scripts
│   ├── nvidia/                     # Root-level GPU scripts
│   ├── go-run.sh                   # Launch Go TUI browser
│   ├── go-shell.sh                 # Launch shell menu
│   └── *.sh                        # Utility scripts
├── ubuntu/                          # Ubuntu-specific scripts
├── linux-mint/                      # Linux Mint-specific scripts
└── README.md
```

## Quick Start

### Interactive Menu (Recommended)

**Fedora shell version:**
```bash
cd fedora
bash shell-version/menu.sh
```

**Fedora Go TUI browser:**
```bash
cd fedora
./go-run.sh
```

### Direct Script Execution

Make script executable (optional):
```bash
chmod +x fedora/shell-version/dev/install-dotnet10-fedora.sh
```

Run as regular user (handles `sudo` internally):
```bash
./fedora/shell-version/dev/install-dotnet10-fedora.sh
```

Run root-only scripts with `sudo`:
```bash
sudo bash fedora/shell-version/fix-ssh-permission.sh
```

## Key Scripts by Category

### Development Tools

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Install .NET 10 SDK | `fedora/shell-version/dev/install-dotnet10-fedora.sh` | Fedora 42+ | C# development |
| Install Go + VS Code | `fedora/shell-version/dev/install-go-vscode-fedora.sh` | Fedora | Go tooling with VS Code setup |
| Install JDK 21 | `fedora/shell-version/dev/install-java-sdk-21.sh` | Fedora | Java development |
| Install JDK 21 | `fedora/shell-version/dev/install-java-sdk-21-linux-mint.sh` | Linux Mint 21 | Java development |
| Install Git | `fedora/shell-version/dev/install-git-fedora.sh` | Fedora | Git version control |
| Install JetBrains Rider | `fedora/shell-version/dev/install-jetbrains-rider-fedora.sh` | Fedora | C# IDE |
| Install Docker | `fedora/shell-version/dev/install-docker-container-fedora.sh` | Fedora | Container runtime |

### GPU & Display Management

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Restore Intel + X11 | `fedora/shell-version/nvidia/restore-intel-x11.sh` | Fedora | Remove NVIDIA, keep Intel iGPU + X11 |
| Fix GNOME NVIDIA | `fedora/shell-version/nvidia/consertar_gnome_nvidia.sh` | Fedora | Troubleshoot GNOME under NVIDIA |
| Fix GTK3 Dark Theme | `fedora/shell-version/fix-gtk3-dark-theme.sh` | Fedora | Apply dark theme to GTK apps |
| Fix Qt5 Dark Theme | `fedora/shell-version/fix-qt5-dark-theme.sh` | Fedora | Apply dark theme to Qt apps |
| Fix Dark GNOME | `fedora/fix-gnome-dark.sh` | Fedora | GNOME dark mode fixes |

### Desktop Environment

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Install GNOME Tweaks + Extensions | `fedora/shell-version/install-gnome-tweaks-extentions.sh` | Fedora 44 | GNOME customization |
| Install VS Code + .NET | `fedora/shell-version/dev/install-vscode-dotnet10-fedora.sh` | Fedora 44 | VS Code with C# support |
| Enable KDE Autologin | `fedora/enable-autologin-kde.sh` | Fedora | Skip login screen |
| Install Codecs | `fedora/shell-version/install-codecs-all.sh` | Fedora | Media codec support |

### System Utilities

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Fix SSH Permissions | `fedora/shell-version/fix-ssh-permission.sh` | Fedora | Fix `~/.ssh` ownership/perms |
| Remove Snapshots | `fedora/shell-version/remove-snapshots.sh` | Fedora (Btrfs) | Clean up Btrfs snapshots |
| Clear Flatpak Cache | `fedora/shell-version/clear-flatpak-cache-objects.sh` | Fedora | Reclaim disk space |
| Clean Temp Files | `fedora/shell-version/limpar_temp.sh` | Fedora | Remove temporary files |
| Clean Flatpak | `fedora/shell-version/limpar-flatpak.sh` | Fedora | Remove unused flatpaks |

### Virtualization

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Setup OSX-KVM | `fedora/shell-version/vm/setup-osx-kvm-fedora.sh` | Fedora | macOS KVM virtualization |
| Fix VirtualBox | `fedora/shell-version/vm/fix-virtualbox-fedora.sh` | Fedora | VirtualBox setup |
| Enable Android Virt | `fedora/shell-version/vm/enable-android-virtualization.sh` | Fedora | Android emulation support |
| Fix Boxes NAT | `fedora/shell-version/vm/fix-boxes-nat.sh` | Fedora | GNOME Boxes networking |
| Resize Boxes HD | `fedora/shell-version/vm/resize-hd-boxes.sh` | Fedora | Expand GNOME Boxes disk |
| QEMU VM Hide | `fedora/shell-version/vm/qemu-vm-hide.sh` | Fedora | Hide guest OS info |

### Wine & Proton

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Wine Setup v12 | `fedora/shell-version/wine/wine-1-fix-install-v12.sh` | Fedora | Wine installation (version 1.x) |
| Wine Setup v9 | `fedora/shell-version/wine/wine-2-fix-and-install-v9.sh` | Fedora | Wine installation (version 9.x) |
| Remove Wine | `fedora/shell-version/wine/wine-3-remove-and-flatpak.sh` | Fedora | Uninstall Wine & use Flatpak |

### System Maintenance

| Script | Location | Platform | Purpose |
|--------|----------|----------|---------|
| Create Restore Point | `fedora/create-restore-point.sh` | Fedora | Snapshot Btrfs filesystem |
| Restore System | `fedora/restore-system.sh` | Fedora | Restore from Btrfs snapshot |
| Clean bin/obj | `fedora/shell-version/dev/limpa-bin-obj.sh` | Fedora | Remove .NET build artifacts |
| Fix Oh-My-Bash | `fedora/shell-version/fix-oh-my-bash.sh` | Fedora | Repair oh-my-bash setup |

## Important Notes

⚠️ **Review Before Running**
- Scripts modify system state: install packages, add repositories, edit `/etc` files
- Always review a script before executing it on your system
- Test in a VM first if you're unfamiliar with a script

**Script Permissions**
- Most scripts exit if run as root (use them as a regular user)
- Exceptions: `fix-ssh-permission.sh`, scripts that explicitly require `sudo`
- Scripts handle `sudo` calls internally for operations requiring elevation

**GPU Management**
- NVIDIA 390xx support has been deprecated
- Recommended path: `restore-intel-x11.sh` (keep Intel iGPU + X11)
- Can be run from mounted filesystem via `TARGET_ROOT=/mounted/root` during live boot

**Btrfs Features**
- `remove-snapshots.sh`, `create-restore-point.sh`, `restore-system.sh` require Btrfs root filesystem
- Verify your root is Btrfs before running: `mount | grep "on / "`

---

**Disclaimer:** This is a personal project with no test suite or CI. Use at your own risk. Always maintain backups before running system scripts.
