import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "erick.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("erick.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  // MPRIS position doesn't update reactively (avoids waking players every
  // frame), so poll it on a timer instead of binding directly.
  property real livePosition: 0
  property real liveLength: 0
  readonly property bool hasPosition: activePlayer && activePlayer.positionSupported && activePlayer.lengthSupported && liveLength > 0
  readonly property string positionText: hasPosition ? (formatTime(livePosition) + " / " + formatTime(liveLength)) : ""

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(seconds))
    var m = Math.floor(total / 60)
    var s = total % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  // Best-effort app icon from MPRIS identity/desktopEntry — falls back to a
  // generic note glyph for anything not explicitly recognized.
  function sourceIcon(player) {
    if (!player) return "󰝚"
    var id = (String(player.identity || "") + " " + String(player.desktopEntry || "")).toLowerCase()
    if (id.indexOf("spotify") !== -1) return ""
    if (id.indexOf("firefox") !== -1) return ""
    if (id.indexOf("chrom") !== -1) return ""
    if (id.indexOf("youtube") !== -1) return ""
    return "󰝚"
  }

  readonly property string sourceGlyph: sourceIcon(activePlayer)
  readonly property string sourceName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""

  property bool popupOpen: false

  function close() { popupOpen = false }
  property real maxLabelWidth: 180

  Timer {
    interval: 1000
    running: root.hasMedia
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!root.activePlayer) return
      root.livePosition = root.activePlayer.positionSupported ? root.activePlayer.position : 0
      root.liveLength = root.activePlayer.lengthSupported ? root.activePlayer.length : 0
    }
  }

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: sourceGlyphText
      anchors.verticalCenter: parent.verticalCenter
      text: root.sourceGlyph
      color: Qt.darker(root.bar.barForeground, 1.3)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: labelText.implicitHeight
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        x: 0
        text: root.title + (root.artist ? "  ·  " + root.artist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignLeft
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        // A track shorter than the previous one can land here mid-scroll:
        // reset to the left edge instead of leaving a stale negative x that
        // scrolls the whole label out of the clip.
        onNeedsScrollChanged: if (!needsScroll) x = 0
        onTextChanged: if (!needsScroll) x = 0

        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && !root.popupOpen && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.positionText !== "" && !root.bar.vertical
      text: root.positionText
      color: Qt.darker(root.bar.barForeground, 1.3)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else {
        // Left or right click: open the info/controls popup instead of
        // toggling playback — clicking the track name shouldn't stop it.
        root.popupOpen = !root.popupOpen
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "") + (root.sourceName ? " (" + root.sourceName + ")" : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Row {
            spacing: Style.space(4)
            visible: root.sourceName !== ""

            Text {
              text: root.sourceGlyph
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: root.sourceName
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.positionText !== ""
        text: root.positionText
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
