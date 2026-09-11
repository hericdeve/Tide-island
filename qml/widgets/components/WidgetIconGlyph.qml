import QtQuick
import IslandBackend

Item {
    id: root

    property string glyph: "󰀀"
    property real size: 18
    property color color: StyleTokens.textPrimary
    property string badgeText: ""
    property bool badgeActive: false
    property color badgeColor: StyleTokens.danger
    property string animation: "none" // "none" | "pulse" | "spin"
    property var widgetContext: null

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18
    readonly property real computedSize: Math.round(size * iconFontSize / 18.0)

    width: Math.max(computedSize, iconText.implicitWidth)
    height: Math.max(computedSize, iconText.implicitHeight)

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.glyph
        font.family: root.iconFont
        font.pixelSize: root.computedSize
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        transformOrigin: Item.Center

        // Spin animation
        RotationAnimation on rotation {
            running: root.animation === "spin" && root.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1000
        }

        // Pulse animation
        SequentialAnimation on opacity {
            running: root.animation === "pulse" && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
    }

    // Status dot badge (when badgeActive is true and badgeText is empty)
    Rectangle {
        id: statusDot
        visible: root.badgeActive && root.badgeText.length === 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -2
        anchors.rightMargin: -2
        width: 6
        height: 6
        radius: 3
        color: root.badgeColor
    }

    // Numbered badge pill (when badgeText is non-empty)
    Rectangle {
        id: badgePill
        visible: root.badgeText.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4
        anchors.rightMargin: -6
        width: Math.max(14, badgeLabel.implicitWidth + 6)
        height: 14
        radius: 7
        color: root.badgeColor

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText
            font.family: root.widgetContext ? root.widgetContext.textFontFamily : "sans-serif"
            font.pixelSize: 9
            font.weight: Font.Bold
            color: StyleTokens.textOnError
        }
    }
}
