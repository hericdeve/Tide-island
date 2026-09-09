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

    Column {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 6

        // CPU Bar
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.fill: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰻠"
                    font.family: root.iconFontFamily
                    font.pixelSize: 14
                    color: "#ff2d55"
                    width: 18
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    height: 10
                    radius: 5
                    color: "#2c2c2e"

                    Rectangle {
                        height: parent.height
                        radius: 5
                        color: "#ff2d55"
                        width: parent.width * Math.max(0, Math.min(1, root.cpuUsage / 100.0))
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.cpuUsage) + "%"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "white"
                    width: 36
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // RAM Bar
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.fill: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍛"
                    font.family: root.iconFontFamily
                    font.pixelSize: 14
                    color: "#007aff"
                    width: 18
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    height: 10
                    radius: 5
                    color: "#2c2c2e"

                    Rectangle {
                        height: parent.height
                        radius: 5
                        color: "#007aff"
                        width: parent.width * Math.max(0, Math.min(1, root.ramUsage / 100.0))
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.ramUsage) + "%"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "white"
                    width: 36
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Battery Bar
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.fill: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isCharging ? "󰂄" : "󰁹"
                    font.family: root.iconFontFamily
                    font.pixelSize: 14
                    color: "#30d158"
                    width: 18
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    height: 10
                    radius: 5
                    color: "#2c2c2e"

                    Rectangle {
                        height: parent.height
                        radius: 5
                        color: "#30d158"
                        width: parent.width * Math.max(0, Math.min(1, root.batteryPct / 100.0))
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.batteryPct >= 0 ? root.batteryPct : 100) + "%"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "white"
                    width: 36
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
