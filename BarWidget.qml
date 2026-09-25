import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "nflscores"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool live: panelLoader.item ? panelLoader.item.showingLiveGames : false
  readonly property string tooltip: panelLoader.item ? panelLoader.item.tooltipText : "NFL scores"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
    else if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
    else
      close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: footballIcon
    slotSize: Style.bar.statusSlot
    tooltipText: root.tooltip

    Rectangle {
      visible: root.live
      width: Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.space(5)
      anchors.rightMargin: Style.space(5)
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else
        root.togglePanel()
    }
  }

  Component {
    id: footballIcon

    Item {
      width: Style.space(20)
      height: Style.space(20)
      anchors.centerIn: parent

      Canvas {
        id: footballCanvas
        anchors.fill: parent
        onPaint: {
          var context = getContext("2d")
          var sx = width / 24
          var sy = height / 24
          context.clearRect(0, 0, width, height)
          context.save()
          context.scale(sx, sy)
          context.translate(12, 12)
          context.rotate(-0.55)
          context.beginPath()
          context.moveTo(-11, 0)
          context.quadraticCurveTo(-7.5, -7, 0, -7)
          context.quadraticCurveTo(7.5, -7, 11, 0)
          context.quadraticCurveTo(7.5, 7, 0, 7)
          context.quadraticCurveTo(-7.5, 7, -11, 0)
          context.closePath()
          context.strokeStyle = root.bar ? root.bar.foreground : Color.foreground
          context.lineWidth = 1.6
          context.lineCap = "round"
          context.lineJoin = "round"
          context.stroke()
          context.beginPath()
          context.moveTo(-2.4, -4)
          context.lineTo(-2.4, 4)
          context.moveTo(0, -4.5)
          context.lineTo(0, 4.5)
          context.moveTo(2.4, -4)
          context.lineTo(2.4, 4)
          context.strokeStyle = root.bar ? root.bar.foreground : Color.foreground
          context.lineWidth = 1.4
          context.stroke()
          context.restore()
        }
      }

      Connections {
        target: root.bar
        function onForegroundChanged() { footballCanvas.requestPaint() }
      }

    }
  }
}
