import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    readonly property var nextEv: CalendarBackend ? CalendarBackend.nextEvent(new Date()) : null
    readonly property bool hasUpcoming: !!(nextEv && nextEv.title)

    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "MMM").toUpperCase()
            font.family: root.textFontFamily
            font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
            font.weight: Font.Bold
            color: "#ff3b30"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "d")
            font.family: root.textFontFamily
            font.pixelSize: Math.round(18 * root.titleFontSize / 20.0)
            font.weight: Font.Bold
            color: "white"
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: 2
            color: root.hasUpcoming ? "#30d158" : "transparent"
        }
    }
}
