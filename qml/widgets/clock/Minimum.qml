import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property string currentDate: ""

    readonly property real requestedContentWidth: Math.min(230, clockSegment.width + dateInfo.implicitWidth + 26)
    readonly property real requestedContentHeight: 0

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.currentDate = Qt.formatDate(now, "ddd, MMM d");
        }
    }

    anchors.fill: parent

    Item {
        id: contentRow
        anchors.fill: parent

        Item {
            id: clockSegment
            width: 58
            height: clockDisplay.implicitHeight
            anchors.centerIn: parent

            WidgetTimerClock {
                id: clockDisplay
                anchors.centerIn: parent
                mode: "clock"
                clockFormat: "hh:mm"
                representation: "compact"
                widgetContext: root.widgetContext
            }
        }

        Row {
            id: dateInfo
            x: clockSegment.x + clockSegment.width + 6
            anchors.verticalCenter: clockSegment.verticalCenter
            spacing: 6

            Text {
                text: "·"
                font.family: root.widgetContext ? root.widgetContext.textFontFamily : "sans-serif"
                font.pixelSize: Math.round(13 * (root.widgetContext ? root.widgetContext.bodyFontSize : 16) / 16.0)
                color: StyleTokens.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            WidgetTextView {
                text: root.currentDate
                role: "body"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
