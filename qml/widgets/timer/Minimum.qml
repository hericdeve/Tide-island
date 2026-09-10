import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property int elapsedSeconds: 0

    readonly property real requestedContentWidth: Math.min(190, contentRow.implicitWidth + 20)
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    Item {
        anchors.fill: parent
        anchors.margins: 2

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            WidgetIconGlyph {
                glyph: "󰔛"
                size: 14
                color: StyleTokens.accent
                widgetContext: root.widgetContext
            }

            WidgetTimerClock {
                mode: "stopwatch"
                representation: "compact"
                running: false
                elapsedSeconds: root.elapsedSeconds
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }
        }
    }
}