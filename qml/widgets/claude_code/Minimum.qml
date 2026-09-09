import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    readonly property string state: ClaudeCodeBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (ClaudeCodeBackend.pendingConsentId !== "")
    readonly property bool showsLastMessage: UserConfig.claudeMinimumShowsLastMessage || ClaudeCodeBackend.minimumShowsLastMessage

    function stateColor() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return "#6b7280";
        switch (root.state) {
        case "waiting_consent": return "#f59e0b";
        case "thinking": return "#a855f7";
        case "running_tool": return "#3b82f6";
        case "error": return "#ef4444";
        case "done": return "#10b981";
        case "idle": default: return "#10b981";
        }
    }

    function statusLabel() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return "Claude Offline";
        if (root.isWaitingConsent) {
            return "Permission: " + (ClaudeCodeBackend.pendingConsentTool || "Tool");
        }
        switch (root.state) {
        case "thinking": return "Thinking...";
        case "running_tool": return (ClaudeCodeBackend.currentTool ? ClaudeCodeBackend.currentTool : "Working");
        case "error": return "Error";
        case "done": return "Done";
        case "idle": default:
            return (ClaudeCodeBackend.projectName || "Claude") + " • " + Math.round(ClaudeCodeBackend.contextUsagePercent * 100) + "%";
        }
    }

    function displayLabel() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return "Claude Offline";
        if (root.isWaitingConsent) {
            return "Permission: " + (ClaudeCodeBackend.pendingConsentTool || "Tool");
        }
        if (root.showsLastMessage) {
            const rawMsg = ClaudeCodeBackend.lastMessage || "";
            const msg = rawMsg.replace(/\r?\n|\r/g, " ").trim();
            if (msg.length > 0) {
                return msg;
            }
        }
        return root.statusLabel();
    }

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // Ambient breathing status dot
        Item {
            id: statusDot
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: dotCore
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.stateColor()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
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
        Text {
            id: statusText
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayLabel()
            font.family: root.textFontFamily
            font.pixelSize: 11
            font.weight: root.isWaitingConsent ? Font.Bold : Font.Medium
            color: root.isWaitingConsent ? "#f59e0b" : (root.state === "error" ? "#fca5a5" : "white")
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, Math.max(0, root.width - statusDot.width - contentRow.spacing - 12))
        }
    }
}
