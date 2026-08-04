#!/usr/bin/env fish
# dots/install.fish — idempotent restore script for Arch + Omarchy + Hyprland
# Usage: fish install.fish [--dry-run]

# ── Color palette ──────────────────────────────────────────────────────────────
set -g GREEN  (set_color green)
set -g YELLOW (set_color yellow)
set -g RED    (set_color red)
set -g BOLD   (set_color --bold)
set -g RESET  (set_color normal)

# ── Flags ──────────────────────────────────────────────────────────────────────
set -g DRY_RUN false
if contains -- --dry-run $argv
    set DRY_RUN true
    echo $YELLOW"[dry-run]"$RESET" No changes will be made — commands are printed only."
end

set -g DOTS_DIR $HOME/Work/dots

# ── Helper functions ───────────────────────────────────────────────────────────
function info
    echo $GREEN"[info]"$RESET"  $argv"
end

function warn
    echo $YELLOW"[warn]"$RESET"  $argv"
end

function error
    echo $RED"[error]"$RESET" $argv" >&2
end

function run
    if test $DRY_RUN = true
        echo $YELLOW"[dry-run]"$RESET" $argv"
    else
        # Invoke $argv directly (not via `eval`) so an argument containing
        # spaces/pipes (e.g. a `fish -c "a | b"` string) is passed through as
        # ONE argument instead of being re-tokenized by eval.
        $argv
        or begin
            error "Command failed: $argv"
            return 1
        end
    end
end

# ── 1. check_prerequisites ─────────────────────────────────────────────────────
function check_prerequisites
    info "Checking prerequisites..."

    if not command -q omarchy
        error "omarchy is not installed."
        error "Install it from: https://omarchy.dev"
        error "Run the Omarchy install script, then re-run this script."
        return 1
    end

    if not command -q yay
        error "yay (AUR helper) is not installed."
        error "Install from: https://github.com/Jguer/yay#installation"
        return 1
    end

    info "All prerequisites satisfied."
end

# ── 2. install_packages ────────────────────────────────────────────────────────
function install_packages
    info "Installing packages from packages.txt..."

    set -l pkgfile $DOTS_DIR/packages.txt

    if not test -f $pkgfile
        error "packages.txt not found at $pkgfile"
        return 1
    end

    # Parse pacman packages (lines between "# PACMAN" and "# AUR" or EOF)
    set -l in_pacman false
    set -l in_aur false
    set -l pacman_pkgs
    set -l aur_pkgs

    while read -l line
        # Skip blank lines
        if test -z (string trim $line)
            continue
        end
        # Section headers
        if string match -qi '# PACMAN' $line
            set in_pacman true
            set in_aur false
            continue
        end
        if string match -qi '# AUR' $line
            set in_pacman false
            set in_aur true
            continue
        end
        # Skip comment lines
        if string match -qr '^#' $line
            continue
        end
        # Collect packages
        if test $in_pacman = true
            set -a pacman_pkgs $line
        else if test $in_aur = true
            set -a aur_pkgs $line
        end
    end < $pkgfile

    if test (count $pacman_pkgs) -gt 0
        info "Installing pacman packages: $pacman_pkgs"
        run sudo pacman -S --needed --noconfirm $pacman_pkgs
        or return 1
    end

    if test (count $aur_pkgs) -gt 0
        info "Installing AUR packages: $aur_pkgs"
        run yay -S --needed --noconfirm $aur_pkgs
        or return 1
    end

    info "Package installation complete."
end

# ── 3. clone_repo ──────────────────────────────────────────────────────────────
function clone_repo
    if test -d $DOTS_DIR/.git
        info "dots repository already exists at $DOTS_DIR — skipping clone."
        return 0
    end

    set -l repo_url $DOTS_REPO_URL
    if test -z "$repo_url"
        warn "DOTS_REPO_URL is not set."
        read -l -P "Enter the dots repository URL (e.g. git@github.com:user/dots.git): " repo_url
        if test -z "$repo_url"
            error "Repository URL is required."
            return 1
        end
    end

    info "Cloning dots repository from $repo_url..."
    run git clone $repo_url $DOTS_DIR
    or return 1

    info "Repository cloned to $DOTS_DIR."
end

