#!/usr/bin/env fish
# Offer to set fish as the default login shell (install.fish didn't have this
# step before, so earlier restores left the default shell as bash).

set -l fish_path (command -v fish)
if test "$SHELL" != "$fish_path"
    read -l -P "Set fish ($fish_path) as your default shell? [y/N] " answer
    if string match -qi 'y' $answer
        chsh -s $fish_path
    end
else
    echo "fish is already the default shell."
end
