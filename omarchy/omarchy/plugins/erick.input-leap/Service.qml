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
  property bool autoStart: false

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

  property bool _configLoaded: false
  property bool _hydrating: false

  function buildCommand() {
    if (mode === "server") {
      var serverCmd = ["input-leaps", "--no-daemon"]
      if (serverAddress) {
        serverCmd.push("--address")
        serverCmd.push(serverAddress)
      }
      return serverCmd
    }

    var clientCmd = ["input-leapc", "--no-daemon"]
    clientCmd.push(serverHost)
    return clientCmd
  }

  function start() {
    if (managedProcess.running) return
    if (mode === "client" && !serverHost) {
      root.state = "error"
      root.errorMessage = "Server address is required in client mode"
      return
    }

    root.state = "starting"
    root.errorMessage = ""
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
      autoStart: root.autoStart
    }, null, 2) + "\n")
  }

  onModeChanged: scheduleSave()
  onServerHostChanged: scheduleSave()
  onServerAddressChanged: scheduleSave()
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
