# erick.lan-mouse

Manages the [lan-mouse](https://github.com/feschber/lan-mouse) daemon —
keyboard/mouse sharing across machines — as a first-party QuickShell plugin,
replacing `erick.input-leap`.

## Why this replaced Input Leap

Input Leap's default backend needs the
`org.freedesktop.portal.RemoteDesktop`/`InputCapture` xdg-desktop-portal
interfaces, which `xdg-desktop-portal-hyprland` doesn't implement on this
session. Its `--use-x11` fallback only injects input into Xwayland, not
native Wayland apps — verified broken here. `lan-mouse` is a different,
actively maintained tool (Arch's official `extra/lan-mouse`, not AUR) built
around `wlr-layer-shell` for capture and wlroots input emulation, which
works on this Hyprland session without any portal.

## What it does

- Starts/stops/restarts the lan-mouse daemon as a tracked
  `Quickshell.Io.Process`, using the one backend combination verified to
  work on this machine (see **CLI invocation**).
- Detects a daemon already running — whether started by this shell or
  externally (e.g. from a terminal) — via `lan-mouse cli list`'s exit code,
  since lan-mouse has an IPC socket to probe instead of needing a pidfile
  or `pgrep` poll.
- Lists configured/paired clients (hostname, port, position, active state)
  by parsing `lan-mouse cli list`'s plain-text output — see
  **Known limitations**.
- Adds/removes clients and toggles their active/position state via real
  `lan-mouse cli add-client` / `remove-client` / `activate` / `deactivate` /
  `set-position` calls, persisting each change with `lan-mouse cli
  save-config`.
- Shows a bar indicator (mouse glyph + status dot) with a popup listing
  paired machines and daemon start/stop/restart controls.

Unlike Input Leap's client/server session model, lan-mouse's daemon is a
single process with a list of paired clients, each independently
active/inactive — there is no "connected/disconnected" transport state to
track, so this plugin's `state` only reflects the daemon process itself:
`"stopped"`, `"starting"`, `"running"`, or `"error"`.

## Registration

Discovered via `manifest.json` (`id: "erick.lan-mouse"`, kinds `service` +
`bar-widget"`) and wired into the bar via `omarchy/shell.json`'s
`bar.layout.right` array, in the same slot `erick.input-leap` used to
occupy (next to `omarchy.tailscale`):

```json
{ "id": "erick.lan-mouse" }
```

## Configuration / persistence

This plugin does **not** keep its own config file. lan-mouse owns its
config at `~/.config/lan-mouse/config.toml` (a `[[clients]]` array with
`hostname`, `ips`, `port`, `position`, `activate_on_startup`, plus an
`[authorized_fingerprints]` table) and persists it itself whenever the
plugin runs `lan-mouse cli save-config` after an add/remove/activate/
deactivate/set-position call. Edit `config.toml` by hand if you need
something the CLI/plugin doesn't expose (e.g. `activate_on_startup`).

## CLI invocation

Daemon: `lan-mouse --capture-backend layer-shell --emulation-backend wlroots daemon`

Global flags (`--capture-backend`, `--emulation-backend`) must come
**before** the `daemon` subcommand — `lan-mouse daemon --capture-backend
...` fails with "unexpected argument" (verified). `layer-shell`/`wlroots`
is the only backend pair verified to start cleanly on this Hyprland
session (log: `using capture backend: layer-shell`, `using emulation
backend: wlroots`, `active outputs: ...`) — other values exist
(`input-capture-portal`/`x11`/`dummy` for capture, `libei`/`xdp`/`x11`/
`dummy` for emulation) but aren't exposed here since they weren't verified
to work without the missing portal.

Everything else goes through `lan-mouse cli <subcommand>`:

| Action | Command |
|---|---|
| Detect daemon / list clients | `lan-mouse cli list` |
| Add a client | `lan-mouse cli add-client --hostname <host> [--port <port>]` |
| Remove a client | `lan-mouse cli remove-client <id>` |
| Activate/deactivate | `lan-mouse cli activate <id>` / `lan-mouse cli deactivate <id>` |
| Set position | `lan-mouse cli set-position <id> <left\|right\|top\|bottom>` |
| Persist changes | `lan-mouse cli save-config` |

`lan-mouse cli list` prints one line per configured client, e.g.:

```
id 0: 100.127.32.118:4242 (right) active: true, ips: {100.127.32.118}
```

With no daemon reachable it exits 1 with stderr
`` could not connect: `connection timed out` - is the service running? `` —
this plugin uses that exit code (not a pgrep poll) to tell whether a
daemon is up, and whether it was started by this shell (`managedProcess`)
or externally (`externallyManaged`).

## Pairing with the Windows laptop

This plugin only manages the **local** (Hyprland) side. The Windows laptop
needs its own lan-mouse instance — an official Windows build is published
on the project's [GitHub releases](https://github.com/feschber/lan-mouse/releases)
(e.g. `lan-mouse-windows-x86_64.zip`). Add each machine as a client pointing
at the other: on this laptop, add the Windows machine's hostname/IP via
this plugin's popup; on Windows, add this laptop's hostname/IP the same
way in its own lan-mouse UI/config. Windows-side setup steps beyond "the
official release exists" are not verified here — follow lan-mouse's own
Windows documentation.

## Known limitations

- **Plain-text `cli list` parsing is fragile.** The output format
  (`id N: host:port (position) active: bool, ips: {...}`) is not a stable
  JSON/machine-readable contract — a future lan-mouse version could reword
  it. `parseListOutput()` in `Service.qml` tolerates non-matching lines
  (skips them) instead of throwing, but a wording change means clients
  silently stop showing up. Re-check the regex against `lan-mouse cli list`
  output if that happens.
- **No way to stop an externally-managed daemon.** `lan-mouse cli` has no
  stop/quit/shutdown subcommand (verified via `lan-mouse cli --help`). If
  a daemon was started outside this plugin (terminal, another session),
  `externallyManaged` becomes true and the Stop/Restart buttons are
  disabled — only Start (for this shell's own instance) is meaningful.
- **Windows side unmanaged.** This plugin has no visibility into or
  control over the Windows laptop's lan-mouse instance.
- **`add-client` has no `--position` flag.** New clients get whatever
  position lan-mouse defaults new entries to; use "Set position" (per-row
  Activate/Deactivate/Remove buttons plus the service's `setPosition()`)
  to adjust afterward.

## Troubleshooting

- **"lan-mouse not found"**: install the official package —
  `sudo pacman -S lan-mouse` (it's in Arch's `extra` repo, not AUR). The
  service checks `command -v lan-mouse` before spawning and sets this
  error instead of failing silently.
- **Stuck on "Starting…"**: check `journalctl -t omarchy-shell` for the
  daemon's own log lines, or run the daemon command by hand in a terminal
  to see its output directly:
  `lan-mouse --capture-backend layer-shell --emulation-backend wlroots daemon`
- **Clients not appearing / list looks empty**: run
  `lan-mouse cli list` by hand and compare its output to the regex in
  `Service.qml`'s `parseListOutput()` — see **Known limitations**.
- **Can't stop the daemon from the bar widget**: it's probably
  externally-managed (started from a terminal or a previous session) —
  see **Known limitations**. Stop it the way it was started (e.g. Ctrl-C
  in its terminal, or `pkill lan-mouse`).
