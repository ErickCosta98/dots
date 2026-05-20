#!/usr/bin/env fish
# dots/install.fish — idempotent restore script for Arch + Omarchy + Hyprland
# Usage: fish install.fish [--dry-run]

# ── Color palette ──────────────────────────────────────────────────────────────
set -l GREEN  (set_color green)
set -l YELLOW (set_color yellow)
set -l RED    (set_color red)
set -l BOLD   (set_color --bold)
set -l RESET  (set_color normal)

# ── Flags ──────────────────────────────────────────────────────────────────────
set -l DRY_RUN false
if contains -- --dry-run $argv
    set DRY_RUN true
    echo "$YELLOW[dry-run]$RESET No changes will be made — commands are printed only."
end

set -l DOTS_DIR $HOME/Work/dots

# ── Helper functions ───────────────────────────────────────────────────────────
function info
    echo "$GREEN[info]$RESET  $argv"
end

function warn
    echo "$YELLOW[warn]$RESET  $argv"
end

function error
    echo "$RED[error]$RESET $argv" >&2
end

function run
    if test $DRY_RUN = true
        echo "$YELLOW[dry-run]$RESET $argv"
    else
        eval $argv
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

    if not command -q stow
        error "stow is not installed. Run: sudo pacman -S stow"
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

# ── 4. backup_conflicts ────────────────────────────────────────────────────────
function backup_conflicts -a pkg
    set -l timestamp (date +%s)
    set -l conflicts (stow --target=$HOME/.config --simulate --restow --dir=$DOTS_DIR $pkg 2>&1 | grep -i 'CONFLICT\|existing target\|already exists')

    if test -z "$conflicts"
        return 0
    end

    warn "Conflicts found in package '$pkg' — backing up originals..."
    for line in $conflicts
        # Extract the conflicting target path from stow output
        set -l target_path (echo $line | grep -oP '(?<=existing target is )[^\s]+' | head -1)
        if test -n "$target_path"
            set -l full_path $HOME/.config/$target_path
            if test -e $full_path
                run mv $full_path $full_path.dotbak.$timestamp
                warn "Backed up: $full_path -> $full_path.dotbak.$timestamp"
            end
        end
    end
end

# ── 5. stow_packages ──────────────────────────────────────────────────────────
function stow_packages
    info "Stowing all packages into ~/.config/..."

    set -l packages \
        aether nvim fish hypr waybar \
        ghostty alacritty walker voxtype \
        mise atuin starship 1password \
        btop swayosd spotify-player

    for pkg in $packages
        set -l pkg_dir $DOTS_DIR/$pkg
        if not test -d $pkg_dir
            warn "Package directory not found: $pkg_dir — skipping."
            continue
        end

        info "Stowing $pkg..."
        backup_conflicts $pkg
        run stow --target=$HOME/.config --restow --dir=$DOTS_DIR $pkg
        or begin
            error "Failed to stow package: $pkg"
            return 1
        end
    end

    info "All packages stowed."
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

# ── 8. activate_theme ─────────────────────────────────────────────────────────
function activate_theme
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
                echo "$YELLOW[dry-run]$RESET Would write .calendar-url: $cal_url"
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
                echo "$YELLOW[dry-run]$RESET Would write wallhaven.json with apiKey: $wh_key"
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

# ── 10. warn_monitors ─────────────────────────────────────────────────────────
function warn_monitors
    set -l monitors_conf $HOME/.config/hypr/monitors.conf

    echo ""
    echo "$YELLOW$BOLD╔══════════════════════════════════════════════════════╗$RESET"
    echo "$YELLOW$BOLD║          MONITORS.CONF IS MACHINE-SPECIFIC          ║$RESET"
    echo "$YELLOW$BOLD╚══════════════════════════════════════════════════════╝$RESET"
    echo ""
    warn "monitors.conf contains monitor names, resolutions, and positions"
    warn "that are specific to this machine's hardware."
    warn "You MUST edit it for new hardware before rebooting into Hyprland."
    echo ""

    if test -f $monitors_conf
        echo "$BOLD--- Current monitors.conf ---$RESET"
        cat $monitors_conf
        echo "$BOLD----------------------------$RESET"
        echo ""
    end

    if test $DRY_RUN = false
        if test -n "$EDITOR"
            read -l -P "Open monitors.conf in $EDITOR? [y/N] " answer
            if string match -qi 'y' $answer
                eval $EDITOR $monitors_conf
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

# ── Main ──────────────────────────────────────────────────────────────────────
check_prerequisites
or exit 1

install_packages
or exit 1

clone_repo
or exit 1

stow_packages
or exit 1

install_fisher
or exit 1

run_mise
or exit 1

activate_theme
or exit 1

configure_secrets
or exit 1

warn_monitors

sync_neovim
or exit 1

echo ""
info "$BOLD Restore complete.$RESET"
info "Your Arch + Omarchy + Hyprland environment is ready."
info "Log out and back in (or reboot) to apply all changes."
