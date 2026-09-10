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
    readonly property int batteryCapacity: widgetContext ? widgetContext.batteryCapacity : 80
    readonly property bool isCharging: widgetContext ? widgetContext.isCharging : false

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    WidgetProgressRing {
        anchors.fill: parent
        strokeWidth: Math.max(1.6, Math.min(2.4, 1.8 + (root.diameter - 44) * 0.015))
        rings: [
            {
                value: root.batteryCapacity >= 0 ? root.batteryCapacity / 100.0 : 0.8,
                fillColor: StyleTokens.success,
                trackColor: StyleTokens.isDark ? "#14281a" : Qt.rgba(0.2, 0.78, 0.35, 0.2)
            },
            {
                value: root.cpuUsage / 100.0,
                fillColor: StyleTokens.danger,
                trackColor: StyleTokens.isDark ? "#2b1016" : Qt.rgba(1.0, 0.18, 0.33, 0.2)
            },
            {
                value: root.ramUsage / 100.0,
                fillColor: StyleTokens.accent,
                trackColor: StyleTokens.isDark ? "#0e1e36" : Qt.rgba(0.0, 0.48, 1.0, 0.2)
            }
        ]
    }

    // Center: Battery % or charging bolt
    Item {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.44)
        height: width

        WidgetIconGlyph {
            anchors.centerIn: parent
            visible: root.isCharging
            glyph: "󰂄"
            size: 13
            color: StyleTokens.success
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.centerIn: parent
            visible: !root.isCharging
            text: root.batteryCapacity >= 0 ? root.batteryCapacity + "%" : "--"
            role: "caption"
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}
