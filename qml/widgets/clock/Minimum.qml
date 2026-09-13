import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property string currentDate: ""

    readonly property real requestedContentWidth: Math.max(185, Math.ceil(widgetRow.implicitWidth + 24))
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

        Row {
            id: widgetRow
            anchors.centerIn: parent
            spacing: 6

            Row {
                id: dateInfo
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                WidgetTextView {
                    text: root.currentDate
                    role: "body"
                    colorOverride: StyleTokens.textPrimary
                    widgetContext: root.widgetContext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                id: clockSegment
                width: clockDisplay.implicitWidth
                height: clockDisplay.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                WidgetTimerClock {
                    id: clockDisplay
                    anchors.centerIn: parent
                    mode: "clock"
                    clockFormat: (UserConfig && UserConfig.clockFormat === "12h") ? "h:mm" : "hh:mm"
                    representation: "compact"
                    widgetContext: root.widgetContext
                }
            }
        }
    }
}
