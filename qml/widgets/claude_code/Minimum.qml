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
    readonly property real scrollSpeed: widgetContext ? widgetContext.claudeCodeScrollSpeed : 17

    onScrollSpeedChanged: {
        statusScrollAnimation.restart();
    }

    readonly property string state: ClaudeCodeBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (ClaudeCodeBackend.pendingConsentId !== "")
    readonly property bool showsLastMessage: UserConfig.claudeMinimumShowsLastMessage || ClaudeCodeBackend.minimumShowsLastMessage

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

    readonly property string displayText: {
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

    function displayLabel() {
        return root.displayText;
    }

    readonly property real naturalContentWidth: 16 + 7 + statusTextContent.implicitWidth + 24
    readonly property real requestedContentWidth: naturalContentWidth
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 7

        // Ambient breathing status dot
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
        Flickable {
            id: statusViewport
            readonly property int textSpacing: Math.round(3.0 * root.bodyFontSize)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(statusTextContent.implicitWidth, Math.max(0, root.width - statusDot.width - contentRow.spacing - 12))
            height: statusTextContent.implicitHeight
            clip: true
            interactive: false
            contentWidth: statusScrollAnimation.running
                ? (statusTextContent.implicitWidth * 2 + textSpacing)
                : statusTextContent.implicitWidth
            contentHeight: height
            opacity: 1.0

            onWidthChanged: {
                contentX = 0;
                statusScrollAnimation.restart();
            }

            Text {
                id: statusTextContent
                x: 0
                width: implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayText
                font.family: root.textFontFamily
                font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
                font.weight: root.isWaitingConsent ? Font.Bold : Font.DemiBold
                color: root.isWaitingConsent ? StyleTokens.warning : (root.state === "error" ? StyleTokens.danger : StyleTokens.textPrimary)

                onImplicitWidthChanged: {
                    statusViewport.contentX = 0;
                    statusScrollAnimation.restart();
                }
                onTextChanged: {
                    statusViewport.contentX = 0;
                    statusScrollAnimation.restart();
                }
            }

            Text {
                id: statusTextDuplicate
                x: statusTextContent.implicitWidth + statusViewport.textSpacing
                width: implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                visible: statusScrollAnimation.running
                text: statusTextContent.text
                font.family: statusTextContent.font.family
                font.pixelSize: statusTextContent.font.pixelSize
                font.weight: statusTextContent.font.weight
                color: statusTextContent.color
            }

            NumberAnimation {
                id: statusScrollAnimation
                target: statusViewport
                property: "contentX"
                from: 0
                to: statusTextContent.implicitWidth + statusViewport.textSpacing
                duration: Math.max(1, (statusTextContent.implicitWidth + statusViewport.textSpacing) / Math.max(1, root.scrollSpeed) * 1000)
                running: statusTextContent.implicitWidth > statusViewport.width
                loops: Animation.Infinite
                easing.type: Easing.Linear

                onRunningChanged: {
                    if (!running) {
                        statusViewport.contentX = 0;
                    }
                }
            }
        }
    }
}
