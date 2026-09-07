import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    property string currentTime: widgetContext ? widgetContext.currentTime : "00:00"
    property string currentDateLabel: widgetContext ? widgetContext.currentDateLabel : ""

    Timer {
        interval: 1000
        running: !widgetContext || !widgetContext.currentTime
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.currentTime = Qt.formatTime(now, "hh:mm");
            root.currentDateLabel = Qt.formatDate(now, "ddd, d");
        }
    }

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    Rectangle {
        anchors.centerIn: parent
        width: root.diameter - 2
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: "#2c2c2e"
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentTime
            color: "white"
            font.family: root.textFontFamily
            font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (root.diameter - 44) * 0.08)))
            font.weight: Font.Bold
            font.letterSpacing: -0.2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentDateLabel !== "" ? root.currentDateLabel : Qt.formatDate(new Date(), "ddd, d")
            color: "#8e8e93"
            font.family: root.textFontFamily
            font.pixelSize: Math.max(7, Math.min(10, Math.round(7.5 + (root.diameter - 44) * 0.05)))
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
