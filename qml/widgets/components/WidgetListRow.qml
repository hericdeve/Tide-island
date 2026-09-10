import QtQuick
import IslandBackend

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string accessoryText: ""
    property bool showChevron: false
    property bool clickable: true
    property bool selected: false
    property var widgetContext: null

    signal clicked()

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    height: subtitle.length > 0 ? 42 : 32
    radius: StyleTokens.radiusButton
    color: {
        if (selected) return StyleTokens.cardFillActive;
        if (mouseArea.containsMouse) return StyleTokens.moduleHover;
        return StyleTokens.transparent;
    }

    Behavior on color {
        ColorAnimation { duration: StyleTokens.durationFast }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Leading Icon
        Text {
            id: leadIcon
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
            color: root.selected ? StyleTokens.accent : StyleTokens.textSecondary
        }

        // Center Content (Title + Subtitle)
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - (leadIcon.visible ? leadIcon.width + parent.spacing : 0)
                                    - (accessoryArea.visible ? accessoryArea.width + parent.spacing : 0))
            spacing: 2

            Text {
                width: parent.width
                text: root.title
                font.family: root.textFont
                font.pixelSize: Math.round(12 * root.bodyFontSize / 16.0)
                font.weight: Font.Medium
                color: root.selected ? StyleTokens.textPrimaryBright : StyleTokens.textPrimary
                elide: Text.ElideRight
            }

            Text {
                visible: root.subtitle.length > 0
                width: parent.width
                text: root.subtitle
                font.family: root.textFont
                font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                color: StyleTokens.textTertiary
                elide: Text.ElideRight
            }
        }

        // Right Accessory Area
        Row {
            id: accessoryArea
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.accessoryText.length > 0 || root.showChevron

            Text {
                visible: root.accessoryText.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.accessoryText
                font.family: root.textFont
                font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                color: StyleTokens.textSecondary
            }

            Text {
                visible: root.showChevron
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅂"
                font.family: root.iconFont
                font.pixelSize: 12
                color: StyleTokens.textTertiary
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onClicked: root.clicked()
    }
}
