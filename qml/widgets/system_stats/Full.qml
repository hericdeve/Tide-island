import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

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

                WidgetIconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "󰻠"
                    size: 14
                    color: StyleTokens.danger
                    widgetContext: root.widgetContext
                    width: 18
                }

                WidgetProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    barHeight: 8
                    fillColor: StyleTokens.danger
                    trackColor: StyleTokens.track
                    value: root.cpuUsage / 100.0
                }

                WidgetTextView {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.cpuUsage) + "%"
                    role: "metric"
                    colorOverride: StyleTokens.textPrimary
                    width: 36
                    widgetContext: root.widgetContext
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

                WidgetIconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "󰍛"
                    size: 14
                    color: StyleTokens.accent
                    widgetContext: root.widgetContext
                    width: 18
                }

                WidgetProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    barHeight: 8
                    fillColor: StyleTokens.accent
                    trackColor: StyleTokens.track
                    value: root.ramUsage / 100.0
                }

                WidgetTextView {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.ramUsage) + "%"
                    role: "metric"
                    colorOverride: StyleTokens.textPrimary
                    width: 36
                    widgetContext: root.widgetContext
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

                WidgetIconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: root.isCharging ? "󰂄" : "󰁹"
                    size: 14
                    color: StyleTokens.success
                    widgetContext: root.widgetContext
                    width: 18
                }

                WidgetProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 46
                    barHeight: 8
                    fillColor: StyleTokens.success
                    trackColor: StyleTokens.track
                    value: Math.max(0, Math.min(1, root.batteryPct / 100.0))
                }

                WidgetTextView {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.batteryPct >= 0 ? root.batteryPct : 100) + "%"
                    role: "metric"
                    colorOverride: StyleTokens.textPrimary
                    width: 36
                    widgetContext: root.widgetContext
                }
            }
        }
    }
}
