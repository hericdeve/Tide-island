import QtQuick
import IslandBackend
import "../components"

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

        WidgetIconGlyph {
            id: calIcon
            glyph: "󰸗"
            size: 14
            color: StyleTokens.danger
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }

        WidgetTextView {
            text: root.eventSummary !== "" ? root.eventSummary : Qt.formatDate(new Date(), "ddd, MMM d")
            role: "body"
            overflowMode: "marquee"
            marqueeSpeed: 25
            maximumLineCount: 1
            colorOverride: StyleTokens.textPrimary
            width: Math.min(measuredWidth, Math.max(0, root.width - calIcon.width - contentRow.spacing - 12))
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
