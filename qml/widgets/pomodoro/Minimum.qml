import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                if (root.connected) {
                    PomotroidBackend.openMainWindow();
                } else {
                    PomotroidBackend.launchPomotroid();
                }
            } else {
                if (root.connected) {
                    PomotroidBackend.toggleTimer();
                } else {
                    PomotroidBackend.launchPomotroid();
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6
        width: Math.min(parent.width - 4, contentWidth)
        readonly property real contentWidth: iconItem.width + textRow.implicitWidth + 8

        Item {
            id: iconItem
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: iconText
                anchors.centerIn: parent
                text: root.isWork ? "󰄉" : "󱫠"
                font.family: root.iconFontFamily
                font.pixelSize: 13
                color: root.themeColor
            }

            // Pulsing ring when active
            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: root.themeColor
                opacity: root.isRunning ? 0.7 : 0.0

                SequentialAnimation on scale {
                    running: root.isRunning
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.35; duration: 900; easing.type: Easing.OutQuad }
                    NumberAnimation { from: 1.35; to: 1.0; duration: 900; easing.type: Easing.InQuad }
                }
                SequentialAnimation on opacity {
                    running: root.isRunning
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.7; to: 0.15; duration: 900 }
                    NumberAnimation { from: 0.15; to: 0.7; duration: 900 }
                }
            }
        }

        Row {
            id: textRow
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.connected ? root.timeDisplay : "Pomotroid"
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.connected ? "white" : "#a1a1aa"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Secondary badge (subject or round fraction)
            Rectangle {
                visible: root.connected
                height: 14
                width: badgeText.implicitWidth + 8
                radius: 7
                color: "#27272a"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.subject ? root.subject : (root.roundNumber + "/" + root.roundsTotal)
                    font.family: root.textFontFamily
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: "#d4d4d8"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
