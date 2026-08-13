import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  property string ipText: "…"
  property bool tooltipHovered: false

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
    onEntered: {
      tooltipHovered = true
      if (bar) bar.showTooltip(root, "IP Local: " + ipText)
    }
    onExited: {
      tooltipHovered = false
      if (bar) bar.hideTooltip(root)
    }
    onClicked: if (bar) bar.run("bash -c 'echo -n \"" + ipText + "\" | wl-copy && notify-send \"IP Local copiada\"'")
  }
}
