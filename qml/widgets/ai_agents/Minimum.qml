import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18
    readonly property real scrollSpeed: widgetContext ? (widgetContext.textScrollSpeed || 17) : 17

    readonly property string state: AIAgentsBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (AIAgentsBackend.pendingConsentId !== "")
    readonly property bool showsLastMessage: UserConfig.aiAgentsMinimumShowsLastMessage || AIAgentsBackend.minimumShowsLastMessage

    function stateColor() {
        if (!AIAgentsBackend.connected && !AIAgentsBackend.demoMode) return StyleTokens.textDisabled;
        switch (root.state) {
        case "waiting_consent": return StyleTokens.warning;
        case "thinking": return StyleTokens.accentSoft;
        case "running_tool": return AIAgentsBackend.providerAccentColor;
        case "error": return StyleTokens.danger;
        case "done": return StyleTokens.success;
        case "idle": default: return StyleTokens.success;
        }
    }

    function statusLabel() {
        if (!AIAgentsBackend.connected && !AIAgentsBackend.demoMode) return "Agents Offline";
        if (root.isWaitingConsent) {
            return "Permission: " + (AIAgentsBackend.pendingConsentTool || "Tool");
        }
        switch (root.state) {
        case "thinking": return "Thinking...";
        case "running_tool": return (AIAgentsBackend.currentTool ? AIAgentsBackend.currentTool : "Working");
        case "error": return "Error";
        case "done": return "Done";
        case "idle": default:
            return (AIAgentsBackend.projectName || AIAgentsBackend.providerDisplayName) + " • " + Math.round(AIAgentsBackend.contextUsagePercent * 100) + "%";
        }
    }

    readonly property string displayText: {
        if (!AIAgentsBackend.connected && !AIAgentsBackend.demoMode) return "Agents Offline";
        if (root.isWaitingConsent) {
            return "Permission: " + (AIAgentsBackend.pendingConsentTool || "Tool");
        }
        if (root.showsLastMessage) {
            const rawMsg = AIAgentsBackend.lastMessage || "";
            const msg = rawMsg.replace(/\r?\n|\r/g, " ").trim();
            if (msg.length > 0) {
                return msg;
            }
        }
        return root.statusLabel();
    }

    readonly property real naturalContentWidth: 16 + 7 + statusTextView.measuredWidth + 24
    readonly property real requestedContentWidth: naturalContentWidth
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 7

        // Ambient breathing status dot + provider glyph
        Item {
            id: statusDot
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: dotCore
                anchors.centerIn: parent
                width: 9
                height: 9
                radius: 4.5
                color: root.stateColor()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.width: 1.5
                border.color: root.stateColor()
                opacity: (root.state === "thinking" || root.state === "running_tool" || root.isWaitingConsent) ? 0.8 : 0.0

                SequentialAnimation on scale {
                    running: root.state === "thinking" || root.state === "running_tool" || root.isWaitingConsent
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.4; duration: 800; easing.type: Easing.OutQuad }
                    NumberAnimation { from: 1.4; to: 1.0; duration: 800; easing.type: Easing.InQuad }
                }
                SequentialAnimation on opacity {
                    running: root.state === "thinking" || root.state === "running_tool" || root.isWaitingConsent
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.8; to: 0.2; duration: 800 }
                    NumberAnimation { from: 0.2; to: 0.8; duration: 800 }
                }
            }
        }

        // Status text
        WidgetTextView {
            id: statusTextView
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(measuredWidth, Math.max(0, root.width - statusDot.width - contentRow.spacing - 12))
            text: root.displayText
            role: "body"
            overflowMode: "marquee"
            colorOverride: root.isWaitingConsent ? StyleTokens.warning : (root.state === "error" ? StyleTokens.danger : StyleTokens.textPrimary)
            widgetContext: root.widgetContext
        }
    }
}
