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
    readonly property int roundNumber: PomotroidBackend.roundNumber
    readonly property int roundsTotal: PomotroidBackend.roundsTotal
    readonly property string subject: PomotroidBackend.subject

    readonly property bool isWork: roundType === "work"
    readonly property bool isLongBreak: roundType === "long-break"
    readonly property color themeColor: !connected ? StyleTokens.textDisabled : (isWork ? StyleTokens.danger : (isLongBreak ? StyleTokens.accent : StyleTokens.success))

    readonly property string timeDisplay: PomotroidBackend.formatTime(root.remainingSeconds)

    anchors.fill: parent

    Row {
        id: textRow
        anchors.centerIn: parent
        spacing: 6

        WidgetTextView {
            text: root.connected ? root.timeDisplay : "Pomotroid"
            role: "title"
            colorOverride: root.connected ? StyleTokens.textPrimaryBright : StyleTokens.textSecondary
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }

        // Secondary badge (subject or round fraction)
        Rectangle {
            visible: root.connected
            height: 18
            width: badgeText.measuredWidth + 12
            radius: 9
            color: StyleTokens.track
            anchors.verticalCenter: parent.verticalCenter

            WidgetTextView {
                id: badgeText
                anchors.centerIn: parent
                text: root.subject ? root.subject : (root.roundNumber + "/" + root.roundsTotal)
                role: "caption"
                overflowMode: "elide"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }
        }
    }
}
