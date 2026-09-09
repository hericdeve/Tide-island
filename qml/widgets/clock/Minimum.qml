import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string heroFontFamily: widgetContext ? widgetContext.heroFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    property string currentTime: widgetContext ? widgetContext.currentTime : "00:00"

    Timer {
        interval: 1000
        running: !widgetContext || !widgetContext.currentTime
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.currentTime = Qt.formatTime(new Date(), "hh:mm");
        }
    }

    anchors.fill: parent

    Text {
        anchors.centerIn: parent
        text: root.currentTime
        font.family: root.heroFontFamily
        font.pixelSize: Math.max(20, Math.min(24, Math.round(root.height * 0.65))) * root.titleFontSize / 20.0
        font.weight: Font.Bold
        font.letterSpacing: -0.35
        color: "white"
    }
}
