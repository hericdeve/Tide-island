import QtQuick
import IslandBackend

Item {
    id: root

    property string text: ""
    property string role: "body" // "hero" | "title" | "body" | "caption" | "metric" | "code"
    property string overflowMode: "elide" // "elide" | "marquee" | "wrap" | "clip"
    property int maximumLineCount: 1
    property real marqueeSpeed: 30 // pixels per second
    property color colorOverride: StyleTokens.transparent
    property bool measureOnly: false
    property var widgetContext: null

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property string heroFont: widgetContext ? widgetContext.heroFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20

    // Font family by role
    readonly property string computedFontFamily: {
        switch (role) {
        case "hero": return heroFont;
        case "code": return iconFont;
        default: return textFont;
        }
    }

    // Font size by role
    readonly property int computedFontSize: {
        switch (role) {
        case "hero": return Math.round(26 * bodyFontSize / 16.0);
        case "title": return Math.round(titleFontSize);
        case "body": return Math.round(13 * bodyFontSize / 16.0);
        case "caption": return Math.round(11 * bodyFontSize / 16.0);
        case "metric": return Math.round(15 * bodyFontSize / 16.0);
        case "code": return Math.round(11 * bodyFontSize / 16.0);
        default: return Math.round(bodyFontSize);
        }
    }

    // Font weight by role
    readonly property int computedFontWeight: {
        switch (role) {
        case "hero": return Font.Bold;
        case "title": return Font.DemiBold;
        case "metric": return Font.Bold;
        case "caption": return Font.Normal;
        default: return Font.Medium;
        }
    }

    // Color by role
    readonly property color computedColor: {
        if (colorOverride !== StyleTokens.transparent && colorOverride.a > 0)
            return colorOverride;
        switch (role) {
        case "hero":
        case "metric":
            return StyleTokens.textPrimaryBright;
        case "title":
            return StyleTokens.textPrimary;
        case "body":
            return StyleTokens.textSecondary;
        case "caption":
            return StyleTokens.textTertiary;
        case "code":
            return StyleTokens.textSoft;
        default:
            return StyleTokens.textPrimary;
        }
    }

    // Exposed dimensions for slot sizing
    readonly property real measuredWidth: probeText.implicitWidth
    readonly property real measuredHeight: probeText.implicitHeight

    implicitWidth: measuredWidth
    implicitHeight: measuredHeight
    width: implicitWidth
    height: implicitHeight
    clip: overflowMode === "marquee" || overflowMode === "clip"

    // Hidden probe for measurement
    Text {
        id: probeText
        visible: false
        text: root.text
        font.family: root.computedFontFamily
        font.pixelSize: root.computedFontSize
        font.weight: root.computedFontWeight
        wrapMode: root.overflowMode === "wrap" ? Text.Wrap : Text.NoWrap
        width: root.overflowMode === "wrap" ? root.width : undefined
        font.features: root.role === "metric" || root.role === "hero" ? { "tnum": 1 } : {}
    }

    // Standard static text display (elide, wrap, clip)
    Text {
        id: staticText
        visible: !root.measureOnly && root.overflowMode !== "marquee"
        anchors.fill: parent
        text: root.text
        font.family: root.computedFontFamily
        font.pixelSize: root.computedFontSize
        font.weight: root.computedFontWeight
        color: root.computedColor
        font.features: root.role === "metric" || root.role === "hero" ? { "tnum": 1 } : {}
        wrapMode: root.overflowMode === "wrap" ? Text.Wrap : Text.NoWrap
        maximumLineCount: root.overflowMode === "wrap" || root.overflowMode === "elide" ? root.maximumLineCount : 1
        elide: root.overflowMode === "elide" ? Text.ElideRight : Text.ElideNone
        verticalAlignment: Text.AlignVCenter
    }

    // Marquee scrolling display
    Item {
        id: marqueeContainer
        visible: !root.measureOnly && root.overflowMode === "marquee"
        anchors.fill: parent
        clip: true

        readonly property bool needsScroll: probeText.implicitWidth > root.width && root.width > 0
        readonly property real textGap: 28

        Item {
            id: scrollCanvas
            width: probeText.implicitWidth * 2 + marqueeContainer.textGap
            height: parent.height
            x: 0

            Text {
                id: mainMarqueeText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: root.computedFontFamily
                font.pixelSize: root.computedFontSize
                font.weight: root.computedFontWeight
                color: root.computedColor
                font.features: root.role === "metric" ? { "tnum": 1 } : {}
            }

            Text {
                id: duplicateMarqueeText
                anchors.left: mainMarqueeText.right
                anchors.leftMargin: marqueeContainer.textGap
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: root.computedFontFamily
                font.pixelSize: root.computedFontSize
                font.weight: root.computedFontWeight
                color: root.computedColor
                font.features: root.role === "metric" ? { "tnum": 1 } : {}
                visible: marqueeContainer.needsScroll
            }

            SequentialAnimation on x {
                running: marqueeContainer.needsScroll && root.visible
                loops: Animation.Infinite

                PauseAnimation { duration: 1200 }
                NumberAnimation {
                    from: 0
                    to: -(probeText.implicitWidth + marqueeContainer.textGap)
                    duration: Math.max(1000, (probeText.implicitWidth + marqueeContainer.textGap) / root.marqueeSpeed * 1000)
                    easing.type: Easing.Linear
                }
                PauseAnimation { duration: 800 }
                PropertyAction { target: scrollCanvas; property: "x"; value: 0 }
            }
        }
    }
}
