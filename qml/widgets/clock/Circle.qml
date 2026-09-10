import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string currentDateLabel: widgetContext ? widgetContext.currentDateLabel : ""
    property string fallbackDateLabel: ""

    Timer {
        interval: 1000
        running: !widgetContext || !widgetContext.currentDateLabel
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fallbackDateLabel = Qt.formatDate(new Date(), "ddd, d");
        }
    }

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    Rectangle {
        anchors.centerIn: parent
        width: root.diameter - 2
        height: width
        radius: width / 2
        color: StyleTokens.transparent
        border.width: 1
        border.color: StyleTokens.track
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        WidgetTimerClock {
            anchors.horizontalCenter: parent.horizontalCenter
            mode: "clock"
            clockFormat: "hh:mm"
            representation: "compact"
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            text: root.currentDateLabel !== "" ? root.currentDateLabel : root.fallbackDateLabel
            colorOverride: StyleTokens.textSecondary
            widgetContext: root.widgetContext
        }
    }
}
