# dots

Personal dotfiles for Arch Linux + Omarchy + Hyprland.

## What this is

Version-controlled configuration files for a full desktop environment built on
Arch Linux, managed with [GNU Stow](https://www.gnu.org/software/stow/) for
symlink management and [Omarchy](https://omarchy.dev) as the theming layer.

Running `fish install.fish` on a fresh Arch + Omarchy machine restores the
complete environment in one step.

---

## Prerequisites

Before cloning and running the install script:

1. **Arch Linux** installed and booted
2. **Omarchy** installed: follow instructions at https://omarchy.dev
3. **yay** (AUR helper) available in PATH
4. **stow** installed: `sudo pacman -S stow`

The install script will handle everything else.

---

## Quick Restore (TL;DR)

```fish
git clone git@github.com:<USER>/dots.git ~/Work/dots
cd ~/Work/dots
fish install.fish
```

---

## Full Restore Walkthrough

### 1. Install Arch + Omarchy

Follow the Omarchy installation guide at https://omarchy.dev. This establishes
the base system with Hyprland, Waybar, and the Omarchy theming layer.

### 2. Clone this repository

```fish
mkdir -p ~/Work
git clone git@github.com:<USER>/dots.git ~/Work/dots
```

### 3. Run the install script

```fish
cd ~/Work/dots
fish install.fish
```

The script will:
- Verify prerequisites (omarchy, stow, yay)
- Install all packages from `packages.txt`
- Stow all config packages into `~/.config/`
- Install Fisher plugins from `fishfile`
- Run `mise install` to restore tool runtimes
- Activate the `aether` theme via Omarchy
- Prompt you for secrets (calendar URL, wallhaven API key)
- Warn you about `monitors.conf` (machine-specific — edit before rebooting)
- Run a headless Neovim sync to install all plugins

### 4. Configure machine-specific settings

Open `~/.config/hypr/monitors.conf` and adjust monitor layout for your hardware.

---

## Package Layout

| Stow package | Config path | Notes |
|---|---|---|
| `aether` | `~/.config/aether/` | Custom Omarchy theme; excludes wallpaper binary |
| `nvim` | `~/.config/nvim/` | LazyVim configuration |
| `fish` | `~/.config/fish/` | Shell config; completions excluded (auto-generated) |
| `hypr` | `~/.config/hypr/` | Hyprland, hypridle, hyprlock, hyprsunset |
| `waybar` | `~/.config/waybar/` | Status bar with custom scripts |
| `ghostty` | `~/.config/ghostty/` | Primary terminal emulator |
| `alacritty` | `~/.config/alacritty/` | Fallback terminal |
| `walker` | `~/.config/walker/` | Application launcher |
| `voxtype` | `~/.config/voxtype/` | Voice-to-text tool |
| `mise` | `~/.config/mise/` | Multi-language version manager |
| `atuin` | `~/.config/atuin/` | Shell history manager |
| `starship` | `~/.config/starship.toml` | Shell prompt (single file at config root) |
| `1password` | `~/.config/1Password/ssh/agent.toml` | SSH agent config only |
| `btop` | `~/.config/btop/` | System resource monitor |
| `swayosd` | `~/.config/swayosd/` | On-screen display for volume/brightness |
| `spotify-player` | `~/.config/spotify-player/` | Terminal Spotify client |

---

## Secrets

Two files contain secrets and are **not committed** to this repository.
After restore, `install.fish` will prompt you to fill them in.

### `~/.config/hypr/.calendar-url`

An ICS URL for the Hyprland calendar widget. Format:
```
https://calendar.google.com/calendar/ical/YOUR_EMAIL/public/basic.ics
```
See template: `hypr/hypr/.calendar-url.sample`

### `~/.config/aether/wallhaven.json`

Wallhaven API key for automatic wallpaper rotation. Format:
```json
{
  "apiKey": "your_wallhaven_api_key_here",
  ...
}
```
See template: `aether/aether/wallhaven.json.sample`

---

## Machine-Specific: monitors.conf

`hypr/hypr/monitors.conf` is tracked in this repository so it is not lost,
but it is **machine-specific** — monitor names, resolutions, and positions will
differ between machines.

After restoring on new hardware, edit `~/.config/hypr/monitors.conf` to match
your monitor layout before rebooting into Hyprland.

The install script will open this file for review before finishing.

---

## Day-2 Operations

### Pull changes from another machine

```fish
cd ~/Work/dots
git pull
# Re-stow any changed packages:
stow --target=$HOME/.config --restow --dir=$HOME/Work/dots <package>
```

### Add a new config to the repo

```fish
# 1. Create the stow package directory tree
mkdir -p ~/Work/dots/<package>/<package>/

# 2. Copy (or move) config files into it
cp -r ~/.config/<path>/* ~/Work/dots/<package>/<package>/

# 3. Stow the package (creates symlinks)
stow --target=$HOME/.config --restow --dir=$HOME/Work/dots <package>

# 4. Add the package name to the stow loop in install.fish

# 5. Commit
cd ~/Work/dots && git add <package>/ install.fish
git commit -m "feat: add <config>"
```

### Update dotfiles after editing a config

Since configs are symlinked from the repo, edits to `~/.config/<path>` are
immediately reflected in `~/Work/dots`. Just commit:

```fish
cd ~/Work/dots
git add -p
git commit -m "chore: update <what-you-changed>"
git push
```

---

## What is NOT tracked

- `~/.config/git/` — excluded by user preference
- `fish/fish/completions/` — auto-generated by carapace on first shell start
- Wallpaper binary files (`*.jpg`, `*.png`, etc.) — sourced from wallhaven URL
- Omarchy-managed themes (`dracula/`, `one-dark-pro/`, `current/`)
- `~/.local/share/omarchy/` — Omarchy internal data
- 1Password data beyond `ssh/agent.toml`
