import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 320
  readonly property int fieldHeight: 65
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // --- Dashboard state (ported from the hyprlock design) ---
  property var now: new Date()
  readonly property string greetingText: {
    var h = now.getHours()
    var greet = (h >= 6 && h < 12) ? "Buenos días" : (h >= 12 && h < 19) ? "Buenas tardes" : "Buenas noches"
    return greet + ", " + userName
  }
  readonly property string userName: Quickshell.env("USER") || ""
  readonly property string clockText: Qt.formatDateTime(now, "HH:mm")

  property string hostnameText: ""
  property string weekdayText: ""
  property string dateText: ""
  property string uptimeText: ""
  property string weatherTemp: ""
  property string weatherDesc: ""
  property string batteryIcon: ""
  property string batteryPercent: ""
  property string batteryStatus: ""
  // Reads MPRIS directly (same backend the bar's Media widget uses) instead
  // of shelling out to playerctl, which isn't even installed on this system.
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activeMediaPlayer: {
    var playing = null
    var withMetadata = null
    for (var i = 0; i < mprisPlayers.length; i++) {
      var p = mprisPlayers[i]
      if (!p || !p.trackTitle) continue
      if (p.isPlaying && !playing) playing = p
      if (!withMetadata) withMetadata = p
    }
    return playing || withMetadata
  }
  readonly property string mediaTitle: activeMediaPlayer ? (activeMediaPlayer.trackTitle || "Sin música") : "Sin música"
  readonly property string mediaArtist: activeMediaPlayer ? (activeMediaPlayer.trackArtist || "") : ""
  readonly property string mediaAlbum: activeMediaPlayer ? (activeMediaPlayer.trackAlbum || "") : ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  // Matches the rest of the shell (e.g. FileView reads on /etc/hostname
  // elsewhere) rather than spawning a process for a value that never
  // changes at runtime.
  FileView {
    path: "/etc/hostname"
    onLoaded: root.hostnameText = String(text() || "").trim()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { uptimeProc.running = true; dateProc.running = true }
  }

  Process {
    id: dateProc
    command: ["bash", "-c", "date +'%a|%d %B, %Y'"]
    stdout: StdioCollector { id: dateOut; waitForEnd: true }
    onExited: {
      var parts = String(dateOut.text || "").trim().split("|")
      if (parts.length === 2) {
        root.weekdayText = parts[0].toUpperCase()
        root.dateText = parts[1]
      }
    }
  }

  Process {
    id: uptimeProc
    command: ["bash", "-c", "uptime -p | sed -e 's/up /  UPTIME /' -e 's/ hours, /H/' -e 's/ minutes/M/' -e 's/ hour, /H/' -e 's/ minute/M/'"]
    stdout: StdioCollector { id: uptimeOut; waitForEnd: true }
    onExited: root.uptimeText = String(uptimeOut.text || "").trim()
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: weatherProc.running = true
  }

  // Reuses Omarchy's own weather tooling (configured location + icon
  // mapping) instead of a hardcoded city/coords, so it stays in sync with
  // whatever `omarchy weather location` is set to.
  Process {
    id: weatherProc
    command: ["bash", "-c", "icon=$(omarchy-weather-icon 2>/dev/null); place=$(omarchy-weather-location 2>/dev/null); query=$(jq -rn --arg place \"$place\" '$place | @uri'); data=$(curl -fsS --max-time 4 \"https://wttr.in/${query}?format=%t|%C\" 2>/dev/null | tr -d '\\n'); IFS='|' read -r temp desc <<< \"$data\"; echo \"${icon}|${temp#+}|${desc}\""]
    stdout: StdioCollector { id: weatherOut; waitForEnd: true }
    onExited: {
      var parts = String(weatherOut.text || "").trim().split("|")
      if (parts.length >= 2) {
        root.weatherTemp = (parts[0] ? parts[0] + " " : "") + parts[1]
        root.weatherDesc = parts[2] || ""
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: batteryProc.running = true
  }

  // Reuses Omarchy's own battery status helper (upower-backed, handles
  // charge-threshold "holding" state) instead of hand-parsing sysfs.
  Process {
    id: batteryProc
    command: ["bash", "-c", "omarchy-battery-status --shell 2>/dev/null"]
    stdout: StdioCollector { id: batteryOut; waitForEnd: true }
    onExited: {
      var percent = ""
      var state = ""
      String(batteryOut.text || "").split("\n").forEach(function(line) {
        var tab = line.indexOf("\t")
        if (tab < 0) return
        var key = line.slice(0, tab)
        var value = line.slice(tab + 1)
        if (key === "percentage") percent = value.replace("%", "")
        else if (key === "state") state = value
      })
      if (percent === "") return

      var cap = parseInt(percent, 10)
      var charging = state === "charging" || state === "holding" || state === "fully-charged"
      root.batteryIcon = charging ? "󰂄"
        : cap >= 90 ? "󰁹" : cap >= 80 ? "󰂂" : cap >= 60 ? "󰂀" : cap >= 40 ? "󰁽" : cap >= 20 ? "󰁻" : "󰁺"
      root.batteryPercent = percent
      root.batteryStatus = state === "charging" ? "Cargando"
        : state === "holding" ? "Carga contenida"
        : state === "fully-charged" ? "Carga completa"
        : state === "discharging" ? "Usando batería"
        : state
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // --- LEFT COLUMN: greeting/login card + clock card ---
    Column {
      anchors.right: parent.horizontalCenter
      anchors.rightMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 20

      Rectangle {
        width: 360
        height: 380
        radius: 25
        color: Qt.rgba(0, 0, 0, 0.3)

        Column {
          anchors.centerIn: parent
          spacing: 18

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰟀  " + root.hostnameText
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: 13
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.greetingText
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: 20
          }

          BorderSurface {
            id: inputField
            width: root.fieldWidth
            height: root.fieldHeight
            anchors.horizontalCenter: parent.horizontalCenter
            color: Color.lock.background
            borderSpec: root.inputBorderSpec
            radius: Style.cornerRadius
            clip: true

            TextInput {
              id: passwordInput
              anchors.fill: parent
              anchors.topMargin: inputField.borderTop
              // Reserve the fingerprint icon's width on both sides so the centered
              // dots stay symmetric and never slide under the icon as they grow.
              anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
              anchors.bottomMargin: inputField.borderBottom
              anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignHCenter
              activeFocusOnPress: true
              clip: true
              enabled: root.inputEnabled && !root.authenticatingPassword
              readOnly: root.authenticatingPassword
              echoMode: TextInput.Password
              passwordCharacter: "●"
              passwordMaskDelay: 0
              color: Color.lock.text
              selectionColor: Color.lock.selection
              selectedTextColor: Color.lock.text
              font.family: Style.font.family
              font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
              font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
              cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
              cursorDelegate: Rectangle {
                width: 2
                color: Color.lock.text
                visible: passwordInput.cursorVisible
              }

              onTextChanged: {
                if (!root.syncingPasswordText) root.passwordTextEdited(text)
                if (text.length > 0) {
                  root.wakeRequested()
                }
                if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
              }

              onAccepted: {
                var submitted = root.passwordText
                root.passwordTextEdited("")
                if (submitted.length > 0) root.submitPassword(submitted)
              }

              Keys.onPressed: function(event) {
                root.wakeRequested()
                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                  root.passwordTextEdited("")
                  event.accepted = true
                }
              }
            }

            Text {
              anchors.fill: passwordInput
              text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
              visible: passwordInput.text.length === 0
              color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
              font.family: Style.font.family
              font.pixelSize: root.fieldFontSize
              font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            // Fingerprint hint pinned inside the field's right edge when a sensor is
            // enrolled, so the user knows they can touch to unlock instead of typing.
            Text {
              id: fingerprintIcon
              objectName: "fingerprintIndicator"
              anchors.right: parent.right
              anchors.rightMargin: inputField.borderRight + 18
              anchors.verticalCenter: parent.verticalCenter
              visible: root.fingerprintConfigured
              text: "󰈷"
              color: Color.lock.placeholder
              font.family: Style.font.family
              font.pixelSize: Math.round(root.fieldFontSize * 1.1)
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.failureMessage
            visible: root.failureMessage.length > 0
            color: Color.lock.textError
            font.family: Style.font.family
            font.pixelSize: 12
          }
        }
      }

      Rectangle {
        width: 360
        height: 160
        radius: 25
        color: Qt.rgba(0, 0, 0, 0.3)

        Column {
          anchors.centerIn: parent
          spacing: 8

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clockText
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: 72
            font.bold: true
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.uptimeText
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: 14
          }
        }
      }
    }

    // --- RIGHT COLUMN: weather/date card + battery/media card ---
    Column {
      anchors.left: parent.horizontalCenter
      anchors.leftMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 20

      Rectangle {
        width: 360
        height: 380
        radius: 25
        color: Qt.rgba(0, 0, 0, 0.3)

        Column {
          anchors.centerIn: parent
          spacing: 10

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weatherTemp
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: 52
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weatherDesc
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: 13
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weekdayText
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: 38
            font.bold: true
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateText
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: 14
          }
        }
      }

      Rectangle {
        width: 360
        height: 320
        radius: 25
        color: Color.lock.background

        Column {
          anchors.centerIn: parent
          spacing: 24
          width: parent.width - 40

          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            width: parent.width

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.mediaTitle
              color: Color.lock.text
              font.family: Style.font.family
              font.pixelSize: 15
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.mediaArtist
              visible: root.mediaArtist.length > 0
              color: Color.lock.placeholder
              font.family: Style.font.family
              font.pixelSize: 12
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.mediaAlbum.length > 0 ? "󰀥  " + root.mediaAlbum : ""
              visible: root.mediaAlbum.length > 0
              color: Color.lock.placeholder
              font.family: Style.font.family
              font.pixelSize: 11
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28
            visible: root.activeMediaPlayer !== null

            Text {
              readonly property bool canUse: root.activeMediaPlayer && root.activeMediaPlayer.canGoPrevious
              text: "󰒮"
              color: canUse ? Color.lock.text : Color.lock.placeholder
              opacity: canUse ? 1.0 : 0.4
              font.family: Style.font.family
              font.pixelSize: 22
              MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                enabled: parent.canUse
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.wakeRequested(); root.activeMediaPlayer.previous() }
              }
            }

            Text {
              readonly property bool playing: root.activeMediaPlayer && root.activeMediaPlayer.isPlaying
              readonly property bool canUse: root.activeMediaPlayer && root.activeMediaPlayer.canTogglePlaying
              text: playing ? "󰏤" : "󰐊"
              color: canUse ? Color.lock.text : Color.lock.placeholder
              opacity: canUse ? 1.0 : 0.4
              font.family: Style.font.family
              font.pixelSize: 26
              MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                enabled: parent.canUse
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.wakeRequested(); root.activeMediaPlayer.togglePlaying() }
              }
            }

            Text {
              readonly property bool canUse: root.activeMediaPlayer && root.activeMediaPlayer.canGoNext
              text: "󰒭"
              color: canUse ? Color.lock.text : Color.lock.placeholder
              opacity: canUse ? 1.0 : 0.4
              font.family: Style.font.family
              font.pixelSize: 22
              MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                enabled: parent.canUse
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.wakeRequested(); root.activeMediaPlayer.next() }
              }
            }
          }

          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.batteryIcon + "  " + root.batteryPercent + "%"
              color: Color.lock.text
              font.family: Style.font.family
              font.pixelSize: 38
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.batteryStatus
              color: Color.lock.text
              font.family: Style.font.family
              font.pixelSize: 13
            }
          }
        }
      }
    }
  }
}
