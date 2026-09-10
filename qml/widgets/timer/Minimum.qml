import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property int elapsedSeconds: 0

    readonly property real requestedContentWidth: Math.min(220, contentRow.implicitWidth + 20)
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    Item {
        anchors.fill: parent
        anchors.margins: 2

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            WidgetIconGlyph {
                glyph: "󰔛"
                size: 14
                color: StyleTokens.accent
                widgetContext: root.widgetContext
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 50
                anchors.verticalCenter: parent.verticalCenter

                WidgetTextView {
                    text: "Stopwatch"
                    role: "caption"
                    colorOverride: StyleTokens.textSecondary
                    widgetContext: root.widgetContext
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 52
                    height: timerClock.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    WidgetTimerClock {
                        id: timerClock
                        anchors.centerIn: parent
                        mode: "stopwatch"
                        representation: "compact"
                        running: false
                        elapsedSeconds: root.elapsedSeconds
                        colorOverride: StyleTokens.textPrimary
                        widgetContext: root.widgetContext
                    }
                }

                WidgetTextView {
                    text: "Paused"
                    role: "caption"
                    colorOverride: StyleTokens.textMuted
                    widgetContext: root.widgetContext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}