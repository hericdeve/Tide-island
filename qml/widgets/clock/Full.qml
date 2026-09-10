import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string heroFontFamily: widgetContext ? widgetContext.heroFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20

    property string currentSeconds: "00"
    property string currentDate: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.currentSeconds = Qt.formatTime(now, "ss");
            root.currentDate = Qt.formatDate(now, "dddd, MMMM d");
        }
    }

    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            WidgetTimerClock {
                mode: "clock"
                clockFormat: "hh:mm"
                representation: "digital"
                widgetContext: root.widgetContext
            }

            Text {
                text: root.currentSeconds
                font.family: root.heroFontFamily
                font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
                font.weight: Font.DemiBold
                color: StyleTokens.textSecondary
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                font.features: { "tnum": 1 }
            }
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "body"
            text: root.currentDate
            colorOverride: StyleTokens.textSecondary
            widgetContext: root.widgetContext
        }
    }
}
