import QtQuick

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    property int remainingSeconds: 1500
    property bool isRunning: false

    readonly property string timeDisplay: {
        const mins = Math.floor(root.remainingSeconds / 60);
        const secs = root.remainingSeconds % 60;
        return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs);
    }

    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰄉"
            font.family: root.iconFontFamily
            font.pixelSize: 13
            color: "#ff453a"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.timeDisplay
            font.family: root.textFontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
