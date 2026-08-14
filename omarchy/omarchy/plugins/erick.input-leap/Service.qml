import QtQuick
import Quickshell
import Quickshell.Io

// Manages an Input Leap client (input-leapc) or server (input-leaps) process.
// There's no systemd unit, pidfile, or socket for this on the system this was
// written against — lifecycle tracking is done two ways:
//   1. A real Quickshell Process when this shell starts it (running/exited).
//   2. A periodic `pgrep -x` poll to notice a copy started outside the shell
//      (e.g. from a terminal), since there is no other IPC surface to hook.
// Connection state (connected/disconnected) is inferred by pattern-matching
// input-leapc/input-leaps stdout/stderr — see README.md for the caveats.
Item {
  id: root

  property var shell: null

  // --- config (persisted to ~/.config/quickshell/input-leap.conf) ---
  property string mode: "client" // "client" | "server"
  property string serverHost: "" // client mode: address to connect to
  property string serverAddress: "" // server mode: optional bind address
  property string remoteScreenName: "" // server mode: hostname of the other screen
  property bool autoStart: false

  // server mode only: this machine's screen name, auto-detected via `hostname`
  // and used both as the --name flag and as one of the two screens in the
  // generated topology config.
  property string localScreenName: ""

  // --- state machine ---
  // "stopped" | "starting" | "running" | "connected" | "disconnected" | "error"
  property string state: "stopped"
  property string errorMessage: ""
  property bool externallyDetected: false

  readonly property bool processRunning: managedProcess.running || externallyDetected
  readonly property string binaryName: mode === "server" ? "input-leaps" : "input-leapc"

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/quickshell"
  readonly property string configPath: configDir + "/input-leap.conf"
  readonly property string serverTopologyPath: configDir + "/input-leap-server.conf"

  property bool _configLoaded: false
  property bool _hydrating: false

  // --disable-crypto avoids Input Leap's own TLS handshake, which requires
  // a client/server certificate at ~/.config/InputLeap/SSL/InputLeap.pem
  // that nothing here generates — verified this is the actual failure mode
  // ("ssl certificate doesn't exist") when connecting without it. Both
  // ends must agree: the other machine's Input Leap also needs SSL/TLS
  // disabled in its own settings, or the connection is opened and
  // immediately closed with no further error. This assumes the transport
  // itself is already encrypted (e.g. Tailscale) since Input Leap's own
  // encryption is turned off.
  //
  // --use-x11 forces the legacy Xwayland-backed input path. Verified this
  // Hyprland session's xdg-desktop-portal has no
  // org.freedesktop.portal.RemoteDesktop implementation — Input Leap's
  // default (portal-based) backend fails immediately with "No such
  // interface" without it. Xwayland input injection is a known-limited
  // fallback (Input Leap itself warns "will not work as expected"); switch
  // to --use-ei once this session's portal setup supports the EI backend.
  function buildCommand() {
    if (mode === "server") {
      var serverCmd = ["input-leaps", "--no-daemon", "--disable-crypto", "--use-x11", "--config", root.serverTopologyPath]
      if (root.localScreenName) {
        serverCmd.push("--name")
        serverCmd.push(root.localScreenName)
      }
      if (serverAddress) {
        serverCmd.push("--address")
        serverCmd.push(serverAddress)
      }
      return serverCmd
    }

    var clientCmd = ["input-leapc", "--no-daemon", "--disable-crypto", "--use-x11"]
    if (root.localScreenName) {
      clientCmd.push("--name")
      clientCmd.push(root.localScreenName)
    }
    clientCmd.push(serverHost)
    return clientCmd
  }

  // input-leaps refuses to start without a config file declaring at least
  // two screens and a link between them (verified: it exits with "no
  // configuration available" otherwise). Generate a minimal two-screen
  // layout — local screen left, remote screen right — from the local
  // hostname and the user-provided remote screen name.
  function buildServerTopology(local, remote) {
    return "section: screens\n" +
      "\t" + local + ":\n" +
      "\t" + remote + ":\n" +
      "end\n\n" +
      "section: links\n" +
      "\t" + local + ":\n" +
      "\t\tright = " + remote + "\n" +
      "\t" + remote + ":\n" +
      "\t\tleft = " + local + "\n" +
      "end\n"
  }

  function start() {
    if (managedProcess.running) return
    if (mode === "client" && !serverHost) {
      root.state = "error"
      root.errorMessage = "Server address is required in client mode"
      return
    }
    if (mode === "server" && !remoteScreenName.trim()) {
      root.state = "error"
      root.errorMessage = "Remote screen name is required in server mode"
      return
    }

    root.state = "starting"
    root.errorMessage = ""

    // Both modes need the local hostname for --name (client) / the
    // topology config + --name (server), so resolve it first either way.
    hostnameProc.running = true
  }

  function proceedToBinaryCheck() {
    binaryCheckProc.command = ["bash", "-c", "command -v " + root.binaryName]
    binaryCheckProc.running = true
  }

  function stop() {
    if (managedProcess.running) managedProcess.running = false
    if (root.state !== "error") root.state = "stopped"
  }

  function restart() {
    if (managedProcess.running) {
      stop()
      restartTimer.restart()
    } else {
      start()
    }
  }

  function checkExternalProcess() {
    if (managedProcess.running) return
    if (externalCheckProc.running) return
    externalCheckProc.command = ["pgrep", "-x", root.binaryName]
    externalCheckProc.running = true
  }

  function classifyLine(line) {
    var lower = String(line || "").toLowerCase()
    if (lower.indexOf("connected to server") !== -1 || lower.indexOf("connected to client") !== -1) {
      root.state = "connected"
    } else if (lower.indexOf("connection refused") !== -1 || lower.indexOf("failed to connect") !== -1) {
      root.state = "error"
      root.errorMessage = "Unable to connect"
    } else if (lower.indexOf("disconnected") !== -1) {
      if (root.state !== "error") root.state = "disconnected"
    }
  }

  function loadConfig(raw) {
    if (root._configLoaded) return
    root._hydrating = true

    var text = String(raw || "").trim()
    if (text.length > 0) {
      try {
        var parsed = JSON.parse(text)
        if (parsed.mode === "client" || parsed.mode === "server") root.mode = parsed.mode
        if (typeof parsed.serverHost === "string") root.serverHost = parsed.serverHost
        if (typeof parsed.serverAddress === "string") root.serverAddress = parsed.serverAddress
        if (typeof parsed.remoteScreenName === "string") root.remoteScreenName = parsed.remoteScreenName
        if (typeof parsed.autoStart === "boolean") root.autoStart = parsed.autoStart
      } catch (e) {
        console.warn("erick.input-leap: failed to parse config:", e)
      }
    }

    root._hydrating = false
    root._configLoaded = true

    if (root.autoStart) root.start()
  }

  function scheduleSave() {
    if (root._hydrating || !root._configLoaded) return
    saveTimer.restart()
  }

  function saveConfig() {
    configFile.setText(JSON.stringify({
      mode: root.mode,
      serverHost: root.serverHost,
      serverAddress: root.serverAddress,
      remoteScreenName: root.remoteScreenName,
      autoStart: root.autoStart
    }, null, 2) + "\n")
  }

  onModeChanged: scheduleSave()
  onServerHostChanged: scheduleSave()
  onServerAddressChanged: scheduleSave()
  onRemoteScreenNameChanged: scheduleSave()
  onAutoStartChanged: scheduleSave()

  Component.onCompleted: {
    ensureDirsProc.running = true
    Qt.callLater(function() { configFile.reload() })
    externalCheckTimer.triggeredOnStart = true
  }

  Process {
    id: ensureDirsProc
    command: ["mkdir", "-p", root.configDir]
    running: false
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: false
    printErrors: false
    onLoaded: root.loadConfig(text())
    onLoadFailed: root.loadConfig("")
  }

  Timer {
    id: saveTimer
    interval: 200
    repeat: false
    onTriggered: root.saveConfig()
  }

  // Resolve the local hostname for --name (both modes), and in server mode
  // write the two-screen topology config before continuing to the binary
  // check — in that order, so the config file exists on disk before
  // input-leaps is spawned.
  Process {
    id: hostnameProc
    command: ["hostname"]
    stdout: StdioCollector { id: hostnameOut; waitForEnd: true }
    onExited: function() {
      var local = String(hostnameOut.text || "").trim().split(/\s+/)[0]
      root.localScreenName = local || "local"
      if (root.mode === "server") {
        serverTopologyFile.setText(root.buildServerTopology(root.localScreenName, root.remoteScreenName.trim()))
      }
      Qt.callLater(root.proceedToBinaryCheck)
    }
  }

  FileView {
    id: serverTopologyFile
    path: root.serverTopologyPath
    watchChanges: false
    printErrors: false
  }

  // Checks the binary is installed before spawning the real process, so a
  // missing package fails fast with a clear message instead of a silent
  // Process start failure.
  Process {
    id: binaryCheckProc
    stdout: StdioCollector { id: binaryCheckOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 || String(binaryCheckOut.text || "").trim().length === 0) {
        root.state = "error"
        root.errorMessage = "Input Leap not found"
        return
      }

      managedProcess.command = root.buildCommand()
      managedProcess.running = true
    }
  }

  Process {
    id: managedProcess

    stdout: SplitParser {
      onRead: function(line) { root.classifyLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { root.classifyLine(line) }
    }

    onStarted: {
      root.state = "running"
      root.errorMessage = ""
    }

    onExited: function(exitCode, exitStatus) {
      if (root.state === "connected" || root.state === "running" || root.state === "starting") {
        if (exitCode !== 0) {
          root.state = "error"
          root.errorMessage = "Input Leap exited unexpectedly"
        } else {
          root.state = "stopped"
        }
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 400
    repeat: false
    onTriggered: root.start()
  }

  // External-process detection: this shell has no way to attach to a process
  // it didn't spawn, so all it can report is "something matching the binary
  // name is alive" via polling pgrep.
  Process {
    id: externalCheckProc
    stdout: StdioCollector { id: externalCheckOut; waitForEnd: true }
    onExited: function(exitCode) {
      root.externallyDetected = exitCode === 0 && String(externalCheckOut.text || "").trim().length > 0
      if (root.externallyDetected && root.state === "stopped") root.state = "running"
    }
  }

  Timer {
    id: externalCheckTimer
    interval: 5000
    repeat: true
    running: true
    onTriggered: root.checkExternalProcess()
  }

  function statusJson() {
    return JSON.stringify({
      mode: root.mode,
      state: root.state,
      processRunning: root.processRunning,
      errorMessage: root.errorMessage,
      serverHost: root.serverHost,
      serverAddress: root.serverAddress,
      remoteScreenName: root.remoteScreenName,
      autoStart: root.autoStart
    })
  }

  IpcHandler {
    target: "input-leap"

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

    function ping(): string {
      return "ok"
    }
  }
}
