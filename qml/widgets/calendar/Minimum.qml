import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18
    readonly property var nextEv: CalendarBackend ? CalendarBackend.nextEvent(new Date()) : null
    readonly property string eventSummary: (nextEv && nextEv.title) ? nextEv.title : ""

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 7

        Text {
            id: iconText
            text: "󰸗"
            font.family: root.iconFontFamily
            font.pixelSize: Math.round(16 * root.iconFontSize / 18.0)
            color: "#ff3b30"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.eventSummary !== "" ? root.eventSummary : Qt.formatDate(new Date(), "ddd, MMM d")
            font.family: root.textFontFamily
            font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
            font.weight: Font.DemiBold
            color: "white"
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, Math.max(0, root.width - iconText.width - contentRow.spacing - 8))
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
