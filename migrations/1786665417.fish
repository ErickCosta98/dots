#!/usr/bin/env fish
# opencode isn't a first-party collector for omarchy's Agents bar panel
# (only claude/codex/fireworks ship in-box), but the panel picks up any
# JSON record dropped in ~/.local/state/omarchy/agents/usage/, regardless
# of who wrote it. This installs a small collector that reads opencode's
# own local session storage and a systemd --user timer to refresh it every
# 15 minutes (same cadence as the panel's default refreshIntervalSec), so
# opencode gets its own tab next to claude/codex.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/agents
cp $DOTS_DIR/omarchy/omarchy/agents/opencode-usage-collector $HOME/.config/omarchy/agents/opencode-usage-collector
chmod +x $HOME/.config/omarchy/agents/opencode-usage-collector

mkdir -p $HOME/.config/systemd/user
cp $DOTS_DIR/systemd/systemd/user/omarchy-agent-usage-opencode.service $HOME/.config/systemd/user/omarchy-agent-usage-opencode.service
cp $DOTS_DIR/systemd/systemd/user/omarchy-agent-usage-opencode.timer $HOME/.config/systemd/user/omarchy-agent-usage-opencode.timer

systemctl --user daemon-reload
systemctl --user enable --now omarchy-agent-usage-opencode.timer

# Generate the first record immediately instead of waiting for OnBootSec.
$HOME/.config/omarchy/agents/opencode-usage-collector

if command -q omarchy
    omarchy restart shell
end