# ── 4. copy_packages ──────────────────────────────────────────────────────────
function copy_packages
    info "Copying all packages into ~/.config/..."

    set -l packages \
        aether nvim fish hypr waybar \
        ghostty alacritty walker voxtype \
        mise atuin \
        btop swayosd spotify-player \
        tmux zellij

    for pkg in $packages
        set -l pkg_src $DOTS_DIR/$pkg/$pkg
        if not test -d $pkg_src
            warn "Package directory not found: $pkg_src — skipping."
            continue
        end

        info "Copying $pkg..."
        set -l pkg_dst $HOME/.config/$pkg
        # Wipe the destination first: a prior stow run may have left symlinks
        # to the repo nested inside, which would make cp a no-op or error.
        run rm -rf $pkg_dst
        or begin
            error "Failed to remove existing $pkg_dst — check for a stuck mount, immutable file, or permission issue inside it."
            return 1
        end
        run mkdir -p $pkg_dst
        or begin
            error "Failed to create $pkg_dst"
            return 1
        end
        run cp -rT $pkg_src $pkg_dst
        or begin
            error "Failed to copy package: $pkg"
            return 1
        end
    end

    # starship.toml lives at ~/.config/starship.toml, not a subdirectory.
    info "Copying starship..."
    run cp $DOTS_DIR/starship/starship.toml $HOME/.config/starship.toml
    or begin
        error "Failed to copy package: starship"
        return 1
    end

    # 1Password only tracks ssh/agent.toml, under a capitalized directory name.
    info "Copying 1password..."
    run rm -rf $HOME/.config/1Password/ssh
    or begin
        error "Failed to remove existing ~/.config/1Password/ssh"
        return 1
    end
    run mkdir -p $HOME/.config/1Password/ssh
    or begin
        error "Failed to create ~/.config/1Password/ssh"
        return 1
    end
    run cp -rT $DOTS_DIR/1password/1Password/ssh $HOME/.config/1Password/ssh
    or begin
        error "Failed to copy package: 1password"
        return 1
    end

    # xdg-terminals.list lives at ~/.config/xdg-terminals.list, not a subdirectory.
    info "Copying xdg-terminals..."
    run cp $DOTS_DIR/xdg-terminals/xdg-terminals.list $HOME/.config/xdg-terminals.list
    or begin
        error "Failed to copy package: xdg-terminals"
        return 1
    end

    info "All packages copied."
end

# ── 6. install_fisher ─────────────────────────────────────────────────────────
function install_fisher
    info "Installing Fisher plugins from fishfile..."

    if not command -q fisher
        warn "fisher is not installed — installing it first..."
        run fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
        or return 1
    end

    run fish -c "fisher update"
    or return 1

    info "Fisher plugins installed."
end

# ── 7. run_mise ───────────────────────────────────────────────────────────────
function run_mise
    info "Installing tool runtimes via mise..."

    if not command -q mise
        error "mise is not installed. It should have been installed via packages.txt."
        return 1
    end

    run mise install
    or return 1

    info "mise install complete."
end

# ── 7b. install_npm_globals ────────────────────────────────────────────────────
function install_npm_globals
    info "Installing global npm packages..."

    if not command -q npm
        error "npm is not installed. It should have been installed via mise."
        return 1
    end

    set -l npm_pkgs \
        @colbymchenry/codegraph \
        eas-cli \
        @benborla29/mcp-server-mysql

    run npm install -g $npm_pkgs
    or return 1

    info "Global npm packages installed."
end

# ── 8. activate_theme ─────────────────────────────────────────────────────────
function activate_theme
    set -l theme_link $HOME/.config/omarchy/themes/aether

    if not test -e $theme_link
        info "Registering aether theme with Omarchy..."
        run mkdir -p $HOME/.config/omarchy/themes
        or return 1
        run ln -s $HOME/.config/aether/theme $theme_link
        or return 1
    end

    info "Activating aether theme via Omarchy..."
    run omarchy theme set aether
    or return 1
    info "Theme activated."
end

# ── 9. configure_secrets ─────────────────────────────────────────────────────
function configure_secrets
    info "Configuring secrets..."

    # .calendar-url
    set -l cal_real $HOME/.config/hypr/.calendar-url
    set -l cal_sample $DOTS_DIR/hypr/hypr/.calendar-url.sample

    if test -f $cal_real
        info ".calendar-url already exists — skipping."
    else
        warn ".calendar-url not found."
        warn "This is your Google Calendar ICS URL for the Hyprland widget."
        warn "Example: https://calendar.google.com/calendar/ical/YOUR_EMAIL/public/basic.ics"
        read -l -P "Enter your calendar ICS URL (leave blank to skip): " cal_url
        if test -n "$cal_url"
            if test $DRY_RUN = true
                echo $YELLOW"[dry-run]"$RESET" Would write .calendar-url: $cal_url"
            else
                echo $cal_url > $cal_real
                info "Written: $cal_real"
            end
        else
            warn "Skipped .calendar-url. Set it later: echo 'YOUR_URL' > ~/.config/hypr/.calendar-url"
        end
    end

    # wallhaven.json — inform user, don't overwrite full JSON
    set -l wh_real $HOME/.config/aether/wallhaven.json

    if test -f $wh_real
        info "wallhaven.json already exists — skipping."
    else
        warn "wallhaven.json not found."
        warn "Get your API key from: https://wallhaven.cc/settings/account"
        read -l -P "Enter your wallhaven API key (leave blank to skip): " wh_key
        if test -n "$wh_key"
            if test $DRY_RUN = true
                echo $YELLOW"[dry-run]"$RESET" Would write wallhaven.json with apiKey: $wh_key"
            else
                # Write full JSON structure with provided key
                echo "{
  \"apiKey\": \"$wh_key\",
  \"categories\": \"110\",
  \"order\": \"desc\",
  \"purity\": \"100\",
  \"purityControlsEnabled\": true,
  \"resolutions\": \"1920x1080\",
  \"sorting\": \"date_added\"
}" > $wh_real
                info "Written: $wh_real"
            end
        else
            warn "Skipped wallhaven.json. Copy the sample and edit it: cp $DOTS_DIR/aether/aether/wallhaven.json.sample $wh_real"
        end
    end

    info "Secrets configuration complete."
