import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var nextEv: CalendarBackend ? CalendarBackend.nextEvent(new Date()) : null
    readonly property bool hasUpcoming: !!(nextEv && nextEv.title)

    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 1

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "MMM").toUpperCase()
            role: "caption"
            colorOverride: StyleTokens.danger
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "d")
            role: "title"
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: 2
            color: root.hasUpcoming ? StyleTokens.success : StyleTokens.transparent
        }
    }
}
