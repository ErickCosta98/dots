import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  property string ipText: "…"
  property bool tooltipHovered: false
  property bool copyOnFinish: false

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "󰩟"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 14
  }

  Process {
    id: proc
    command: ["bash", "-lc", "~/.config/omarchy/bar/scripts/local-ip.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = text.trim()
        var t = raw
        try {
          var data = JSON.parse(raw)
          t = data.text || raw
        } catch (e) {}
        ipText = t
        if (copyOnFinish) {
          copyOnFinish = false
          if (bar) bar.run("bash -c 'echo -n \"" + ipText + "\" | wl-copy && notify-send \"IP Local copiada\"'")
        }
      }
    }
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!proc.running) proc.running = true
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: {
      tooltipHovered = true
      if (bar) bar.showTooltip(root, "IP Local: " + ipText)
    }
    onExited: {
      tooltipHovered = false
      if (bar) bar.hideTooltip(root)
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (bar) bar.run("bash -c 'echo -n \"" + ipText + "\" | wl-copy && notify-send \"IP Local copiada\"'")
      } else {
        copyOnFinish = true
        if (!proc.running) proc.running = true
      }
    }
  }
}
