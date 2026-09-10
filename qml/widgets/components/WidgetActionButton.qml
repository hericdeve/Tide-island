import QtQuick
import IslandBackend

Rectangle {
    id: root

    property string variant: "capsule" // "icon" | "capsule" | "pill"
    property string buttonStyle: "secondary" // "primary" | "secondary" | "ghost" | "danger"
    property string icon: ""
    property string label: ""
    property bool enabled: true
    property real radiusOverride: StyleTokens.radiusButton
    property var widgetContext: null

    signal clicked()
    signal pressed()
    signal released()

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isPressed: mouseArea.pressed

    // Compute surface background color
    readonly property color computedBackground: {
        if (!enabled)
            return StyleTokens.transparent;

        if (buttonStyle === "primary") {
            if (isPressed) return StyleTokens.accentPressed;
            if (isHovered) return StyleTokens.accentSoft;
            return StyleTokens.accent;
        }

        if (buttonStyle === "danger") {
            if (isPressed) return Qt.darker(StyleTokens.danger, 1.2);
            if (isHovered) return Qt.lighter(StyleTokens.danger, 1.15);
            return StyleTokens.danger;
        }

        if (buttonStyle === "ghost") {
            if (isPressed) return Qt.rgba(1, 1, 1, 0.12);
            if (isHovered) return Qt.rgba(1, 1, 1, 0.06);
            return StyleTokens.transparent;
        }

        // Default "secondary"
        if (isPressed) return StyleTokens.buttonFillPressed;
        if (isHovered) return StyleTokens.buttonFillHover;
        return StyleTokens.buttonFill;
    }

    // Compute text/icon foreground color
    readonly property color computedForeground: {
        if (!enabled)
            return StyleTokens.textDisabled;
        if (buttonStyle === "primary" || buttonStyle === "danger")
            return StyleTokens.white;
        return StyleTokens.textPrimary;
    }

    radius: radiusOverride
    color: computedBackground
    border.width: buttonStyle === "secondary" && !isHovered ? 1 : 0
    border.color: StyleTokens.track

    // Auto dimensions
    implicitHeight: variant === "icon" ? 28 : 28
    implicitWidth: {
        if (variant === "icon") return 28;
        return contentRow.implicitWidth + 20;
    }

    scale: isPressed ? 0.94 : 1.0
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation { duration: StyleTokens.durationFast; easing.type: Easing.OutQuad }
    }

    Behavior on color {
        ColorAnimation { duration: StyleTokens.durationFast }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: iconText
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: Math.round(13 * root.bodyFontSize / 16.0)
            color: root.computedForeground
        }

        Text {
            id: labelText
            visible: root.variant !== "icon" && root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: root.textFont
            font.pixelSize: Math.round(12 * root.bodyFontSize / 16.0)
            font.weight: Font.DemiBold
            color: root.computedForeground
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        onPressed: root.pressed()
        onReleased: root.released()
        onClicked: root.clicked()
    }
}
