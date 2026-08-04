# dots

Personal dotfiles for Arch Linux + Omarchy + Hyprland.

## What this is

Version-controlled configuration files for a full desktop environment built on
Arch Linux, using [Omarchy](https://omarchy.dev) as the theming layer. Configs
are copied (not symlinked) into `~/.config/`, so edits made there won't
propagate back to the repo automatically — commit changes explicitly.

Running `fish install.fish` on a fresh Arch + Omarchy machine restores the
complete environment in one step.

---

## Prerequisites

Before cloning and running the install script:

1. **Arch Linux** installed and booted
2. **Omarchy** installed: follow instructions at https://omarchy.dev
3. **yay** (AUR helper) available in PATH

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
- Verify prerequisites (omarchy, yay)
- Install all packages from `packages.txt`
- Copy all config packages into `~/.config/`
- Install Fisher plugins from `fishfile`
- Run `mise install` to restore tool runtimes
- Install global npm packages (codegraph, eas-cli, mcp-server-mysql)
- Activate the `aether` theme via Omarchy
- Prompt you for secrets (calendar URL, wallhaven API key)
- Auto-generate `monitors.conf` from this machine's actually detected monitors
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
| `xdg-terminals` | `~/.config/xdg-terminals.list` | Default terminal preference for `xdg-terminal-exec` (single file) |
| `tmux` | `~/.config/tmux/` | Terminal multiplexer |
| `zellij` | `~/.config/zellij/` | Terminal multiplexer (layouts included) |

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

`hypr/hypr/monitors.conf` is tracked in this repository, but it's
**machine-specific** — monitor names, resolutions, and positions differ
between machines. Copying the file as-is from another laptop is what breaks
your layout on new hardware.

`install.fish` handles this automatically: `generate-monitors.fish` runs
`hyprctl monitors -j` and regenerates `~/.config/hypr/monitors.conf` for
whatever this machine actually has connected, laying out monitors
left-to-right in detection order at their preferred resolution/refresh/scale.

Run it manually any time your monitor setup changes (new laptop, new external
display, docking/undocking):

```fish
fish ~/Work/dots/generate-monitors.fish              # write it
fish ~/Work/dots/generate-monitors.fish --dry-run    # preview without writing
```

If you want a non-default arrangement (e.g. an external monitor above/below
instead of beside the laptop screen), edit `~/.config/hypr/monitors.conf` by
hand afterward — it won't be touched again until you re-run the generator.

---

## Day-2 Operations

### Pull changes from another machine (recommended: migrations)

On a machine that's already fully set up, don't re-run `install.fish` — it
reinstalls every package and recopies every config from scratch. Instead use
`migrate.fish`, which only applies changes that are actually new:

```fish
cd ~/Work/dots
git pull
fish migrate.fish              # runs any pending migrations
fish migrate.fish --dry-run    # preview what would run, without running it
```

Each migration is a small `migrations/<unix-timestamp>.fish` script (same
pattern Omarchy itself uses). Applied migrations are tracked in
`~/.local/state/dots/migrations/` so they never run twice. If a migration
fails, you're prompted to skip it (and it's recorded under `.../skipped/`) or
abort.

`install.fish` runs a full bootstrap and, at the end, marks every existing
migration as already applied (`fish migrate.fish --baseline`) — a fresh
install already has the latest state, so there's nothing left to migrate.

#### Creating a new migration

When you change a config in a way that needs an action on other machines
(not just a file copy that `install.fish` would already handle on next full
run), add a migration instead of documenting a manual step:

```fish
fish migrate.fish --new "short description of the change"
```

This scaffolds `migrations/<timestamp>.fish` and opens it in `$EDITOR`. Write
whatever's needed (copy specific files, restart a service, run a one-off
command) — see `migrations/*.fish` for examples.

### Add a new config to the repo

```fish
# 1. Create the package directory tree
mkdir -p ~/Work/dots/<package>/<package>/

# 2. Copy config files into it
cp -r ~/.config/<path>/* ~/Work/dots/<package>/<package>/

# 3. Add the package name to the copy loop in install.fish

# 4. Commit
cd ~/Work/dots && git add <package>/ install.fish
git commit -m "feat: add <config>"
```

### Update dotfiles after editing a config

Since configs are **copied**, not symlinked, edits to `~/.config/<path>` do
**not** propagate back to `~/Work/dots` automatically. Copy the changed files
back into the repo, then commit:

```fish
cp -r ~/.config/<package>/* ~/Work/dots/<package>/<package>/
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
