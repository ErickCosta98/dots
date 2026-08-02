#!/usr/bin/env bash
# dots/install-wsl.sh — bootstrap for WSL (Ubuntu/Debian): installs bash-only
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

if ! command -v apt-get >/dev/null 2>&1; then
    error "apt-get not found. This script targets Ubuntu/Debian-based WSL distros."
    exit 1
fi

info "Updating apt package index..."
sudo apt-get update

info "Installing base packages via apt..."
sudo apt-get install -y --no-install-recommends \
    fish stow git curl wget build-essential \
    ripgrep fd-find fzf bat unzip

# Debian/Ubuntu ship fd and bat under different binary names.
mkdir -p "$HOME/.local/bin"
[ -e "$HOME/.local/bin/fd" ] || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd" 2>/dev/null || true
[ -e "$HOME/.local/bin/bat" ] || ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat" 2>/dev/null || true

if ! command -v nvim >/dev/null 2>&1; then
    info "Installing latest Neovim (apt's version is usually stale)..."
    curl -fsSL -o /tmp/nvim-linux-x86_64.tar.gz \
        https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm /tmp/nvim-linux-x86_64.tar.gz
fi

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
