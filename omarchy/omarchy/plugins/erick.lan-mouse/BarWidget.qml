import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "erick.lan-mouse"

  readonly property var lanMouseService: bar?.shell?.firstPartyServiceFor("erick.lan-mouse")
  readonly property string state: lanMouseService ? lanMouseService.state : "stopped"
  readonly property string errorMessage: lanMouseService ? lanMouseService.errorMessage : ""
  readonly property bool externallyManaged: lanMouseService ? lanMouseService.externallyManaged : false
  readonly property var clients: lanMouseService ? lanMouseService.clients : []
  readonly property int activeClientCount: {
    var n = 0
    for (var i = 0; i < clients.length; i++) if (clients[i].active) n++
    return n
  }

  // Reuses the same mouse glyph from the retired erick.input-leap widget —
  // still the best available Nerd Font match, no repo convention to defer to.
  readonly property string glyph: "󰍽"
  readonly property string statusDot: state === "running" ? "●" : (state === "error" ? "󰀦" : "○")
  readonly property color statusColor: state === "running" ? Color.accent
    : state === "error" ? Color.lock.textError
    : Qt.darker(root.bar.barForeground, 1.6)

  property bool popupOpen: false
  function close() { popupOpen = false }

  visible: true
  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: Qt.darker(root.bar.barForeground, 1.3)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.statusDot
      color: root.statusColor
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.popupOpen = !root.popupOpen
    onEntered: if (root.bar) root.bar.showTooltip(root, "Lan Mouse: " + root.state + " (" + root.activeClientCount + " active)")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // PopupCard never gets real keyboard focus unless summoned by a key
  // press, so a TextField inside it can't be typed into — KeyboardPanel is
  // this repo's layer-shell alternative that primes real Wayland keyboard
  // focus on open. Always use it here, never PopupCard, since this popup
  // has a TextField.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: hostnameField
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        text: "Lan Mouse"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Row {
        spacing: Style.space(6)

        Text {
          text: root.statusDot
          color: root.statusColor
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          text: {
            if (root.state === "running") return root.externallyManaged ? "Running (external)" : "Running"
            if (root.state === "starting") return "Starting…"
            if (root.state === "error") return "Error" + (root.errorMessage ? ": " + root.errorMessage : "")
            return "Stopped"
          }
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.clients.length > 0

        Text {
          text: "Paired machines"
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          model: root.clients

          Column {
            id: clientRow
            required property var modelData
            width: parent.width
            spacing: Style.space(2)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clientRow.modelData.active ? "●" : "○"
                color: clientRow.modelData.active ? Color.accent : Qt.darker(root.bar.foreground, 1.6)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(210)
                text: clientRow.modelData.hostname + ":" + clientRow.modelData.port + " (" + clientRow.modelData.position + ")"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Button {
                text: clientRow.modelData.active ? "Deactivate" : "Activate"
                foreground: root.bar.foreground
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.lanMouseService) return
                  if (clientRow.modelData.active) root.lanMouseService.deactivateClient(clientRow.modelData.id)
                  else root.lanMouseService.activateClient(clientRow.modelData.id)
                }
              }

              Button {
                text: "Remove"
                foreground: root.bar.foreground
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: if (root.lanMouseService) root.lanMouseService.removeClient(clientRow.modelData.id)
              }
            }
          }
        }
      }

      Text {
        text: "No paired machines yet"
        visible: root.clients.length === 0
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: root.bar.foreground }

      Text {
        text: "Add machine"
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Row {
        spacing: Style.space(6)
        width: parent.width

        TextField {
          id: hostnameField
          width: parent.width * 0.6
          placeholderText: "hostname or IP"
          onTextEdited: root._pendingHostname = text
        }

        TextField {
          id: portField
          width: parent.width * 0.4 - Style.space(6)
          placeholderText: "port (24800)"
          onTextEdited: root._pendingPort = text
        }
      }

      property string _pendingHostname: ""
      property string _pendingPort: ""

      Button {
        text: "Add"
        anchors.right: parent.right
        foreground: root.bar.foreground
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        enabled: root.lanMouseService && column._pendingHostname.trim().length > 0
        opacity: enabled ? 1.0 : 0.4
        onClicked: {
          if (!root.lanMouseService) return
          var port = column._pendingPort.trim().length > 0 ? parseInt(column._pendingPort.trim(), 10) : 0
          root.lanMouseService.addClient(column._pendingHostname.trim(), port)
          hostnameField.text = ""
          portField.text = ""
          column._pendingHostname = ""
          column._pendingPort = ""
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          text: "Start"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.lanMouseService && (root.state === "stopped" || root.state === "error")
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.lanMouseService) root.lanMouseService.start()
        }

        Button {
          text: "Stop"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.lanMouseService && root.state === "running" && !root.externallyManaged
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.lanMouseService) root.lanMouseService.stop()
        }

        Button {
          text: "Restart"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.lanMouseService && root.state === "running" && !root.externallyManaged
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.lanMouseService) root.lanMouseService.restart()
        }
      }

      Text {
        text: "Managed by an external process — Stop/Restart unavailable"
        visible: root.externallyManaged
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }
}
