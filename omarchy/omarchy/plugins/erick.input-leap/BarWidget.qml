import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "erick.input-leap"

  readonly property var inputLeapService: bar?.shell?.firstPartyServiceFor("erick.input-leap")
  readonly property string state: inputLeapService ? inputLeapService.state : "stopped"
  readonly property string errorMessage: inputLeapService ? inputLeapService.errorMessage : ""
  readonly property string mode: inputLeapService ? inputLeapService.mode : "client"

  // No existing hardware-sharing icon convention exists elsewhere in this
  // repo's bar widgets to copy — picked a Nerd Font mouse glyph (Material
  // Design Icons "mouse") as the best available match.
  readonly property string glyph: "󰍽"
  readonly property string statusDot: state === "connected" || state === "running" ? "●" : (state === "error" ? "󰀦" : "○")
  readonly property color statusColor: state === "connected" ? Color.accent
    : state === "error" ? Color.lock.textError
    : state === "running" ? Qt.darker(root.bar.barForeground, 1.1)
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
    onEntered: if (root.bar) root.bar.showTooltip(root, "Input Leap: " + root.state)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // PopupCard (xdg-popup) never receives keyboard focus unless it was
  // summoned by a key press, so the TextFields below couldn't be typed
  // into. KeyboardPanel is this repo's purpose-built layer-shell
  // alternative for exactly this case — same anchorItem/bar/owner/open/
  // contentWidth/contentHeight API, but primes real Wayland keyboard
  // focus on open (see Ui/KeyboardPanel.qml for why).
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: root.mode === "server" ? remoteScreenField : serverHostField
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        text: "Input Leap"
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
            if (root.state === "connected") return "Connected"
            if (root.state === "running") return "Running"
            if (root.state === "starting") return "Starting…"
            if (root.state === "disconnected") return "Disconnected"
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

        Row {
          spacing: Style.space(6)
          width: parent.width

          Text {
            text: "Mode"
            width: Style.space(90)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Button {
            text: "Client"
            selected: root.mode === "client"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: if (root.inputLeapService) root.inputLeapService.mode = "client"
          }

          Button {
            text: "Server"
            selected: root.mode === "server"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: if (root.inputLeapService) root.inputLeapService.mode = "server"
          }
        }

        Row {
          spacing: Style.space(6)
          width: parent.width
          visible: root.mode === "client"

          Text {
            text: "Server host"
            width: Style.space(90)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          TextField {
            id: serverHostField
            width: parent.width - Style.space(96)
            text: root.inputLeapService ? root.inputLeapService.serverHost : ""
            placeholderText: "e.g. 192.168.1.10"
            onTextEdited: if (root.inputLeapService) root.inputLeapService.serverHost = text
          }
        }

        Row {
          spacing: Style.space(6)
          width: parent.width
          visible: root.mode === "server"

          Text {
            text: "Bind address"
            width: Style.space(90)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          TextField {
            width: parent.width - Style.space(96)
            text: root.inputLeapService ? root.inputLeapService.serverAddress : ""
            placeholderText: "optional, e.g. :24800"
            onTextEdited: if (root.inputLeapService) root.inputLeapService.serverAddress = text
          }
        }

        Row {
          spacing: Style.space(6)
          width: parent.width
          visible: root.mode === "server"

          Text {
            text: "Remote screen"
            width: Style.space(90)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          TextField {
            id: remoteScreenField
            width: parent.width - Style.space(96)
            text: root.inputLeapService ? root.inputLeapService.remoteScreenName : ""
            placeholderText: "hostname of the other laptop"
            onTextEdited: if (root.inputLeapService) root.inputLeapService.remoteScreenName = text
          }
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
          enabled: root.inputLeapService && (root.state === "stopped" || root.state === "error")
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.inputLeapService) root.inputLeapService.start()
        }

        Button {
          text: "Stop"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.inputLeapService && root.state !== "stopped"
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.inputLeapService) root.inputLeapService.stop()
        }

        Button {
          text: "Restart"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.inputLeapService && root.state !== "stopped"
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.inputLeapService) root.inputLeapService.restart()
        }
      }
    }
  }
}
