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
  property var favorites: []
  property bool favoritesLoaded: false
  property bool favoritesExpanded: true
  readonly property var teams: [
    {name: "Arizona Cardinals", abbrev: "ARI"},
    {name: "Atlanta Falcons", abbrev: "ATL"},
    {name: "Baltimore Ravens", abbrev: "BAL"},
    {name: "Buffalo Bills", abbrev: "BUF"},
    {name: "Carolina Panthers", abbrev: "CAR"},
    {name: "Chicago Bears", abbrev: "CHI"},
    {name: "Cincinnati Bengals", abbrev: "CIN"},
    {name: "Cleveland Browns", abbrev: "CLE"},
    {name: "Dallas Cowboys", abbrev: "DAL"},
    {name: "Denver Broncos", abbrev: "DEN"},
    {name: "Detroit Lions", abbrev: "DET"},
    {name: "Green Bay Packers", abbrev: "GB"},
    {name: "Houston Texans", abbrev: "HOU"},
    {name: "Indianapolis Colts", abbrev: "IND"},
    {name: "Jacksonville Jaguars", abbrev: "JAX"},
    {name: "Kansas City Chiefs", abbrev: "KC"},
    {name: "Las Vegas Raiders", abbrev: "LV"},
    {name: "Los Angeles Chargers", abbrev: "LAC"},
    {name: "Los Angeles Rams", abbrev: "LAR"},
    {name: "Miami Dolphins", abbrev: "MIA"},
    {name: "Minnesota Vikings", abbrev: "MIN"},
    {name: "New England Patriots", abbrev: "NE"},
    {name: "New Orleans Saints", abbrev: "NO"},
    {name: "New York Giants", abbrev: "NYG"},
    {name: "New York Jets", abbrev: "NYJ"},
    {name: "Philadelphia Eagles", abbrev: "PHI"},
    {name: "Pittsburgh Steelers", abbrev: "PIT"},
    {name: "San Francisco 49ers", abbrev: "SF"},
    {name: "Seattle Seahawks", abbrev: "SEA"},
    {name: "Tampa Bay Buccaneers", abbrev: "TB"},
    {name: "Tennessee Titans", abbrev: "TEN"},
    {name: "Washington Commanders", abbrev: "WSH"}
  ]
  readonly property var liveGames: (report.events || []).filter(function(game) {
    return game.state === "in"
  })
  readonly property var upcomingGames: (report.events || []).filter(function(game) {
    return game.state === "pre"
  })
  readonly property bool showingLiveGames: liveGames.length > 0
  readonly property var displayedGames: {
    var games = showingLiveGames ? liveGames.slice() : upcomingGames.slice()
    var favoriteOrder = favorites
    var rank = function(game) {
      var awayRank = favoriteOrder.indexOf(game.away.abbrev)
      var homeRank = favoriteOrder.indexOf(game.home.abbrev)
      if (awayRank < 0) return homeRank < 0 ? favoriteOrder.length : homeRank
      return homeRank < 0 ? awayRank : Math.min(awayRank, homeRank)
    }
    return games.sort(function(a, b) {
      var rankDifference = rank(a) - rank(b)
      if (rankDifference !== 0) return rankDifference
      return String(a.date || "").localeCompare(String(b.date || ""))
    })
  }
  readonly property var idleService: root.bar && root.bar.shell
    ? root.bar.shell.firstPartyServiceFor("omarchy.idle")
    : null
  readonly property string tooltipText: {
    if (showingLiveGames) return liveGames.length + " NFL game" + (liveGames.length === 1 ? "" : "s") + " live"
    if (upcomingGames.length) return "Upcoming NFL games"
    return "No upcoming NFL games"
  }
  readonly property string backendScript: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")) + "bin/omarchy-nflscores"
  readonly property var barIdentity: hostWidget || root

  function toggleFavorite(abbrev) {
    var next = favorites.slice()
    var index = next.indexOf(abbrev)
    if (index >= 0) next.splice(index, 1)
    else next.push(abbrev)
    favorites = next
    saveFavorites()
  }

  function clearFavorites() {
    favorites = []
    favoritesExpanded = true
    saveFavorites()
  }

  function loadFavorites(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      var stored = parsed.favorites instanceof Array ? parsed.favorites : []
      favorites = stored.filter(function(abbrev) {
        return teams.some(function(team) { return team.abbrev === abbrev })
      })
      favoritesExpanded = favorites.length === 0
    } catch (e) {
      favorites = []
      favoritesExpanded = true
      console.warn("nflscores: favorite teams settings could not be parsed")
    }
    favoritesLoaded = true
  }

  function saveFavorites() {
    if (!favoritesLoaded) return
    favoriteFile.setText(JSON.stringify({favorites: favorites}, null, 2) + "\n")
  }

  property FileView favoriteFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/nflscores.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadFavorites(text())
    onLoadFailed: {
      root.favorites = []
      root.favoritesLoaded = true
      root.favoritesExpanded = true
    }
    onFileChanged: reload()
  }

  Process {
    id: stateDirProc
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/omarchy/settings"]
    onExited: function(exitCode) {
      if (exitCode === 0) root.favoriteFile.reload()
      else console.warn("nflscores: unable to create favorites settings directory")
    }
  }

  Component.onCompleted: stateDirProc.running = true

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
    required property bool live
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
        textFormat: Text.PlainText
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
      textFormat: Text.PlainText
      id: teamScore
      text: live && team ? (team.score || "0") : ""
      visible: live
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
            textFormat: Text.PlainText
            text: root.showingLiveGames ? "LIVE GAMES" : "UPCOMING SLATE"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            textFormat: Text.PlainText
            text: root.report.fetchedAt ? "Updated " + root.report.fetchedAt : "Refreshing..."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.report.error === "offline"
          text: "Unable to reach ESPN — showing the last available scores."
          color: Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Column {
          width: parent.width - parent.leftPadding - parent.rightPadding
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(6)

            Rectangle {
              id: favoriteToggle
              width: favoriteToggleLabel.implicitWidth + Style.space(30)
              height: Style.space(30)
              radius: Style.cornerRadius
              color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                             (root.bar ? root.bar.foreground : Color.foreground).g,
                             (root.bar ? root.bar.foreground : Color.foreground).b, 0.08)
              border.width: 1
              border.color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                                    (root.bar ? root.bar.foreground : Color.foreground).g,
                                    (root.bar ? root.bar.foreground : Color.foreground).b, 0.16)

              Text {
                id: favoriteToggleLabel
                anchors.left: parent.left
                anchors.leftMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                text: root.favoritesExpanded
                  ? (root.favorites.length ? "DONE" : "CHOOSE TEAMS")
                  : "MANAGE FAVORITES"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: root.favoritesExpanded ? "⌃" : "⌄"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.2)
                font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                font.pixelSize: Style.font.body
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.favoritesExpanded = !root.favoritesExpanded
              }
            }

            Text {
              visible: !root.favoritesExpanded && root.favorites.length > 0
              width: visible ? Math.max(0, parent.width - favoriteToggle.width - parent.spacing) : 0
              height: Style.space(30)
              verticalAlignment: Text.AlignVCenter
              text: root.favorites.join(" · ")
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
              font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Rectangle {
              id: clearFavoritesButton
              visible: root.favoritesExpanded && root.favorites.length > 0
              width: visible ? clearFavoritesLabel.implicitWidth + Style.space(18) : 0
              height: Style.space(30)
              radius: Style.cornerRadius
              color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                             (root.bar ? root.bar.foreground : Color.foreground).g,
                             (root.bar ? root.bar.foreground : Color.foreground).b, 0.08)
              border.width: 1
              border.color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                                    (root.bar ? root.bar.foreground : Color.foreground).g,
                                    (root.bar ? root.bar.foreground : Color.foreground).b, 0.16)
              Text {
                id: clearFavoritesLabel
                anchors.centerIn: parent
                text: "CLEAR"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.clearFavorites()
              }
            }
          }

          Grid {
            id: favoriteGrid
            visible: root.favoritesExpanded
            width: parent.width
            columns: 8
            spacing: Style.space(4)
            height: visible
              ? Math.ceil(root.teams.length / columns) * Style.space(28)
                + Math.max(0, Math.ceil(root.teams.length / columns) - 1) * spacing
              : 0

            Repeater {
              model: root.teams

              Rectangle {
                required property var modelData
                width: (favoriteGrid.width - (favoriteGrid.columns - 1) * favoriteGrid.spacing)
                  / favoriteGrid.columns
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.favorites.indexOf(modelData.abbrev) >= 0
                  ? Color.accent
                  : Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                            (root.bar ? root.bar.foreground : Color.foreground).g,
                            (root.bar ? root.bar.foreground : Color.foreground).b, 0.08)
                border.width: 1
                border.color: Qt.rgba((root.bar ? root.bar.foreground : Color.foreground).r,
                                      (root.bar ? root.bar.foreground : Color.foreground).g,
                                      (root.bar ? root.bar.foreground : Color.foreground).b, 0.16)
                Text {
                  anchors.centerIn: parent
                  text: modelData.abbrev
                  color: root.favorites.indexOf(modelData.abbrev) >= 0
                    ? (root.bar ? root.bar.background : Color.background)
                    : (root.bar ? root.bar.foreground : Color.foreground)
                  font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: root.toggleFavorite(modelData.abbrev)
                }
              }
            }
          }
        }

        Grid {
          id: scoreGrid
          visible: root.displayedGames.length > 0
          width: parent.width - parent.leftPadding - parent.rightPadding
          columns: 2
          spacing: Style.space(10)
          height: Math.ceil(root.displayedGames.length / 2) * Style.space(84)
            + Math.max(0, Math.ceil(root.displayedGames.length / 2) - 1) * Style.space(10)
          clip: true

          Repeater {
            model: root.displayedGames

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
                    textFormat: Text.PlainText
                    text: modelData.state === "in" ? (modelData.detail || "LIVE") : (modelData.detail || "UPCOMING")
                    color: modelData.state === "in" ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                    font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: {
                      var broadcast = modelData.state === "in" ? (modelData.broadcast || "") : ""
                      var situation = modelData.situation || {}
                      var downDistance = situation.shortDownDistanceText || situation.downDistanceText || ""
                      var fieldPosition = situation.possessionText || ""
                      var gameSituation = ""
                      if (modelData.state === "in") {
                        if (downDistance && fieldPosition)
                          gameSituation = downDistance.replace(/\s+at\s+.+$/i, "") + " · " + fieldPosition
                        else
                          gameSituation = downDistance || fieldPosition
                      }
                      if (gameSituation && broadcast) return gameSituation + " · " + broadcast
                      return gameSituation || broadcast
                    }
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width - x
                  }
                }

                TeamRow { team: modelData.away; live: modelData.state === "in" }
                TeamRow { team: modelData.home; live: modelData.state === "in" }
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.displayedGames.length === 0
          width: parent.width - parent.leftPadding - parent.rightPadding
          text: root.report.error === "offline"
            ? "Scores are temporarily unavailable."
            : "No upcoming NFL games found."
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
