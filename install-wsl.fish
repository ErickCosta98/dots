#!/usr/bin/env fish
# dots/install-wsl.fish — copies terminal-only config (fish, starship, nvim,
# mise, atuin) into ~/.config/ on WSL. No Hyprland/Waybar/Omarchy — desktop
# packages excluded. Files are copied, not symlinked — edits under ~/.config/
# won't propagate back to the repo.
# Invoked via install-wsl.sh, which installs the bash-only prerequisites first.

set -g GREEN  (set_color green)
set -g YELLOW (set_color yellow)
set -g RED    (set_color red)
set -g BOLD   (set_color --bold)
set -g RESET  (set_color normal)

set -g DOTS_DIR $HOME/Work/dots

function info
    printf '%s[info]%s  %s\n' $GREEN $RESET "$argv"
end

function warn
    printf '%s[warn]%s  %s\n' $YELLOW $RESET "$argv"
end

function error
    printf '%s[error]%s %s\n' $RED $RESET "$argv" >&2
end

function copy_packages
    info "Copying terminal packages into ~/.config/..."

    set -l packages fish starship nvim mise atuin

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
        rm -rf $pkg_dst
        mkdir -p $pkg_dst
        cp -rT $pkg_src $pkg_dst
        or begin
            error "Failed to copy package: $pkg"
            return 1
        end
    end

    info "Terminal packages copied."
end

function install_fisher
    info "Installing Fisher plugins from fishfile..."

    if not command -q fisher
        warn "fisher is not installed — installing it first..."
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
        or return 1
    end

    fish -c "fisher update"
    or return 1

    info "Fisher plugins installed."
end

function run_mise
    info "Installing tool runtimes via mise..."

    if not command -q mise
        error "mise is not installed."
        return 1
    end

    mise install
    or return 1

    info "mise install complete."
end

function sync_neovim
    info "Running headless Neovim plugin sync..."

    if not command -q nvim
        warn "nvim not found — skipping plugin sync."
        return 0
    end

    nvim --headless "+Lazy! sync" +qa
    or begin
        warn "Neovim sync returned non-zero — check for plugin errors on first open."
        return 0
    end

    info "Neovim sync complete."
end

function set_default_shell
    set -l fish_path (command -v fish)
    if test "$SHELL" != "$fish_path"
        warn "Default shell is not fish."
        read -l -P "Set fish ($fish_path) as your default shell? [y/N] " answer
        if string match -qi 'y' $answer
            chsh -s $fish_path
        end
    end
end

# ── Main ──────────────────────────────────────────────────────────────────────
if not test -d $DOTS_DIR/.git
    error "dots repository not found at $DOTS_DIR — clone it there first."
    exit 1
end

copy_packages
or exit 1

install_fisher
or exit 1

run_mise
or exit 1

sync_neovim
or exit 1

set_default_shell

echo ""
info "$BOLD Terminal restore complete.$RESET"
info "Restart your WSL shell (or run 'exec fish') to apply changes."
