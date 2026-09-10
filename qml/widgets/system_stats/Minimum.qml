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

    Row {
        anchors.centerIn: parent
        spacing: 8

        // CPU
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            WidgetIconGlyph {
                glyph: "󰻠"
                size: 13
                color: StyleTokens.danger
                widgetContext: root.widgetContext
            }
            WidgetTextView {
                text: Math.round(root.cpuUsage) + "%"
                role: "metric"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }
        }

        // RAM
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            WidgetIconGlyph {
                glyph: "󰍛"
                size: 13
                color: StyleTokens.accent
                widgetContext: root.widgetContext
            }
            WidgetTextView {
                text: Math.round(root.ramUsage) + "%"
                role: "metric"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }
        }

        // Battery
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            WidgetIconGlyph {
                glyph: root.isCharging ? "󰂄" : "󰁹"
                size: 13
                color: StyleTokens.success
                widgetContext: root.widgetContext
            }
            WidgetTextView {
                text: (root.batteryPct >= 0 ? root.batteryPct : 100) + "%"
                role: "metric"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }
        }
    }
}