end

# ── 10. configure_monitors ─────────────────────────────────────────────────────
function configure_monitors
    set -l monitors_conf $HOME/.config/hypr/monitors.conf

    echo ""
    echo "$YELLOW$BOLD╔══════════════════════════════════════════════════════╗$RESET"
    echo "$YELLOW$BOLD║          MONITORS.CONF IS MACHINE-SPECIFIC          ║$RESET"
    echo "$YELLOW$BOLD╚══════════════════════════════════════════════════════╝$RESET"
    echo ""

    if command -q hyprctl
        info "Generating monitors.conf from this machine's detected hardware..."
        run fish $DOTS_DIR/generate-monitors.fish
        or warn "Auto-generation failed — the copied monitors.conf (from wherever it came from) is still in place below."
    else
        warn "hyprctl not available (not running inside Hyprland yet) — cannot auto-detect monitors."
        warn "Re-run: fish $DOTS_DIR/generate-monitors.fish   (from inside Hyprland, once logged in)"
    end

    echo ""
    if test -f $monitors_conf
        echo "$BOLD--- Current monitors.conf ---$RESET"
        cat $monitors_conf
        echo "$BOLD----------------------------$RESET"
    else
        warn "No monitors.conf found."
    end
    echo ""
    warn "If you have multiple monitors and want a different arrangement than"
    warn "left-to-right in detection order, edit $monitors_conf by hand."

    if test $DRY_RUN = false
        if test -n "$EDITOR"
            read -l -P "Open monitors.conf in $EDITOR? [y/N] " answer
            if string match -qi 'y' $answer
                $EDITOR $monitors_conf
            end
        else
            warn "\$EDITOR is not set. Edit manually: $monitors_conf"
        end
    end
end

# ── 11. sync_neovim ───────────────────────────────────────────────────────────
function sync_neovim
    info "Running headless Neovim plugin sync..."

    if not command -q nvim
        warn "nvim not found — skipping plugin sync."
        return 0
    end

    run nvim --headless "+Lazy! sync" +qa
    or begin
        warn "Neovim sync returned non-zero — check for plugin errors on first open."
        return 0
    end

    info "Neovim sync complete."
end

# ── 12. set_default_shell ──────────────────────────────────────────────────────
function set_default_shell
    set -l fish_path (command -v fish)
    if test "$SHELL" != "$fish_path"
        warn "Default shell is not fish."
        if test $DRY_RUN = true
            echo $YELLOW"[dry-run]"$RESET" Would prompt to set fish ($fish_path) as your default shell."
            return 0
        end
        read -l -P "Set fish ($fish_path) as your default shell? [y/N] " answer
        if string match -qi 'y' $answer
            run chsh -s $fish_path
        end
    else
        info "fish is already your default shell."
    end
end

# ── 13. baseline_migrations ────────────────────────────────────────────────────
function baseline_migrations
    info "Marking existing migrations as already applied (fresh install already has them)..."
    run fish $DOTS_DIR/migrate.fish --baseline
end

# ── Main ──────────────────────────────────────────────────────────────────────
check_prerequisites
or exit 1

install_packages
or exit 1

clone_repo
or exit 1

copy_packages
or exit 1

install_fisher
or exit 1

run_mise
or exit 1

install_npm_globals
or exit 1

activate_theme
or exit 1

configure_secrets
or exit 1

configure_monitors

sync_neovim
or exit 1

set_default_shell

baseline_migrations
or exit 1

echo ""
info "$BOLD Restore complete.$RESET"
info "Your Arch + Omarchy + Hyprland environment is ready."
info "Log out and back in (or reboot) to apply all changes."
