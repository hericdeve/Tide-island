import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18
    readonly property real scrollSpeed: widgetContext ? widgetContext.claudeCodeScrollSpeed : 17

    readonly property string state: ClaudeCodeBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (ClaudeCodeBackend.pendingConsentId !== "")
    readonly property real contextPercent: Math.max(0.0, Math.min(1.0, ClaudeCodeBackend.contextUsagePercent))
    readonly property real diameter: Math.min(width, height)
    readonly property bool isPillMode: root.width > (root.height + 8)

    function stateColor() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return StyleTokens.textDisabled;
        switch (root.state) {
        case "waiting_consent": return StyleTokens.warning;
        case "thinking": return StyleTokens.accentSoft;
        case "running_tool": return StyleTokens.accent;
        case "error": return StyleTokens.danger;
        case "done": return StyleTokens.success;
        case "idle": default: return StyleTokens.success;
        }
    }

    function arcColor() {
        if (root.contextPercent > 0.85) return StyleTokens.danger;
        if (root.contextPercent > 0.65) return StyleTokens.warning;
        return StyleTokens.accent;
    }

    function displayStatusText() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return "Offline";
        if (root.isWaitingConsent) return "Permission: " + (ClaudeCodeBackend.pendingConsentTool || "Tool");
        switch (root.state) {
        case "thinking": return "Thinking...";
        case "running_tool": return ClaudeCodeBackend.currentTool ? ClaudeCodeBackend.currentTool : "Working";
        case "error": return "Error";
        case "done": return "Done";
        default:
            const raw = ClaudeCodeBackend.lastMessage || "";
            if (raw.trim().length > 0) return raw.trim();
            return (ClaudeCodeBackend.projectName || "Claude") + " " + Math.round(root.contextPercent * 100) + "%";
        }
    }

    function requestPaint() {
        if (ringCanvas) ringCanvas.requestPaint();
    }

    TextMetrics {
        id: circleTextMetrics
        font.family: root.textFontFamily
        font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
        text: root.displayStatusText()
    }

    readonly property bool shouldRequestPill: {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return false;
        return root.state === "thinking" || root.state === "running_tool" || root.isWaitingConsent
            || (root.state === "done" && ClaudeCodeBackend.lastMessage !== "");
    }

    readonly property real requestedContentWidth: {
        if (!shouldRequestPill) return 0;
        const needed = 44 + circleTextMetrics.width + 20;
        return needed > 44 ? needed : 0;
    }
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    // Complication container (smoothly shifts left when expanding into a pill)
    Item {
        id: complicationContainer
        anchors.verticalCenter: parent.verticalCenter
        x: root.isPillMode ? 6 : (parent.width - width) / 2
        width: root.isPillMode ? Math.max(26, root.height - 12) : parent.height
        height: width

        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Context Usage Radial Ring
        Canvas {
            id: ringCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = Math.min(cx, cy) - 2.5;
                if (radius <= 0) return;

                // Background track
                ctx.strokeStyle = StyleTokens.track;
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.stroke();

                // Context window usage arc
                if (root.contextPercent > 0.01) {
                    ctx.strokeStyle = root.arcColor();
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle + (Math.PI * 2 * root.contextPercent);
                    ctx.arc(cx, cy, radius, startAngle, endAngle);
                    ctx.stroke();
                }
            }

            Connections {
                target: ClaudeCodeBackend
                function onTokenMetricsChanged() { ringCanvas.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
        }

        // Thinking / Tool Rotating Radar Sweep
        Item {
            anchors.centerIn: parent
            width: Math.max(10, complicationContainer.width - 8)
            height: width
            visible: root.state === "thinking" || root.state === "running_tool"

            RotationAnimation on rotation {
                running: root.state === "thinking" || root.state === "running_tool"
                loops: Animation.Infinite
                from: 0; to: 360; duration: 1600
            }

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3
                height: 3
                radius: 1.5
                color: root.stateColor()
            }
        }

        // Central Complication Content
        Column {
            anchors.centerIn: parent
            spacing: 0

            WidgetIconGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                glyph: root.isWaitingConsent ? "󰀦" : ((root.state === "running_tool") ? "󰞷" : "󰚩")
                size: root.isPillMode ? 10 : 13
                color: root.stateColor()
                widgetContext: root.widgetContext

                // Pulsing animation if waiting consent
                SequentialAnimation on opacity {
                    running: root.isWaitingConsent
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 450 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 450 }
                }
            }

            WidgetTextView {
                visible: !root.isPillMode
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.contextPercent * 100) + "%"
                role: "caption"
                tabularFigures: true
                colorOverride: StyleTokens.textSecondary
                widgetContext: root.widgetContext
            }
        }
    }

    // Side Status Label in Pill Mode
    WidgetTextView {
        id: pillStatusTextView
        anchors.left: complicationContainer.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.displayStatusText()
        role: "caption"
        overflowMode: "marquee"
        marqueeSpeed: root.scrollSpeed
        colorOverride: root.isWaitingConsent ? StyleTokens.warning : (root.state === "error" ? StyleTokens.danger : StyleTokens.textPrimary)
        widgetContext: root.widgetContext
        opacity: root.isPillMode ? 1.0 : 0.0
        visible: opacity > 0.001

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
    }
}
