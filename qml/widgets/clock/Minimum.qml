import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    anchors.fill: parent

    WidgetTimerClock {
        anchors.centerIn: parent
        mode: "clock"
        clockFormat: "hh:mm"
        representation: "compact"
        widgetContext: root.widgetContext
    }
}
