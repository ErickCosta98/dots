#!/usr/bin/env bash
# dots/install-wsl.sh — bootstrap for WSL (Arch Linux): installs bash-only
# prerequisites (fish itself isn't installed yet, so this can't be a fish
# script), then hands off to install-wsl.fish for stowing/config.
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo -e "\033[32m[info]\033[0m  $*"; }
warn() { echo -e "\033[33m[warn]\033[0m  $*"; }
error() { echo -e "\033[31m[error]\033[0m $*" >&2; }

if ! grep -qi microsoft /proc/version 2>/dev/null; then
    warn "This doesn't look like WSL — continuing anyway."
fi

if ! command -v pacman >/dev/null 2>&1; then
    error "pacman not found. This script targets Arch-based WSL distros."
    exit 1
fi

# Prefer yay if present so AUR packages (e.g. atuin, mise) can be pulled the
# same way; fall back to pacman for the base install.
PKG_INSTALL=(sudo pacman -S --needed --noconfirm)
if command -v yay >/dev/null 2>&1; then
    PKG_INSTALL=(yay -S --needed --noconfirm)
fi

info "Syncing package databases..."
sudo pacman -Sy

info "Installing base packages via ${PKG_INSTALL[0]}..."
"${PKG_INSTALL[@]}" \
    fish stow git curl wget base-devel \
    ripgrep fd fzf bat unzip neovim

if ! command -v starship >/dev/null 2>&1; then
    info "Installing starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

if ! command -v mise >/dev/null 2>&1; then
    info "Installing mise..."
    curl -fsSL https://mise.run | sh
fi

if ! command -v atuin >/dev/null 2>&1; then
    info "Installing atuin..."
    curl -fsSL https://setup.atuin.sh | sh
fi

info "Base tools installed. Handing off to install-wsl.fish..."
exec fish "$DOTS_DIR/install-wsl.fish" "$@"
