# Dotfiles

Personal configuration for Arch Linux with [Niri](https://github.com/YaLTeR/niri) (Wayland compositor).

## Stack

| Role | Tool |
|------|------|
| Compositor | Niri |
| Terminal | Kitty |
| Shell | Fish |
| Bar | Waybar |
| Launcher | Wofi |
| File manager | Yazi / Nautilus |
| Audio | PipeWire + WirePlumber |
| Display manager | SDDM |

## Structure

```
Dotfiles/
├── install.sh          # entry point
├── bootstrap/
│   ├── lib.sh          # shared functions (sourced by all scripts)
│   ├── host.sh         # partition, format, pacstrap
│   ├── chroot.sh       # locale, users, bootloader
│   ├── post.sh         # post-install: snapper, cachyos repos, dotfiles
│   ├── packages.txt    # full package list (yay -Qs output)
│   ├── systemctl-root.txt
│   └── systemctl-user.txt
├── config/             # → ~/.config
├── local/              # → ~/.local
├── bash/               # → ~
└── vim/                # → ~
```

`config/`, `local/`, `bash/`, and `vim/` are [GNU Stow](https://www.gnu.org/software/stow/) packages. `deploy_dotfiles` in `lib.sh` maps each to its target and stows them.

## Installation

### Fresh Arch install

Boot an Arch ISO, then:

```bash
git clone https://github.com/Lunobe/Dotfiles
bash Dotfiles/bootstrap/host.sh
```

`host.sh` partitions the disk (GPT, EFI + root), formats with btrfs (subvolumes: `@`, `@home`, `@cache`, `@log`, `@snapshots`) or ext4, runs `pacstrap`, and calls `chroot.sh` automatically. Both scripts are interactive — they prompt for disk, hostname, username, timezone, and so on before touching anything.

After reboot, run `post.sh` as root (or with sudo) to set up CachyOS repos, Snapper, install packages, enable systemd units, and deploy dotfiles:

```bash
bash post.sh
```

Each step asks for confirmation unless you choose auto mode.

### Existing system

Clone the repo and run the main installer:

```bash
git clone https://github.com/lunobe/Dotfiles ~/Dotfiles
cd ~/Dotfiles
bash install.sh
```

Two prompts:
1. **Install packages** — reads `bootstrap/packages.txt` and passes everything to `yay -S --needed`. `linux-cachyos` and `linux-cachyos-headers` are excluded by default (CachyOS-specific kernel).
2. **Deploy dotfiles** — backs up any conflicting files to `~/dotfiles-backup-<timestamp>/`, then stows each package.

## dotit

`dotit` moves a file or directory into the repo and replaces it with a symlink. It's the main way to add new configs.

```
Usage: dotit [options] <path>

Options:
  -u    Undo: restore original file from repository
```

**Adding a config:**

```bash
dotit ~/.config/someapp
# ==> deployed: /home/lunobe/.config/someapp -> ~/Dotfiles/config/someapp
```

If the target is directly in `$HOME` (e.g. `dotit ~/.zshrc`), dotit asks for a category name (like `bash`) to determine where in the repo to place it.

**Undoing:**

```bash
dotit -u ~/.config/someapp
# ==> restored: /home/lunobe/.config/someapp
```

This removes the symlink and moves the file back from the repo to its original location.

**Path cleaning:** dotit strips leading dots from path components before placing files in the repo so they stay visible (non-hidden). For example, `~/.config/foo` → `Dotfiles/config/foo`. Stow re-adds the dots at deploy time via `TARGET_MAP`.

The repo path is read from `~/.config/lunobe/dotit.conf` (created on first run with default `~/Dotfiles`).

## dotsync

Commits and optionally pushes the current state of the repo. Also regenerates `packages.txt` from the live system.

```bash
dotsync "feat: add kitty config"
```

What it does:
1. Runs `yay -Qs` and overwrites `bootstrap/packages.txt`
2. `git add -A`
3. `git commit -m "<message>"`
4. Asks whether to push to `origin main`

## Niri config

The Niri config is split into modules under `config/niri/cfg/`:

| File | Contents |
|------|----------|
| `binds.kdl` | Keybindings |
| `input.kdl` | Mouse and keyboard settings |
| `outputs.kdl` | Monitor configuration |
| `layout.kdl` | Window layout rules |
| `startup.kdl` | Autostart applications |
| `window-n-layer-rules.kdl` | Per-app window/layer rules |
| `environment.kdl` | Environment variables for the session |
| `misc.kdl` | Everything else |

## Other scripts

| Script | Description |
|--------|-------------|
| `local/bin/nodisplay` | Hide an app from launchers by setting `NoDisplay=true` in its `.desktop` file |
| `local/bin/rvc-audio-setup` | Create/destroy a PipeWire virtual mic for RVC voice conversion (`up` / `down` / `status`) |

## License
Do whatever you want with this. No warranty implied.
