import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string heroFontFamily: widgetContext ? widgetContext.heroFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

    property string currentTime: "00:00"
    property string currentSeconds: "00"
    property string currentDate: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.currentTime = Qt.formatTime(now, "hh:mm");
            root.currentSeconds = Qt.formatTime(now, "ss");
            root.currentDate = Qt.formatDate(now, "dddd, MMMM d");
        }
    }

    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Text {
                text: root.currentTime
                font.family: root.heroFontFamily
                font.pixelSize: Math.round(32 * root.titleFontSize / 20.0)
                font.weight: Font.Bold
                font.letterSpacing: -0.5
                color: "white"
            }

            Text {
                text: root.currentSeconds
                font.family: root.heroFontFamily
                font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
                font.weight: Font.DemiBold
                color: "#8e8e93"
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentDate
            font.family: root.textFontFamily
            font.pixelSize: Math.round(12 * root.bodyFontSize / 16.0)
            font.weight: Font.Medium
            color: "#8e8e93"
        }
    }
}
