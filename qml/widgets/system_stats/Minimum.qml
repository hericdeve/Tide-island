import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    readonly property real cpuUsage: widgetContext ? widgetContext.currentCpuUsage : 15
    readonly property real ramUsage: widgetContext ? widgetContext.currentRamUsage : 45
    readonly property int batteryPct: widgetContext ? widgetContext.batteryCapacity : 80
    readonly property bool isCharging: widgetContext ? widgetContext.isCharging : false

    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        spacing: 8

        // CPU
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "󰻠"
                font.family: root.iconFontFamily
                font.pixelSize: 11
                color: "#ff2d55"
            }
            Text {
                text: Math.round(root.cpuUsage) + "%"
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "white"
            }
        }

        // RAM
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "󰍛"
                font.family: root.iconFontFamily
                font.pixelSize: 11
                color: "#007aff"
            }
            Text {
                text: Math.round(root.ramUsage) + "%"
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "white"
            }
        }

        // Battery
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: root.isCharging ? "󰂄" : "󰁹"
                font.family: root.iconFontFamily
                font.pixelSize: 11
                color: "#30d158"
            }
            Text {
                text: (root.batteryPct >= 0 ? root.batteryPct : 100) + "%"
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "white"
            }
        }
    }
}
