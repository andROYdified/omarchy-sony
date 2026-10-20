// plugin/Panel.qml
// Omarchy Bar-Widget & Interactive Dropdown Control Panel for Sony WH-1000XM5.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.androydified.omasony"
  ipcTarget: "io.github.androydified.omasony"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Keyboard navigation state
  property string focusSection: "noise"
  property int noiseIndex: 0
  property int eqIndex: 0
  property bool cursorActive: false

  readonly property var noiseModes: [Model.NOISE_ANC, Model.NOISE_AMBIENT, Model.NOISE_OFF]

  // shell.json: { "id": "io.github.androydified.omasony", "hideWhenDisconnected": true }
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true

  visible: sony.connected || !hideWhenDisconnected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onVisibleChanged: if (!visible) root.close()

  Service {
    id: sony
    settings: root.settings
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = true
      focusSection = "noise"
      var idx = noiseModes.indexOf(sony.noiseMode)
      noiseIndex = idx !== -1 ? idx : 0
      var eqIdx = Model.EQ_PRESETS.indexOf(sony.eqPreset)
      eqIndex = eqIdx !== -1 ? eqIdx : 0
      if (panelFlick) panelFlick.contentY = 0
      sony.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    var sections = ["noise", "ambient", "eq", "speakToChat", "dsee", "multipoint"]

    if (dy !== 0) {
      if (focusSection === "noise") {
        if (dy > 0) {
          focusSection = (sony.noiseMode === Model.NOISE_AMBIENT) ? "ambient" : "eq"
        }
      } else if (focusSection === "ambient") {
        if (dy > 0) focusSection = "eq"
        else if (dy < 0) focusSection = "noise"
      } else if (focusSection === "eq") {
        if (dy > 0) {
          if (eqIndex < 5) eqIndex = Math.min(9, eqIndex + 5)
          else focusSection = "speakToChat"
        } else if (dy < 0) {
          if (eqIndex >= 5) eqIndex = eqIndex - 5
          else focusSection = (sony.noiseMode === Model.NOISE_AMBIENT) ? "ambient" : "noise"
        }
      } else if (focusSection === "speakToChat") {
        if (dy > 0) focusSection = "dsee"
        else if (dy < 0) {
          focusSection = "eq"
          eqIndex = 5
        }
      } else if (focusSection === "dsee") {
        if (dy > 0) focusSection = "multipoint"
        else if (dy < 0) focusSection = "speakToChat"
      } else if (focusSection === "multipoint") {
        if (dy < 0) focusSection = "dsee"
      }
      return
    }

    if (dx !== 0) {
      if (focusSection === "noise") {
        noiseIndex = Math.max(0, Math.min(noiseModes.length - 1, noiseIndex + dx))
      } else if (focusSection === "ambient") {
        var newLvl = Model.clamp(sony.ambientSoundLevel + dx, 0, 20, 0)
        sony.setAmbientLevel(newLvl)
      } else if (focusSection === "eq") {
        eqIndex = Math.max(0, Math.min(Model.EQ_PRESETS.length - 1, eqIndex + dx))
      }
    }
  }

  function activateCursor() {
    if (focusSection === "noise") {
      sony.setNoiseMode(noiseModes[noiseIndex])
    } else if (focusSection === "ambient") {
      // Level is adjusted via left/right
    } else if (focusSection === "eq") {
      sony.setEqPreset(Model.EQ_PRESETS[eqIndex])
    } else if (focusSection === "speakToChat") {
      sony.setSpeakToChat(!sony.speakToChat)
    } else if (focusSection === "dsee") {
      sony.setDsee(!sony.dseeExtreme)
    } else if (focusSection === "multipoint") {
      sony.setMultipoint(!sony.multipoint)
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { sony.refresh(); return "ok" }
    function cycleNoise(): string { sony.cycleNoiseMode(); return sony.noiseMode }
  }

  // Bar Widget Button
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : (contentRow.implicitWidth + scaledHorizontalMargin * 2)
    tooltipText: sony.connected
      ? ((sony.deviceName || "WH-1000XM5") + " (" + Model.noiseModeName(sony.noiseMode) + ", " + Model.formatBattery(sony.batteryLevel) + ")")
      : "Sony Headphones (Disconnected)"

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      SonyIcon {
        id: barIcon
        anchors.verticalCenter: parent.verticalCenter
        iconSize: Style.space(14)
        connected: sony.connected
        batteryLevel: sony.batteryLevel
        charging: sony.batteryCharging
        color: sony.connected
          ? (button.active ? button.activeColor : button.foreground)
          : Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.4)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: sony.connected ? Model.formatBattery(sony.batteryLevel) : "—"
        color: button.active ? button.activeColor : button.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
        visible: !button.vertical
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        sony.cycleNoiseMode()
      } else {
        root.toggle()
      }
    }
  }

  // Dropdown Control Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight + Style.space(24), Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: function() { root.activateCursor() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          policy: panelColumn.implicitHeight > panelFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Column {
          id: panelColumn
          width: parent.width
          spacing: Style.space(12)

          // -------------------------------------------------------------------
          // 1. Device Header
          // -------------------------------------------------------------------
          Row {
            width: parent.width
            spacing: Style.space(12)

            SonyIcon {
              anchors.verticalCenter: parent.verticalCenter
              iconSize: Style.space(28)
              connected: sony.connected
              batteryLevel: sony.batteryLevel
              charging: sony.batteryCharging
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(110)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: sony.connected ? (sony.deviceName || "WH-1000XM5") : "WH-1000XM5"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Row {
                spacing: Style.space(6)
                anchors.left: parent.left

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(7)
                  height: Style.space(7)
                  radius: width / 2
                  color: sony.connected ? "#2ecc71" : Qt.darker(root.foreground, 1.8)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: sony.connected
                    ? (sony.codec ? "Connected • " + sony.codec : "Connected")
                    : "Disconnected"
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Battery status block
            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              spacing: Style.space(2)
              visible: sony.connected

              Row {
                anchors.right: parent.right
                spacing: Style.space(4)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.batteryIcon(sony.batteryLevel, sony.batteryCharging)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Model.formatBattery(sony.batteryLevel)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
              }

              Text {
                anchors.right: parent.right
                textFormat: Text.PlainText
                visible: sony.batteryCharging
                text: "Charging"
                color: "#2ecc71"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // -------------------------------------------------------------------
          // 2. Noise Control Mode Selector
          // -------------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "NOISE CONTROL"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              id: noiseModeRow
              width: parent.width
              spacing: Style.space(6)

              readonly property real cellWidth: (width - spacing * (noiseModes.length - 1)) / noiseModes.length

              Repeater {
                model: [
                  { mode: Model.NOISE_ANC, label: "ANC", icon: Model.noiseModeIcon(Model.NOISE_ANC) },
                  { mode: Model.NOISE_AMBIENT, label: "Ambient", icon: Model.noiseModeIcon(Model.NOISE_AMBIENT) },
                  { mode: Model.NOISE_OFF, label: "Off", icon: Model.noiseModeIcon(Model.NOISE_OFF) }
                ]

                Button {
                  required property var modelData
                  required property int index
                  width: noiseModeRow.cellWidth
                  iconText: modelData.icon
                  iconSize: Style.font.title
                  text: modelData.label
                  fontSize: Style.font.bodySmall
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  bordered: true
                  selected: sony.noiseMode === modelData.mode
                  hasCursor: root.cursorActive && root.focusSection === "noise" && root.noiseIndex === index
                  onClicked: {
                    root.focusSection = "noise"
                    root.noiseIndex = index
                    sony.setNoiseMode(modelData.mode)
                  }
                }
              }
            }
          }

          // -------------------------------------------------------------------
          // 3. Ambient Sound Level Slider
          // -------------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(6)
            opacity: sony.noiseMode === Model.NOISE_AMBIENT ? 1.0 : 0.4

            Row {
              width: parent.width

              PanelSectionHeader {
                text: "AMBIENT SOUND LEVEL"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Item {
                width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth)
                height: 1
              }

              Text {
                textFormat: Text.PlainText
                text: String(sony.ambientSoundLevel) + " / 20"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            PanelSlider {
              id: ambientSlider
              width: parent.width
              minimum: 0
              maximum: 20
              step: 1
              integer: true
              value: sony.ambientSoundLevel
              enabled: sony.noiseMode === Model.NOISE_AMBIENT
              bar: root.bar
              onMoved: function(v) {
                root.focusSection = "ambient"
                sony.setAmbientLevel(Math.round(v))
              }
              onReleased: function(v) {
                sony.setAmbientLevel(Math.round(v))
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // -------------------------------------------------------------------
          // 4. Equalizer Presets Selector
          // -------------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "EQUALIZER PRESET (" + Model.eqPresetName(sony.eqPreset) + ")"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: eqGrid
              width: parent.width
              columns: 5
              spacing: Style.space(6)

              readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

              Repeater {
                model: Model.EQ_PRESETS

                Button {
                  required property var modelData
                  required property int index
                  width: eqGrid.cellWidth
                  text: Model.eqPresetButtonLabel(modelData)
                  fontSize: Style.font.caption
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  bordered: true
                  selected: sony.eqPreset === modelData
                  hasCursor: root.cursorActive && root.focusSection === "eq" && root.eqIndex === index
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(6)
                  onClicked: {
                    root.focusSection = "eq"
                    root.eqIndex = index
                    sony.setEqPreset(modelData)
                  }
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // -------------------------------------------------------------------
          // 5. Feature Toggles
          // -------------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "FEATURES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              id: toggleSpeakToChat
              width: parent.width
              label: "Speak-to-Chat"
              description: "Pauses music automatically when speaking"
              checked: sony.speakToChat
              hasCursor: root.cursorActive && root.focusSection === "speakToChat"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                root.focusSection = "speakToChat"
                sony.setSpeakToChat(!sony.speakToChat)
              }
            }

            Toggle {
              id: toggleDsee
              width: parent.width
              label: "DSEE Extreme"
              description: "AI audio upscaling for compressed tracks"
              checked: sony.dseeExtreme
              hasCursor: root.cursorActive && root.focusSection === "dsee"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                root.focusSection = "dsee"
                sony.setDsee(!sony.dseeExtreme)
              }
            }

            Toggle {
              id: toggleMultipoint
              width: parent.width
              label: "Multipoint Connection"
              description: "Connect to two devices simultaneously"
              checked: sony.multipoint
              hasCursor: root.cursorActive && root.focusSection === "multipoint"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                root.focusSection = "multipoint"
                sony.setMultipoint(!sony.multipoint)
              }
            }
          }
        }
      }
    }
  }
}
