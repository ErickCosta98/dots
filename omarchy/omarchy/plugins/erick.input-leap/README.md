# erick.input-leap

Manages an [Input Leap](https://github.com/input-leap/input-leap) client
(`input-leapc`) or server (`input-leaps`) process — keyboard/mouse sharing
across machines — as a first-party QuickShell plugin, mirroring the
structure of `erick.media` and `erick.lock`.

## What it does

- Starts/stops/restarts `input-leapc` or `input-leaps` as a tracked
  `Quickshell.Io.Process`, so real lifecycle signals (`started`, `exited`)
  drive the service state.
- Detects a copy started outside the shell (e.g. from a terminal) via a
  periodic `pgrep -x input-leapc`/`pgrep -x input-leaps` poll, since there is
  no systemd unit, pidfile, or socket to hook into on this system.
- Infers connection state (connected/disconnected/error) by pattern-matching
  the process's stdout/stderr for phrases like "connected to server" —
  see **Limitations** below.
- Shows a bar indicator (mouse glyph + status dot) with a popup for
  mode/server/bind-address settings and start/stop/restart controls.
- Persists `mode`, `serverHost`, `serverAddress`, `remoteScreenName`, and
  `autoStart` to `~/.config/quickshell/input-leap.conf` as plain JSON.
- In server mode, auto-generates the two-screen topology config
  `input-leaps` requires (see **CLI invocation**) from the local hostname
  and the configured remote screen name — `input-leaps` refuses to start
  without one ("no configuration available").

## Registration

Like `erick.media`/`erick.lock`, this plugin is discovered via its
`manifest.json` (`id: "erick.input-leap"`, kinds `service` + `bar-widget`).
It's wired into the bar via `omarchy/shell.json`'s `bar.layout.right` array
(next to `omarchy.tailscale`):

```json
{ "id": "erick.input-leap" }
```

To enable/disable the bar widget, add or remove that entry from
`bar.layout.right` (or move it to any other layout section) in
`omarchy/shell.json`. The service loads regardless (`keepLoaded: true` in
the manifest), matching `erick.media`'s convention.

## Configuration

Edit settings from the bar popup, or directly in
`~/.config/quickshell/input-leap.conf`:

```json
{
  "mode": "client",
  "serverHost": "192.168.1.10",
  "serverAddress": "",
  "remoteScreenName": "",
  "autoStart": false
}
```

- `mode`: `"client"` runs `input-leapc`, `"server"` runs `input-leaps`.
- `serverHost`: required in client mode — the Input Leap server's address
  (positional argument to `input-leapc`).
- `serverAddress`: optional in server mode — passed as `input-leaps --address <value>`.
- `remoteScreenName`: required in server mode — the hostname of the other
  laptop, used to build the topology config (see **CLI invocation**).
- `autoStart`: if `true`, the service starts automatically once config
  loads at shell startup.

## CLI invocation

- Client: `input-leapc --no-daemon --disable-crypto --use-x11 --name <localScreenName> <serverHost>`
- Server: `input-leaps --no-daemon --disable-crypto --use-x11 --config <serverTopologyPath> --name <localScreenName> [--address <serverAddress>]`

`--disable-crypto` is always passed: connecting with Input Leap's default
TLS failed with `ssl certificate doesn't exist:
~/.config/InputLeap/SSL/InputLeap.pem` (verified against the real binary)
— nothing here generates that certificate. **Both machines must agree**:
the other side's Input Leap (GUI or CLI) also needs SSL/encryption
disabled in its own settings, or the connection opens and is immediately
closed with no further log line. This assumes the transport itself is
already encrypted (e.g. a Tailscale link) since Input Leap's own
encryption is off.

`--use-x11` is always passed: Input Leap's default backend needs the
`org.freedesktop.portal.RemoteDesktop` xdg-desktop-portal interface, which
this Hyprland session's portal doesn't implement — it fails immediately
with `No such interface`. `--use-x11` forces the legacy Xwayland input
path instead, which Input Leap itself warns is a limited fallback
("Running against Xwayland. InputLeap will not work as expected"). Switch
to `--use-ei` in `Service.qml`'s `buildCommand()` once this session's
portal setup supports the EI backend — not verified as available here.
`--name <localScreenName>` (the machine's own `hostname` output) is
passed in both modes so the other side's screen-name matching works:
whatever screen name the other machine's Input Leap expects for this
machine must match this laptop's actual hostname.

Both are run with `--no-daemon` so the process stays foreground and attached
to the QuickShell `Process` — this is required for real lifecycle tracking
(`running`/`exited`), rather than forking into a background daemon this
shell can no longer see.

`input-leaps` requires a config file declaring at least two screens and a
link between them — starting it without one fails with
`input-leaps: no configuration available`. On `start()` in server mode, the
service runs `hostname` to get the local screen name, then writes a minimal
left/right topology to `~/.config/quickshell/input-leap-server.conf`:

```
section: screens
	<local-hostname>:
	<remoteScreenName>:
end

section: links
	<local-hostname>:
		right = <remoteScreenName>
	<remoteScreenName>:
		left = <local-hostname>
end
```

This assumes a simple two-machine, side-by-side layout (local on the left,
remote on the right — move the mouse off the right edge to reach the other
laptop). The service **overwrites** this file every time `start()` runs in
server mode, so a different layout (top/bottom, more than two screens,
aliases) can't be hand-edited in place — it would need the topology
generation in `Service.qml`'s `buildServerTopology()` changed instead.

## IPC

Mirrors the `IpcHandler` pattern used by `erick.media`/`erick.lock`, under
target `input-leap`: `start`, `stop`, `restart`, `status` (JSON), `ping`.

## Known limitations

- **Log-string connection detection.** input-leapc/input-leaps write
  connection status to stdout/stderr, but the exact wording is not
  guaranteed across Input Leap versions. The service does a
  case-insensitive substring match for phrases like "connected to server",
  "connection refused", and "disconnected" — if a given version phrases
  this differently, `state` may get stuck on `"running"` instead of
  advancing to `"connected"`/`"disconnected"`. Adjust `classifyLine()` in
  `Service.qml` if this happens on your version.
- **No systemd/socket detection.** There's no pidfile or IPC surface for
  Input Leap on this system, so an externally-started process is only
  noticed via a 5-second `pgrep -x` poll — expect up to a 5s delay before
  the bar widget reflects a process started from a terminal.
- **Icon glyph is a judgment call.** No mouse/keyboard-sharing hardware
  icon convention exists elsewhere in this repo's bar widgets to copy from;
  the widget uses the Material Design Icons "mouse" Nerd Font glyph (󰍽) as
  the closest available match. Same for the error-state glyph (󰀦, "alert").
  Swap either in `BarWidget.qml` if a better convention emerges.
- **`input-leap` GUI launcher not used.** Only `input-leapc`/`input-leaps`
  CLI binaries are invoked; the bundled `input-leap` GUI binary's CLI
  surface (if any) was not verified and is intentionally not used here.

## Troubleshooting

- **"Input Leap not found"**: install the AUR package, e.g.
  `yay -S input-leap-bin`. The service checks `command -v input-leapc` /
  `command -v input-leaps` before spawning and sets this error instead of
  silently failing if the binary is missing.
- **"Unable to connect" / connection refused**: check that the target
  machine's Input Leap server/client is running, the address/port is
  correct, and no firewall is blocking the connection (Input Leap defaults
  to TCP port 24800). A LAN IP blocked by the other machine's firewall
  but a Tailscale IP reaching the same port fine is a common split —
  verified with `bash -c 'cat < /dev/null > /dev/tcp/<ip>/24800'`; prefer
  the Tailscale address in that case.
- **Socket opens then immediately closes, no error, retries forever**: an
  encryption mismatch — one side has Input Leap's TLS enabled and the
  other doesn't. Since this plugin always passes `--disable-crypto` (see
  **CLI invocation**), disable SSL/encryption on the other machine's
  Input Leap too.
- **"No such interface" / RemoteDesktop portal error**: this Hyprland
  session's `xdg-desktop-portal` doesn't implement
  `org.freedesktop.portal.RemoteDesktop`. The plugin already forces
  `--use-x11` to route around this — if you still see this error, check
  that the deployed `Service.qml` actually includes `--use-x11` in
  `buildCommand()`.
- **Screen name mismatch**: `--name` is always the output of `hostname`.
  The other machine's Input Leap config must reference this exact name
  for this laptop's screen — in server mode, that's the plugin's
  auto-generated topology; in client mode against a GUI-run server, check
  what screen name the GUI expects and rename this laptop (or the GUI's
  entry) to match.
- **State stuck on "running" and never reaches "connected"**: your Input
  Leap version likely logs a different connection-success phrase — see
  **Known limitations** above.
