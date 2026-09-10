import QtQuick
import IslandBackend

Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property string status: ""
    property color statusColor: StyleTokens.success
    property string actionIcon: ""
    property bool clickable: false
    property var widgetContext: null
    default property alias content: contentSlot.data

    signal clicked()
    signal actionClicked()

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    radius: StyleTokens.radiusModule
    color: StyleTokens.module
    border.width: 1
    border.color: StyleTokens.track

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Header Row
        Row {
            width: parent.width
            spacing: 6

            Text {
                visible: root.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                font.family: root.iconFont
                font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
                color: StyleTokens.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - (root.icon.length > 0 ? 20 : 0) - (actionBtn.visible ? 24 : 0) - (statusDot.visible ? 16 : 0))
                text: root.title
                font.family: root.textFont
                font.pixelSize: Math.round(13 * root.bodyFontSize / 16.0)
                font.weight: Font.DemiBold
                color: StyleTokens.textPrimary
                elide: Text.ElideRight
            }

            // Status Indicator Dot
            Rectangle {
                id: statusDot
                visible: root.status.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: root.statusColor
            }

            // Optional Header Action Button
            Item {
                id: actionBtn
                visible: root.actionIcon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                Text {
                    anchors.centerIn: parent
                    text: root.actionIcon
                    font.family: root.iconFont
                    font.pixelSize: 12
                    color: actionMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textTertiary
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: root.actionClicked()
                }
            }
        }

        // Body Content Slot
        Item {
            id: contentSlot
            width: parent.width
            height: Math.max(0, parent.height - 24)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onClicked: root.clicked()
    }
}
