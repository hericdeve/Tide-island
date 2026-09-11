import QtQuick
import QtQuick.Controls
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

    readonly property string state: ClaudeCodeBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (ClaudeCodeBackend.pendingConsentId !== "")

    // Off-screen measuring items to determine wrapped content height
    WidgetTextView {
        id: bannerTextMeasure
        measureOnly: true
        width: Math.max(120, (root.width > 0 ? root.width : 600) - (root.state === "error" ? 56 : 36))
        role: "body"
        overflowMode: "wrap"
        text: ClaudeCodeBackend.toolDetail || ClaudeCodeBackend.lastMessage || ""
        widgetContext: root.widgetContext
    }

    WidgetTextView {
        id: consentTextMeasure
        measureOnly: true
        width: Math.max(120, (root.width > 0 ? root.width : 600) - 40)
        role: "code"
        overflowMode: "wrap"
        text: ClaudeCodeBackend.pendingConsentDetail || ClaudeCodeBackend.toolDetail || ""
        widgetContext: root.widgetContext
    }

    readonly property real baseSlotHeight: Math.max(120, (UserConfig.notchOpenHeight || 190) - 52)

    readonly property real requestedContentWidth: {
        // In full view, only request horizontal expansion if the slot is cramped in a multi-slot page
        if (root.width > 0 && root.width < 320) {
            return 360;
        }
        return 0;
    }

    readonly property real requestedContentHeight: {
        if (root.isWaitingConsent) {
            const h = consentTextMeasure.implicitHeight;
            if (h > 42) {
                const extraH = Math.min(120, h - 42);
                return baseSlotHeight + extraH;
            }
            return 0;
        }

        const bannerH = bannerTextMeasure.implicitHeight;
        // Standard resting banner fits 1 wrapped line (~20px with base 13)
        if (bannerH > 22) {
            const extraH = Math.min(120, bannerH - 18);
            return baseSlotHeight + extraH;
        }
        return 0;
    }

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

    function stateText() {
        if (!ClaudeCodeBackend.connected && !ClaudeCodeBackend.demoMode) return "Offline";
        switch (root.state) {
        case "waiting_consent": return "Approval Required";
        case "thinking": return "Thinking...";
        case "running_tool": return "Running " + (ClaudeCodeBackend.currentTool || "Tool");
        case "error": return "Error";
        case "done": return "Finished";
        case "idle": default: return "Ready";
        }
    }

    anchors.fill: parent

    Item {
        anchors.fill: parent
        anchors.margins: 2

        // -------------------------------------------------------------
        // CONSENT OVERLAY (Takes precedence when approval is needed)
        // -------------------------------------------------------------
        Item {
            id: consentView
            anchors.fill: parent
            visible: root.isWaitingConsent

            Row {
                id: consentHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 22
                spacing: 6

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#33f59e0b"
                    WidgetIconGlyph {
                        anchors.centerIn: parent
                        glyph: "󰀦"
                        size: 13
                        color: "#f59e0b"
                        widgetContext: root.widgetContext
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    WidgetTextView {
                        text: "Action Permission"
                        role: "caption"
                        colorOverride: StyleTokens.textPrimary
                        widgetContext: root.widgetContext
                    }
                    WidgetTextView {
                        text: "Tool: " + (ClaudeCodeBackend.pendingConsentTool || ClaudeCodeBackend.currentTool || "Action")
                        role: "caption"
                        colorOverride: "#d1d5db"
                        overflowMode: "elide"
                        width: parent.width
                        widgetContext: root.widgetContext
                    }
                }
            }

            // Button row: Allow / Always / Deny (anchored to bottom)
            Row {
                id: consentButtons
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24
                spacing: 6

                WidgetActionButton {
                    width: (parent.width - 12) / 3
                    height: parent.height
                    variant: "pill"
                    buttonStyle: "secondary"
                    label: "Allow"
                    widgetContext: root.widgetContext
                    onClicked: ClaudeCodeBackend.allowConsent(false)
                }

                WidgetActionButton {
                    width: (parent.width - 12) / 3
                    height: parent.height
                    variant: "pill"
                    buttonStyle: "primary"
                    label: "Always"
                    widgetContext: root.widgetContext
                    onClicked: ClaudeCodeBackend.allowConsent(true)
                }

                WidgetActionButton {
                    width: (parent.width - 12) / 3
                    height: parent.height
                    variant: "pill"
                    buttonStyle: "danger"
                    label: "Deny"
                    widgetContext: root.widgetContext
                    onClicked: ClaudeCodeBackend.denyConsent()
                }
            }

            // Monospace detail box (anchored in the middle, fills all space)
            Rectangle {
                id: consentDetailBox
                anchors.top: consentHeader.bottom
                anchors.topMargin: 6
                anchors.bottom: consentButtons.top
                anchors.bottomMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 6
                color: "#0f0f12"
                border.width: 1
                border.color: "#26ffffff"
                clip: true

                Flickable {
                    id: consentFlickable
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: detailText.width
                    contentHeight: detailText.height
                    boundsBehavior: Flickable.StopAtBounds

                    WidgetTextView {
                        id: detailText
                        text: ClaudeCodeBackend.pendingConsentDetail || ClaudeCodeBackend.toolDetail || "Execute command"
                        role: "code"
                        overflowMode: "wrap"
                        colorOverride: "#93c5fd"
                        width: Math.max(10, consentFlickable.width - 12)
                        widgetContext: root.widgetContext
                    }
                }
            }
        }

            // -------------------------------------------------------------
            // STANDARD MONITORING VIEW (Single-slot or Multi-slot)
            // -------------------------------------------------------------
            Item {
                id: standardView
                anchors.fill: parent
                visible: !root.isWaitingConsent

                // Top row: Avatar/Status + Project/Branch + Action buttons
                Row {
                    id: topRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24
                    spacing: 6

                    // Status dot & Icon
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#27272a"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: "󰚩"
                            size: 13
                            color: root.stateColor()
                            widgetContext: root.widgetContext
                        }

                        // Pulsing ambient ring when active
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: "transparent"
                            border.width: 1.5
                            border.color: root.stateColor()
                            opacity: (root.state === "thinking" || root.state === "running_tool") ? 0.8 : 0.0

                            SequentialAnimation on scale {
                                running: root.state === "thinking" || root.state === "running_tool"
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 1.35; duration: 900; easing.type: Easing.OutQuad }
                                NumberAnimation { from: 1.35; to: 1.0; duration: 900; easing.type: Easing.InQuad }
                            }
                            SequentialAnimation on opacity {
                                running: root.state === "thinking" || root.state === "running_tool"
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.8; to: 0.1; duration: 900 }
                                NumberAnimation { from: 0.1; to: 0.8; duration: 900 }
                            }
                        }
                    }

                    // Project & State
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - 6 - (actionsRow.width + 6)
                        spacing: 1

                        Row {
                            spacing: 4
                            WidgetTextView {
                                text: ClaudeCodeBackend.projectName || "Claude Code"
                                role: "caption"
                                colorOverride: StyleTokens.textPrimary
                                overflowMode: "elide"
                                widgetContext: root.widgetContext
                            }
                            // Branch tag
                            Rectangle {
                                visible: ClaudeCodeBackend.gitBranch !== ""
                                height: 13
                                width: branchLabel.implicitWidth + 8
                                radius: 4
                                color: "#27272a"
                                Row {
                                    id: branchLabel
                                    anchors.centerIn: parent
                                    spacing: 3
                                    WidgetIconGlyph {
                                        glyph: "󰘬"
                                        size: 8
                                        color: "#9ca3af"
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: ClaudeCodeBackend.gitBranch
                                        role: "caption"
                                        colorOverride: "#d1d5db"
                                        widgetContext: root.widgetContext
                                    }
                                }
                            }
                        }

                        WidgetTextView {
                            text: root.stateText() + (ClaudeCodeBackend.currentTool ? " (" + ClaudeCodeBackend.currentTool + ")" : "")
                            role: "caption"
                            colorOverride: root.stateColor()
                            overflowMode: "elide"
                            width: parent.width
                            widgetContext: root.widgetContext
                        }
                    }

                    // Action buttons (Minimum View Mode Toggle + Terminal + Demo Simulator)
                    Row {
                        id: actionsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Minimum View Mode Toggle (Status vs Last Message)
                        Rectangle {
                            id: minModeBtn
                            readonly property bool showsLastMsg: UserConfig.claudeMinimumShowsLastMessage || ClaudeCodeBackend.minimumShowsLastMessage
                            readonly property bool compact: root.width < 280

                            width: compact ? 20 : (minModeRow.implicitWidth + 12)
                            height: 20
                            radius: StyleTokens.radiusButton
                            color: minModeMouse.containsMouse
                                ? (showsLastMsg ? "#9333ea" : "#3f3f46")
                                : (showsLastMsg ? "#7e22ce" : "#27272a")
                            border.width: 1
                            border.color: showsLastMsg ? "#c084fc" : "#3f3f46"

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                id: minModeRow
                                anchors.centerIn: parent
                                spacing: 4

                                WidgetIconGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: minModeBtn.showsLastMsg ? "󰍡" : "󰚩"
                                    size: 10
                                    color: minModeBtn.showsLastMsg ? "#ffffff" : "#9ca3af"
                                    widgetContext: root.widgetContext
                                }

                                WidgetTextView {
                                    visible: !minModeBtn.compact
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: minModeBtn.showsLastMsg ? "Min: Last Msg" : "Min: Status"
                                    role: "caption"
                                    colorOverride: minModeBtn.showsLastMsg ? "#ffffff" : "#d1d5db"
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                id: minModeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const next = !minModeBtn.showsLastMsg;
                                    UserConfig.setClaudeMinimumShowsLastMessage(next);
                                    ClaudeCodeBackend.setMinimumShowsLastMessage(next);
                                }
                            }
                        }

                        // Demo Mode Toggle (lets user preview states without running Claude)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: StyleTokens.radiusButton
                            color: demoBtnMouse.containsMouse ? "#3f3f46" : "#27272a"
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰍉"
                                size: 10
                                color: ClaudeCodeBackend.demoMode ? "#a855f7" : "#9ca3af"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                id: demoBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!ClaudeCodeBackend.demoMode) {
                                        ClaudeCodeBackend.setDemoState("waiting_consent");
                                    } else if (ClaudeCodeBackend.sessionState === "waiting_consent") {
                                        ClaudeCodeBackend.setDemoState("thinking");
                                    } else if (ClaudeCodeBackend.sessionState === "thinking") {
                                        ClaudeCodeBackend.setDemoState("running_tool");
                                    } else if (ClaudeCodeBackend.sessionState === "running_tool") {
                                        ClaudeCodeBackend.setDemoState("done");
                                    } else {
                                        ClaudeCodeBackend.setDemoMode(false);
                                    }
                                }
                            }
                        }

                        // Terminal button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: StyleTokens.radiusButton
                            color: termBtnMouse.containsMouse ? "#3f3f46" : "#27272a"
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰆍"
                                size: 10
                                color: "#e4e4e7"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                id: termBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ClaudeCodeBackend.openTerminal()
                            }
                        }
                    }
                }

                // Middle: Last message or active activity banner
                Rectangle {
                    id: activityBanner
                    anchors.top: topRow.bottom
                    anchors.topMargin: 4
                    anchors.bottom: contextStats.top
                    anchors.bottomMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    radius: 6
                    color: root.state === "error" ? "#221113" : "#111113"
                    border.width: 1
                    border.color: root.state === "error" ? "#33ef4444" : "#1affffff"
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 5

                        WidgetIconGlyph {
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            glyph: (root.state === "thinking") ? "󰑣" : ((root.state === "running_tool") ? "󰞷" : ((root.state === "error") ? "󰅚" : "󰋼"))
                            size: 11
                            color: root.stateColor()
                            widgetContext: root.widgetContext

                            RotationAnimation on rotation {
                                running: root.state === "thinking"
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        WidgetTextView {
                            id: bannerText
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - (dismissErrorBtn.visible ? 20 : 0)
                            text: ClaudeCodeBackend.toolDetail || ClaudeCodeBackend.lastMessage || "Ready to assist"
                            role: "body"
                            overflowMode: "wrap"
                            colorOverride: root.state === "error" ? "#fca5a5" : "#e4e4e7"
                            widgetContext: root.widgetContext
                        }

                        Item {
                            id: dismissErrorBtn
                            visible: root.state === "error"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16

                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰅖"
                                size: 10
                                color: dismissMouse.containsMouse ? "#ffffff" : "#ef4444"
                                widgetContext: root.widgetContext
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClaudeCodeBackend.clearError()
                            }
                        }
                    }
                }

                // Context bar and Token stats
                Column {
                    id: contextStats
                    anchors.bottom: promptBar.top
                    anchors.bottomMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 3

                    Row {
                        width: parent.width
                        WidgetTextView {
                            text: Math.round(ClaudeCodeBackend.contextUsagePercent * 100) + "% Context"
                            role: "caption"
                            tabularFigures: true
                            colorOverride: "#9ca3af"
                            widgetContext: root.widgetContext
                        }
                        Item { width: Math.max(0, parent.width - costLabel.width - 70); height: 1 }
                        WidgetTextView {
                            id: costLabel
                            text: "$" + ClaudeCodeBackend.estimatedCost.toFixed(2) + " · " + (ClaudeCodeBackend.modelName || "Claude")
                            role: "caption"
                            tabularFigures: true
                            colorOverride: "#9ca3af"
                            widgetContext: root.widgetContext
                        }
                    }

                    // Progress bar
                    WidgetProgressBar {
                        width: parent.width
                        barHeight: 4
                        value: ClaudeCodeBackend.contextUsagePercent
                        fillColor: {
                            const p = ClaudeCodeBackend.contextUsagePercent;
                            if (p > 0.85) return StyleTokens.danger;
                            if (p > 0.65) return StyleTokens.warning;
                            return StyleTokens.accent;
                        }
                        trackColor: StyleTokens.track
                    }
                }

                // Bottom: Quick Prompt Bar
                WidgetSearchInput {
                    id: promptBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    inputHeight: 26
                    placeholder: "Ask Claude Code..."
                    icon: "󰍉"
                    showClearButton: false
                    widgetContext: root.widgetContext
                    onAccepted: query => {
                        if (query.trim() !== "") {
                            ClaudeCodeBackend.sendQuickPrompt(query.trim());
                            text = "";
                        }
                    }
                }
            }
        }
    }
