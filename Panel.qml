import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "nflscores"
  property var anchorItem: null
  property var hostWidget: null
  property var report: ({events: [], fetchedAt: ""})
  readonly property var idleService: root.bar && root.bar.shell
    ? root.bar.shell.firstPartyServiceFor("omarchy.idle")
    : null
  readonly property var games: report.events || []
  readonly property string tooltipText: games.length
    ? games.length + " live NFL game" + (games.length === 1 ? "" : "s")
    : "No live NFL games"
  readonly property string backendScript: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")) + "bin/omarchy-nflscores"
  readonly property var barIdentity: hostWidget || root

  function open() {
    controller.show()
    refresh()
  }

  function openFromHotkey() {
    open()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (!scoreProc.running) scoreProc.running = true
  }

  Process {
    id: scoreProc
    command: [root.backendScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          root.report = JSON.parse(raw)
        } catch (e) {
          // Keep the last successful response visible during a bad response.
        }
      }
    }
  }

  Timer {
    interval: 30 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: root.idleService
    function onScreensaverWindowCountChanged() {
      if (root.idleService && root.idleService.screensaverWindowCount > 0 && root.opened)
        root.close()
    }
  }

  component TeamRow: Row {
    required property var team
    readonly property bool hasBall: !!(team && team.possession)
    width: parent.width
    spacing: Style.space(8)

    Row {
      id: identity
      spacing: Style.space(8)
      width: parent.width - teamScore.implicitWidth - spacing

      Image {
        width: Style.space(24)
        height: width
        source: team ? (team.logoUrl || "") : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        opacity: team && team.logoUrl ? 1 : 0
      }

      Text {
        id: teamName
        text: team ? (team.abbrev || team.name) : ""
        color: team && team.possession ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
        font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
        font.pixelSize: Style.font.body
        font.bold: team && team.possession
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width - football.width - spacing)
      }

      Image {
        id: football
        visible: parent.parent.hasBall
        width: visible ? Style.space(16) : 0
        height: Style.space(16)
        source: Qt.resolvedUrl("football.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }

    Item { width: Math.max(0, parent.width - teamScore.implicitWidth - identity.width - parent.spacing) }

    Text {
      id: teamScore
      text: team ? (team.score || "0") : "0"
      color: root.bar ? root.bar.foreground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(680))
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight, Style.space(560)), Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scoreScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
        id: content
        width: scoreScroll.width
        clip: true
        spacing: Style.space(12)
        padding: Style.space(16)

        RowLayout {
          width: parent.width - parent.leftPadding - parent.rightPadding
          spacing: Style.space(8)

          Text {
            text: "NFL LIVE"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            text: root.report.fetchedAt ? "Updated " + root.report.fetchedAt : "Refreshing..."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          visible: root.report.error === "offline"
          text: "Unable to reach ESPN — showing the last available scores."
          color: Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Grid {
          id: scoreGrid
          visible: root.games.length > 0
          width: parent.width - parent.leftPadding - parent.rightPadding
          columns: 2
          spacing: Style.space(10)
          height: Math.ceil(root.games.length / 2) * Style.space(84)
            + Math.max(0, Math.ceil(root.games.length / 2) - 1) * Style.space(10)
          clip: true

          Repeater {
            model: root.games

            Rectangle {
              required property var modelData
              width: (parent.width - Style.space(10)) / 2
              height: Style.space(84)
              clip: true
              radius: Style.cornerRadius
              color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                             (root.bar ? root.bar.foreground : Color.foreground).g,
                             (root.bar ? root.bar.foreground : Color.foreground).b, 0.08)
              border.width: 1
              border.color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                                    (root.bar ? root.bar.foreground : Color.foreground).g,
                                    (root.bar ? root.bar.foreground : Color.foreground).b, 0.16)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(9)
                spacing: Style.space(3)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: modelData.detail || "LIVE"
                    color: Color.accent
                    font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1
                  }
                  Text {
                    text: modelData.broadcast || ""
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width - x
                  }
                }

                TeamRow { team: modelData.away }
                TeamRow { team: modelData.home }
              }
            }
          }
        }

        Text {
          visible: root.games.length === 0
          width: parent.width - parent.leftPadding - parent.rightPadding
          text: root.report.error === "offline"
            ? "Scores are temporarily unavailable."
            : "No live NFL games right now."
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(22)
          bottomPadding: Style.space(22)
        }
      }
      }
    }
  }
}
