import QtQuick
import Quickshell
import Quickshell.Io

// Manages the lan-mouse daemon (github.com/feschber/lan-mouse) — a
// wlr-layer-shell-capture + wlroots-emulation KVM-style mouse/keyboard
// sharer that (unlike Input Leap) actually works on this Hyprland session
// without needing the missing xdg-desktop-portal-hyprland InputCapture/
// RemoteDesktop portal implementations.
//
// lan-mouse owns its own config (~/.config/lan-mouse/config.toml) and its
// own IPC surface (`lan-mouse cli ...` talks to the running daemon over a
// local socket) — this plugin does NOT maintain a separate config file. It
// only:
//   1. Spawns/tracks the daemon as a Quickshell Process (verified working
//      invocation: global flags BEFORE the `daemon` subcommand).
//   2. Shells out to `lan-mouse cli ...` for everything else, including
//      detecting whether a daemon (ours or external) is already up.
//
// lan-mouse's unit of pairing is a client entry with `active: true/false` —
// there is no persistent TCP session/handshake state machine the way Input
// Leap had, so this Service deliberately does not expose a "connected/
// disconnected" state. `state` only ever reflects the daemon process:
// "stopped" | "starting" | "running" | "error".
Item {
  id: root

  property var shell: null

  // "stopped" | "starting" | "running" | "error"
  property string state: "stopped"
  property string errorMessage: ""

  // true once `lan-mouse cli list` succeeds while this shell's own
  // managedProcess is NOT running — i.e. some other daemon instance
  // (started from a terminal, or a previous session) answered instead.
  // lan-mouse's cli has no stop/quit/shutdown subcommand (verified via
  // `lan-mouse cli --help`), so an externally-started daemon can only be
  // observed here, never stopped from this plugin.
  property bool externallyManaged: false

  // Parsed from `lan-mouse cli list`, one entry per configured client:
  // { id: int, hostname: string, port: int, position: string,
  //   active: bool, ips: [string] }
  property var clients: []

  readonly property bool daemonUp: state === "running"

  // --- daemon lifecycle ---

  // Verified on this machine: global flags (--capture-backend,
  // --emulation-backend) must come BEFORE the `daemon` subcommand —
  // `lan-mouse daemon --capture-backend ...` errors with "unexpected
  // argument". layer-shell/wlroots is the only backend pair verified to
  // start cleanly here (log: "using capture backend: layer-shell",
  // "using emulation backend: wlroots", "active outputs: ..."), since
  // xdg-desktop-portal-hyprland doesn't implement the InputCapture/
  // RemoteDesktop portals the other backends need. Other backend values
  // exist (input-capture-portal/x11/dummy, libei/xdp/x11/dummy) but are
  // intentionally not exposed here — this pair is hardcoded.
  readonly property var daemonCommand: ["lan-mouse", "--capture-backend", "layer-shell", "--emulation-backend", "wlroots", "daemon"]

  function start() {
    if (managedProcess.running) return
    if (root.externallyManaged) return

    root.state = "starting"
    root.errorMessage = ""
    binaryCheckProc.command = ["bash", "-c", "command -v lan-mouse"]
    binaryCheckProc.running = true
  }

  property bool _stopping: false

  function stop() {
    if (managedProcess.running) {
      root._stopping = true
      managedProcess.running = false
      return
    }
    // Nothing this plugin can do about an externally-managed daemon — see
    // externallyManaged doc comment above.
    if (root.state !== "error" && !root.externallyManaged) root.state = "stopped"
  }

  function restart() {
    if (managedProcess.running) {
      stop()
      restartTimer.restart()
    } else {
      start()
    }
  }

  Process {
    id: binaryCheckProc
    stdout: StdioCollector { id: binaryCheckOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 || String(binaryCheckOut.text || "").trim().length === 0) {
        root.state = "error"
        root.errorMessage = "lan-mouse not found"
        return
      }
      managedProcess.command = root.daemonCommand
      managedProcess.running = true
    }
  }

  Process {
    id: managedProcess
    onStarted: {
      root.state = "running"
      root.errorMessage = ""
      Qt.callLater(root.refreshList)
    }
    onExited: function(exitCode, exitStatus) {
      if (root._stopping) {
        root._stopping = false
        root.state = "stopped"
      } else if (root.state === "running" || root.state === "starting") {
        if (exitCode !== 0) {
          root.state = "error"
          root.errorMessage = "lan-mouse daemon exited unexpectedly"
        } else {
          root.state = "stopped"
        }
      }
      root.clients = []
    }
  }

  Timer {
    id: restartTimer
    interval: 400
    repeat: false
    onTriggered: root.start()
  }

  // --- cli command queue ---
  // `lan-mouse cli` is a one-shot client of the daemon's own IPC socket;
  // running two overlapping invocations is unnecessary and untested, so
  // queue them and run one at a time.
  property var _queue: []
  property bool _busy: false

  function runCli(args, callback) {
    root._queue.push({ args: args, callback: callback || null })
    root._dequeue()
  }

  function _dequeue() {
    if (root._busy || root._queue.length === 0) return
    root._busy = true
    var item = root._queue.shift()
    cliProcess._callback = item.callback
    cliProcess.command = ["lan-mouse", "cli"].concat(item.args)
    cliProcess.running = true
  }

  Process {
    id: cliProcess
    property var _callback: null
    stdout: StdioCollector { id: cliOut; waitForEnd: true }
    stderr: StdioCollector { id: cliErr; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      var cb = cliProcess._callback
      var out = String(cliOut.text || "")
      var err = String(cliErr.text || "")
      cliProcess._callback = null
      root._busy = false
      if (cb) cb(exitCode, out, err)
      Qt.callLater(root._dequeue)
    }
  }

  // --- client list: also doubles as daemon-reachability detection, since
  // lan-mouse has no pidfile/socket path this shell could otherwise poll.
  // Verified: with no daemon running, `lan-mouse cli list` exits 1 with
  // stderr "could not connect: `connection timed out` - is the service
  // running?"; with a daemon up (whether started by this shell or not) it
  // exits 0 and prints one line per configured client.
  function refreshList() {
    runCli(["list"], function(exitCode, out, err) {
      if (exitCode === 0) {
        root.clients = root.parseListOutput(out)
        if (!managedProcess.running) {
          root.externallyManaged = true
          root.state = "running"
        }
      } else {
        root.clients = []
        if (!managedProcess.running) {
          root.externallyManaged = false
          if (root.state !== "starting" && root.state !== "error") root.state = "stopped"
        }
      }
    })
  }

  // Parses lines shaped like (verified against 0.11.0):
  //   id 0: 100.127.32.118:4242 (right) active: true, ips: {100.127.32.118}
  // This is lan-mouse's plain-text `cli list` output, not a stable
  // machine-readable format — tolerate lines that don't match instead of
  // throwing, and re-check this regex if a future lan-mouse version
  // changes the wording (see README "Known limitations").
  function parseListOutput(text) {
    var result = []
    var lines = String(text || "").split("\n")
    var re = /^id\s+(\d+):\s+([^:\s]+):(\d+)\s+\(([a-z]+)\)\s+active:\s+(true|false),\s+ips:\s+\{([^}]*)\}\s*$/
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var m = re.exec(line)
      if (!m) continue
      var ipsRaw = m[6].trim()
      result.push({
        id: parseInt(m[1], 10),
        hostname: m[2],
        port: parseInt(m[3], 10),
        position: m[4],
        active: m[5] === "true",
        ips: ipsRaw.length > 0 ? ipsRaw.split(",").map(function(s) { return s.trim() }) : []
      })
    }
    return result
  }

  // --- client management: real `lan-mouse cli` calls, no invented flags ---

  function addClient(hostname, port) {
    if (!hostname || !hostname.trim()) return
    var args = ["add-client", "--hostname", hostname.trim()]
    if (port) args.push("--port", String(port))
    runCli(args, function(exitCode, out, err) {
      if (exitCode === 0) root.saveAndRefresh()
      else root._reportCliError("Add client failed", err)
    })
  }

  function removeClient(id) {
    runCli(["remove-client", String(id)], function(exitCode, out, err) {
      if (exitCode === 0) root.saveAndRefresh()
      else root._reportCliError("Remove client failed", err)
    })
  }

  function activateClient(id) {
    runCli(["activate", String(id)], function(exitCode, out, err) {
      if (exitCode === 0) root.saveAndRefresh()
      else root._reportCliError("Activate failed", err)
    })
  }

  function deactivateClient(id) {
    runCli(["deactivate", String(id)], function(exitCode, out, err) {
      if (exitCode === 0) root.saveAndRefresh()
      else root._reportCliError("Deactivate failed", err)
    })
  }

  // Verified accepted values: left, right, top, bottom.
  function setPosition(id, position) {
    runCli(["set-position", String(id), position], function(exitCode, out, err) {
      if (exitCode === 0) root.saveAndRefresh()
      else root._reportCliError("Set position failed", err)
    })
  }

  function saveAndRefresh() {
    runCli(["save-config"], function(exitCode, out, err) {
      root.refreshList()
    })
  }

  function _reportCliError(prefix, stderrText) {
    console.warn("erick.lan-mouse: " + prefix + ": " + stderrText)
  }

  Timer {
    id: pollTimer
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshList()
  }

  function statusJson() {
    return JSON.stringify({
      state: root.state,
      errorMessage: root.errorMessage,
      externallyManaged: root.externallyManaged,
      clients: root.clients
    })
  }

  IpcHandler {
    target: "lan-mouse"

    function start(): string {
      root.start()
      return "ok"
    }

    function stop(): string {
      root.stop()
      return "ok"
    }

    function restart(): string {
      root.restart()
      return "ok"
    }

    function status(): string {
      return root.statusJson()
    }

    function addClient(hostname: string, port: string): string {
      root.addClient(hostname, port ? parseInt(port, 10) : 0)
      return "ok"
    }

    function removeClient(id: string): string {
      root.removeClient(parseInt(id, 10))
      return "ok"
    }

    function activateClient(id: string): string {
      root.activateClient(parseInt(id, 10))
      return "ok"
    }

    function deactivateClient(id: string): string {
      root.deactivateClient(parseInt(id, 10))
      return "ok"
    }

    function setPosition(id: string, position: string): string {
      root.setPosition(parseInt(id, 10), position)
      return "ok"
    }

    function ping(): string {
      return "ok"
    }
  }
}
