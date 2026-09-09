import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

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
    readonly property color themeColor: !connected ? "#71717a" : (isWork ? "#ff453a" : (isLongBreak ? "#0a84ff" : "#30d158"))

    readonly property string timeDisplay: PomotroidBackend.formatTime(root.remainingSeconds)

    anchors.fill: parent

    Row {
        id: textRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.connected ? root.timeDisplay : "Pomotroid"
            font.family: root.textFontFamily
            font.pixelSize: Math.round(14 * root.titleFontSize / 20.0)
            font.weight: Font.Bold
            font.letterSpacing: -0.2
            color: root.connected ? "white" : "#a1a1aa"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Secondary badge (subject or round fraction)
        Rectangle {
            visible: root.connected
            height: 18
            width: badgeText.implicitWidth + 10
            radius: 9
            color: "#27272a"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.subject ? root.subject : (root.roundNumber + "/" + root.roundsTotal)
                font.family: root.textFontFamily
                font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                font.weight: Font.DemiBold
                color: "#d4d4d8"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
