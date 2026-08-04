#!/usr/bin/env fish
# dots/migrate.fish — apply only NEW dotfile changes since your last update,
# without reinstalling packages or recopying everything from scratch.
#
# Use this for day-2 updates (git pull + migrate). Use install.fish only for
# the initial bootstrap of a machine.
#
# Usage:
#   fish migrate.fish              # run all pending migrations
#   fish migrate.fish --dry-run    # show what would run, without running it
#   fish migrate.fish --new "desc" # scaffold a new migration file
#   fish migrate.fish --baseline   # mark all existing migrations as already
#                                  # applied (used by install.fish on a fresh
#                                  # bootstrap, and safe to run manually on a
#                                  # machine you know is already up to date)

set -g GREEN  (set_color green)
set -g YELLOW (set_color yellow)
set -g RED    (set_color red)
set -g RESET  (set_color normal)

set -g DOTS_DIR $HOME/Work/dots
set -g STATE_DIR $HOME/.local/state/dots/migrations
set -g MIGRATIONS_DIR $DOTS_DIR/migrations

function info
    echo $GREEN"[info]"$RESET"  $argv"
end

function warn
    echo $YELLOW"[warn]"$RESET"  $argv"
end

function error
    echo $RED"[error]"$RESET" $argv" >&2
end

mkdir -p $STATE_DIR/skipped
mkdir -p $MIGRATIONS_DIR

# ── --new: scaffold a new migration file ──────────────────────────────────
if test "$argv[1]" = "--new"
    set -l desc $argv[2..-1]
    set -l ts (date +%s)
    set -l file $MIGRATIONS_DIR/$ts.fish

    echo "#!/usr/bin/env fish
# $desc
" > $file
    chmod +x $file

    info "Created migration: $file"
    if test -n "$EDITOR"
        eval $EDITOR $file
    else
        warn "\$EDITOR is not set. Edit manually: $file"
    end
    exit 0
end

# ── --baseline: mark every existing migration as already applied ─────────
if test "$argv[1]" = "--baseline"
    for file in $MIGRATIONS_DIR/*.fish
        test -e $file
        or continue
        touch $STATE_DIR/(basename $file)
    end
    info "Baseline complete — all current migrations marked as applied."
    exit 0
end

set -l DRY_RUN false
if contains -- --dry-run $argv
    set DRY_RUN true
    info "Dry run — no migrations will actually be executed."
end

# ── Run pending migrations, in filename (timestamp) order ────────────────
set -l pending 0

for file in (find $MIGRATIONS_DIR -maxdepth 1 -name '*.fish' 2>/dev/null | sort)
    set -l name (basename $file)

    if test -f $STATE_DIR/$name
        continue
    end
    if test -f $STATE_DIR/skipped/$name
        continue
    end

    set pending (math $pending + 1)

    if test $DRY_RUN = true
        echo $YELLOW"[dry-run]"$RESET" would run: $name"
        continue
    end

    info "Running migration $name..."
    if fish $file
        touch $STATE_DIR/$name
        info "Migration $name applied."
    else
        error "Migration $name failed."
        read -l -P "Skip this migration and continue? [y/N] " answer
        if string match -qi 'y' $answer
            touch $STATE_DIR/skipped/$name
        else
            exit 1
        end
    end
end

if test $pending -eq 0
    info "No pending migrations. Already up to date."
else if test $DRY_RUN = false
    info "All pending migrations applied."
end
