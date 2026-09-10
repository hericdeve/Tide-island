import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property bool connected: PomotroidBackend.connected
    readonly property bool isRunning: PomotroidBackend.running
    readonly property bool isPaused: PomotroidBackend.paused
    readonly property string roundType: PomotroidBackend.roundType
    readonly property int remainingSeconds: PomotroidBackend.remainingSeconds
    readonly property double progress: PomotroidBackend.progress
    readonly property int roundNumber: PomotroidBackend.roundNumber
    readonly property int roundsTotal: PomotroidBackend.roundsTotal

    readonly property bool isWork: roundType === "work"
    readonly property bool isLongBreak: roundType === "long-break"
    readonly property color themeColor: !connected ? StyleTokens.textDisabled : (isWork ? StyleTokens.danger : (isLongBreak ? StyleTokens.accent : StyleTokens.success))

    readonly property string timeDisplay: {
        if (!connected) return "--:--";
        return PomotroidBackend.formatTime(root.remainingSeconds);
    }

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    WidgetProgressRing {
        anchors.fill: parent
        strokeWidth: Math.max(2.5, Math.min(4, 3.0 + (root.diameter - 44) * 0.04))
        value: root.connected ? (1.0 - root.progress) : 0
        fillColor: root.themeColor
        trackColor: StyleTokens.track
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.max(0, Math.round((root.diameter - 44) * 0.05))

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeDisplay
            role: "title"
            colorOverride: StyleTokens.textPrimaryBright
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.connected ? (root.roundNumber + "/" + root.roundsTotal) : "Offline"
            role: "caption"
            colorOverride: root.connected ? StyleTokens.textSecondary : StyleTokens.textDisabled
            widgetContext: root.widgetContext
        }
    }
}
