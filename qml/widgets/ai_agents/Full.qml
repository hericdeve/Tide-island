import QtQuick
import QtQuick.Controls
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property bool agentSubmenuOpen: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

    readonly property string state: AIAgentsBackend.sessionState
    readonly property bool isWaitingConsent: state === "waiting_consent" || (AIAgentsBackend.pendingConsentId !== "")

    // Off-screen measuring items to determine wrapped content height
    WidgetTextView {
        id: bannerTextMeasure
        measureOnly: true
        width: Math.max(120, (root.width > 0 ? root.width : 600) - (root.state === "error" ? 56 : 36))
        role: "body"
        overflowMode: "wrap"
        text: AIAgentsBackend.toolDetail || AIAgentsBackend.lastMessage || ""
        widgetContext: root.widgetContext
    }

    WidgetTextView {
        id: consentTextMeasure
        measureOnly: true
        width: Math.max(120, (root.width > 0 ? root.width : 600) - 40)
        role: "code"
        overflowMode: "wrap"
        text: AIAgentsBackend.pendingConsentDetail || AIAgentsBackend.toolDetail || ""
        widgetContext: root.widgetContext
    }

    readonly property real baseSlotHeight: Math.max(120, (UserConfig.notchOpenHeight || 190) - 52)

    readonly property real requestedContentWidth: {
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
        if (bannerH > 22) {
            const extraH = Math.min(120, bannerH - 18);
            return baseSlotHeight + extraH;
        }
        return 0;
    }

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

    function stateText() {
        if (!AIAgentsBackend.connected && !AIAgentsBackend.demoMode) return "Offline";
        switch (root.state) {
        case "waiting_consent": return "Approval Required";
        case "thinking": return "Thinking...";
        case "running_tool": return AIAgentsBackend.currentTool ? ("Running " + AIAgentsBackend.currentTool) : "Running Tool";
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
                        text: "Action Permission (" + AIAgentsBackend.providerDisplayName + ")"
                        role: "caption"
                        colorOverride: StyleTokens.textPrimary
                        widgetContext: root.widgetContext
                    }
                    WidgetTextView {
                        text: "Tool: " + (AIAgentsBackend.pendingConsentTool || AIAgentsBackend.currentTool || "Action")
                        role: "caption"
                        colorOverride: "#d1d5db"
                        overflowMode: "elide"
                        width: parent.width
                        widgetContext: root.widgetContext
                    }
                }
            }

            // Button row: Allow / Always / Deny
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
                    onClicked: AIAgentsBackend.allowConsent(false)
                }

                WidgetActionButton {
                    width: (parent.width - 12) / 3
                    height: parent.height
                    variant: "pill"
                    buttonStyle: "primary"
                    label: "Always"
                    widgetContext: root.widgetContext
                    onClicked: AIAgentsBackend.allowConsent(true)
                }

                WidgetActionButton {
                    width: (parent.width - 12) / 3
                    height: parent.height
                    variant: "pill"
                    buttonStyle: "danger"
                    label: "Deny"
                    widgetContext: root.widgetContext
                    onClicked: AIAgentsBackend.denyConsent()
                }
            }

            // Monospace detail box
            Rectangle {
                id: consentDetailBox
                anchors.top: consentHeader.bottom
                anchors.topMargin: 6
                anchors.bottom: consentButtons.top
                anchors.bottomMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 6
                color: StyleTokens.module
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
                        text: AIAgentsBackend.pendingConsentDetail || AIAgentsBackend.toolDetail || "Execute command"
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

            // Top Row: Agent Selector (Submenu Trigger) + Project/Branch + Action buttons
            Row {
                id: topRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24
                spacing: 6

                // Agent Selector Dropdown Trigger Button
                Rectangle {
                    id: agentSelectorBtn
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: Math.min(145, selectorContentRow.implicitWidth + 14)
                    radius: StyleTokens.radiusButton
                    color: root.agentSubmenuOpen ? StyleTokens.accent : (selectorMouse.containsMouse ? StyleTokens.buttonHover : StyleTokens.module)
                    border.width: 1
                    border.color: root.agentSubmenuOpen
                        ? StyleTokens.accent
                        : (AIAgentsBackend.isProviderRunning(AIAgentsBackend.activeProvider) ? AIAgentsBackend.providerAccentColor : StyleTokens.track)

                    Row {
                        id: selectorContentRow
                        anchors.centerIn: parent
                        spacing: 4

                        WidgetIconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: AIAgentsBackend.providerIcon
                            size: 11
                            color: root.agentSubmenuOpen ? "#ffffff" : root.stateColor()
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (AIAgentsBackend.selectedProvider === "auto" ? "Auto" : (AIAgentsBackend.selectedProvider === "claude" ? "Claude" : (AIAgentsBackend.selectedProvider === "opencode" ? "OpenCode" : "AGY")))
                                + (AIAgentsBackend.totalActiveSessions > 1 ? (" (" + AIAgentsBackend.totalActiveSessions + ")") : "")
                            role: "caption"
                            colorOverride: root.agentSubmenuOpen ? "#ffffff" : StyleTokens.textPrimary
                            widgetContext: root.widgetContext
                        }

                        WidgetIconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: root.agentSubmenuOpen ? "󰅃" : "󰅀"
                            size: 8
                            color: root.agentSubmenuOpen ? "#ffffff" : StyleTokens.textSecondary
                            widgetContext: root.widgetContext
                        }
                    }

                    MouseArea {
                        id: selectorMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.agentSubmenuOpen = !root.agentSubmenuOpen
                    }
                }

                // Project & Branch Row
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(40, parent.width - agentSelectorBtn.width - 6 - (actionsRow.width + 6))
                    spacing: 4

                    WidgetTextView {
                        text: AIAgentsBackend.projectName || AIAgentsBackend.providerDisplayName
                        role: "caption"
                        colorOverride: StyleTokens.textPrimary
                        overflowMode: "elide"
                        widgetContext: root.widgetContext
                    }
                    // Branch tag
                    Rectangle {
                        visible: AIAgentsBackend.gitBranch !== ""
                        height: 14
                        width: branchLabel.implicitWidth + 8
                        radius: 4
                        color: StyleTokens.module
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
                                text: AIAgentsBackend.gitBranch
                                role: "caption"
                                colorOverride: "#d1d5db"
                                widgetContext: root.widgetContext
                            }
                        }
                    }
                }

                // Action buttons (Minimum View Mode Toggle + Terminal + Demo Simulator)
                Row {
                    id: actionsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Minimum View Mode Toggle
                    Rectangle {
                        id: minModeBtn
                        readonly property bool showsLastMsg: UserConfig.aiAgentsMinimumShowsLastMessage || AIAgentsBackend.minimumShowsLastMessage
                        readonly property bool compact: root.width < 280

                        width: compact ? 20 : (minModeRow.implicitWidth + 12)
                        height: 20
                        radius: StyleTokens.radiusButton
                        color: minModeMouse.containsMouse
                            ? (showsLastMsg ? "#9333ea" : "#3f3f46")
                            : (showsLastMsg ? "#7e22ce" : StyleTokens.module)
                        border.width: 1
                        border.color: showsLastMsg ? "#c084fc" : StyleTokens.track

                        Behavior on color { ColorAnimation { duration: 150 } }

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
                                text: minModeBtn.showsLastMsg ? "Last Msg" : "Status"
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
                                UserConfig.setAiAgentsMinimumShowsLastMessage(next);
                                AIAgentsBackend.setMinimumShowsLastMessage(next);
                            }
                        }
                    }

                    // Demo Mode Toggle
                    Rectangle {
                        width: 20
                        height: 20
                        radius: StyleTokens.radiusButton
                        color: demoBtnMouse.containsMouse ? StyleTokens.buttonHover : StyleTokens.module
                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: "󰍉"
                            size: 10
                            color: AIAgentsBackend.demoMode ? AIAgentsBackend.providerAccentColor : "#9ca3af"
                            widgetContext: root.widgetContext
                        }
                        MouseArea {
                            id: demoBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!AIAgentsBackend.demoMode) {
                                    AIAgentsBackend.setDemoState("waiting_consent");
                                } else if (AIAgentsBackend.sessionState === "waiting_consent") {
                                    AIAgentsBackend.setDemoState("thinking");
                                } else if (AIAgentsBackend.sessionState === "thinking") {
                                    AIAgentsBackend.setDemoState("running_tool");
                                } else if (AIAgentsBackend.sessionState === "running_tool") {
                                    AIAgentsBackend.setDemoState("done");
                                } else {
                                    AIAgentsBackend.setDemoMode(false);
                                }
                            }
                        }
                    }

                    // Terminal button
                    Rectangle {
                        width: 20
                        height: 20
                        radius: StyleTokens.radiusButton
                        color: termBtnMouse.containsMouse ? StyleTokens.buttonHover : StyleTokens.module
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AIAgentsBackend.openTerminal()
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
                color: root.state === "error" ? "#221113" : StyleTokens.module
                border.width: 1
                border.color: root.state === "error" ? "#33ef4444" : StyleTokens.track
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

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - (dismissErrorBtn.visible ? 20 : 0)
                        spacing: 2

                        // Status header above the detail message
                        Row {
                            spacing: 4

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                radius: 2.5
                                color: root.stateColor()
                            }

                            WidgetTextView {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.stateText()
                                role: "caption"
                                colorOverride: root.stateColor()
                                widgetContext: root.widgetContext
                            }
                        }

                        // Detail message
                        WidgetTextView {
                            id: bannerText
                            width: parent.width
                            text: AIAgentsBackend.toolDetail || AIAgentsBackend.lastMessage || "Ready to assist"
                            role: "body"
                            overflowMode: "wrap"
                            colorOverride: root.state === "error" ? "#fca5a5" : StyleTokens.textPrimary
                            widgetContext: root.widgetContext
                        }
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
                            color: dismissMouse.containsMouse ? "#ffffff" : StyleTokens.danger
                            widgetContext: root.widgetContext
                        }

                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AIAgentsBackend.clearError()
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
                        text: Math.round(AIAgentsBackend.contextUsagePercent * 100) + "% Context"
                        role: "caption"
                        tabularFigures: true
                        colorOverride: StyleTokens.textSecondary
                        widgetContext: root.widgetContext
                    }
                    Item { width: Math.max(0, parent.width - costLabel.width - 70); height: 1 }
                    WidgetTextView {
                        id: costLabel
                        text: (AIAgentsBackend.estimatedCost > 0 ? "$" + AIAgentsBackend.estimatedCost.toFixed(2) + " · " : "") + (AIAgentsBackend.modelName || AIAgentsBackend.providerDisplayName)
                        role: "caption"
                        tabularFigures: true
                        colorOverride: StyleTokens.textSecondary
                        widgetContext: root.widgetContext
                    }
                }

                // Progress bar
                WidgetProgressBar {
                    width: parent.width
                    barHeight: 4
                    value: AIAgentsBackend.contextUsagePercent
                    fillColor: {
                        const p = AIAgentsBackend.contextUsagePercent;
                        if (p > 0.85) return StyleTokens.danger;
                        if (p > 0.65) return StyleTokens.warning;
                        return AIAgentsBackend.providerAccentColor;
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
                placeholder: "Ask " + AIAgentsBackend.providerDisplayName + "..."
                icon: "󰍉"
                showClearButton: false
                widgetContext: root.widgetContext
                onAccepted: query => {
                    if (query.trim() !== "") {
                        AIAgentsBackend.sendQuickPrompt(query.trim());
                        text = "";
                    }
                }
            }

            // Click-outside dismissal overlay
            MouseArea {
                id: submenuDismissOverlay
                anchors.fill: parent
                z: 90
                visible: root.agentSubmenuOpen
                onClicked: root.agentSubmenuOpen = false
            }

            // Agent Submenu Popover (macOS floating dropdown menu style)
            Rectangle {
                id: agentSubmenu
                z: 100
                visible: opacity > 0.01
                opacity: root.agentSubmenuOpen ? 1.0 : 0.0
                scale: root.agentSubmenuOpen ? 1.0 : 0.94
                transformOrigin: Item.TopLeft

                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                anchors.top: topRow.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                width: Math.min(parent.width, 240)
                height: Math.min(320, submenuLayout.implicitHeight + 8)
                radius: StyleTokens.radiusModule
                color: StyleTokens.panel
                border.width: 1
                border.color: StyleTokens.inputBorder
                clip: true

                function getProviderGlyph(prov) {
                    if (prov === "claude") return "󰚩";
                    if (prov === "opencode") return "󰘐";
                    if (prov === "agy") return "󰧑";
                    return "󰌨";
                }

                function getProviderColor(prov) {
                    if (prov === "claude") return "#d97706";
                    if (prov === "opencode") return "#06b6d4";
                    if (prov === "agy") return "#8b5cf6";
                    return StyleTokens.accent;
                }

                function getSessionStateColor(state) {
                    switch (state) {
                    case "waiting_consent": return "#f59e0b";
                    case "thinking": return "#818cf8";
                    case "running_tool": return "#60a5fa";
                    case "error": return "#ef4444";
                    case "done": return "#34d399";
                    case "idle": default: return StyleTokens.textDisabled;
                    }
                }

                function getSessionStateLabel(state, tool, detail) {
                    switch (state) {
                    case "waiting_consent": return "Approval needed";
                    case "thinking": return "Thinking...";
                    case "running_tool": return tool ? ("Running " + tool) : "Running tool";
                    case "error": return "Error";
                    case "done": return "Finished";
                    case "idle": default: return "Ready";
                    }
                }

                // Intercept clicks within menu
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Flickable {
                    id: submenuFlickable
                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: submenuLayout.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: submenuLayout
                        width: submenuFlickable.width
                        spacing: 3

                        Item {
                            width: parent.width
                            height: 18

                            WidgetTextView {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: "AGENTS & SESSIONS"
                                role: "caption"
                                colorOverride: StyleTokens.textTertiary
                                widgetContext: root.widgetContext
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: closeSubmenuMouse.containsMouse ? StyleTokens.buttonHover : "transparent"

                                WidgetIconGlyph {
                                    anchors.centerIn: parent
                                    glyph: "󰅖"
                                    size: 8
                                    color: StyleTokens.textSecondary
                                    widgetContext: root.widgetContext
                                }

                                MouseArea {
                                    id: closeSubmenuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.agentSubmenuOpen = false
                                }
                            }
                        }

                        // Active Sessions List
                        Column {
                            id: activeSessionsSection
                            width: parent.width
                            spacing: 2
                            visible: AIAgentsBackend.runningSessions.length > 0

                            Item {
                                width: parent.width
                                height: 16

                                WidgetTextView {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "ACTIVE SESSIONS (" + AIAgentsBackend.runningSessions.length + ")"
                                    role: "caption"
                                    colorOverride: StyleTokens.accent
                                    widgetContext: root.widgetContext
                                }
                            }

                            Repeater {
                                model: AIAgentsBackend.runningSessions

                                delegate: Rectangle {
                                    id: sessionItem
                                    readonly property bool isSelected: modelData.isSelected
                                    width: activeSessionsSection.width
                                    height: 38
                                    radius: StyleTokens.radiusButton
                                    color: sessionMouse.containsMouse
                                        ? StyleTokens.buttonHover
                                        : (sessionItem.isSelected ? StyleTokens.module : "transparent")

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: sessionItem.isSelected ? agentSubmenu.getProviderColor(modelData.provider) : StyleTokens.module

                                            WidgetIconGlyph {
                                                anchors.centerIn: parent
                                                glyph: agentSubmenu.getProviderGlyph(modelData.provider)
                                                size: 10
                                                color: sessionItem.isSelected ? "#ffffff" : agentSubmenu.getProviderColor(modelData.provider)
                                                widgetContext: root.widgetContext
                                            }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20 - 6 - (sessionItem.isSelected ? 18 : 0)
                                            spacing: 2

                                            Row {
                                                width: parent.width
                                                spacing: 4

                                                WidgetTextView {
                                                    text: modelData.projectName || modelData.title || "Agent"
                                                    role: "caption"
                                                    colorOverride: sessionItem.isSelected ? StyleTokens.accent : StyleTokens.textPrimary
                                                    overflowMode: "elide"
                                                    widgetContext: root.widgetContext
                                                }

                                                Rectangle {
                                                    visible: modelData.gitBranch !== ""
                                                    height: 12
                                                    width: sessBranchRow.implicitWidth + 6
                                                    radius: 3
                                                    color: StyleTokens.module
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Row {
                                                        id: sessBranchRow
                                                        anchors.centerIn: parent
                                                        spacing: 2

                                                        WidgetIconGlyph {
                                                            glyph: "󰘬"
                                                            size: 7
                                                            color: "#9ca3af"
                                                            widgetContext: root.widgetContext
                                                        }

                                                        WidgetTextView {
                                                            text: modelData.gitBranch
                                                            role: "caption"
                                                            colorOverride: "#d1d5db"
                                                            widgetContext: root.widgetContext
                                                        }
                                                    }
                                                }
                                            }

                                            Row {
                                                width: parent.width
                                                spacing: 3

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 5
                                                    height: 5
                                                    radius: 2.5
                                                    color: agentSubmenu.getSessionStateColor(modelData.sessionState)
                                                }

                                                WidgetTextView {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: agentSubmenu.getSessionStateLabel(modelData.sessionState, modelData.currentTool, modelData.toolDetail)
                                                    role: "caption"
                                                    colorOverride: agentSubmenu.getSessionStateColor(modelData.sessionState)
                                                    overflowMode: "elide"
                                                    widgetContext: root.widgetContext
                                                }
                                            }
                                        }

                                        WidgetIconGlyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            glyph: "󰄲"
                                            size: 11
                                            color: StyleTokens.accent
                                            visible: sessionItem.isSelected
                                            widgetContext: root.widgetContext
                                        }
                                    }

                                    MouseArea {
                                        id: sessionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            AIAgentsBackend.selectSession(modelData.provider, modelData.sessionId);
                                            root.agentSubmenuOpen = false;
                                        }
                                    }
                                }
                            }
                        }

                        // Divider between sessions and providers
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: StyleTokens.inputBorder
                            visible: AIAgentsBackend.runningSessions.length > 0
                        }

                        Item {
                            width: parent.width
                            height: 16

                            WidgetTextView {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PROVIDER PREFERENCE"
                                role: "caption"
                                colorOverride: StyleTokens.textTertiary
                                widgetContext: root.widgetContext
                            }
                        }

                        Repeater {
                            model: [
                                { id: "auto", name: "Auto-detect", desc: "Follows active agent", icon: "󰌨" },
                                { id: "claude", name: "Claude Code", desc: "Anthropic Claude", icon: "󰚩" },
                                { id: "opencode", name: "OpenCode v2", desc: "OpenCode agent", icon: "󰘐" },
                                { id: "agy", name: "Antigravity CLI", desc: "Google AGY CLI", icon: "󰧑" }
                            ]

                            delegate: Rectangle {
                                id: submenuItem
                                readonly property bool isSelected: AIAgentsBackend.selectedProvider === modelData.id
                                readonly property int sessionCount: modelData.id === "auto" ? AIAgentsBackend.totalActiveSessions : AIAgentsBackend.sessionsForProvider(modelData.id).length
                                readonly property bool isRunning: modelData.id === "auto" ? (sessionCount > 0) : AIAgentsBackend.isProviderRunning(modelData.id)
                                readonly property color brandColor: agentSubmenu.getProviderColor(modelData.id)

                                width: submenuLayout.width
                                height: 28
                                radius: StyleTokens.radiusButton
                                color: itemMouse.containsMouse
                                    ? StyleTokens.buttonHover
                                    : (submenuItem.isSelected ? StyleTokens.module : "transparent")

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: submenuItem.isSelected ? submenuItem.brandColor : StyleTokens.module

                                        WidgetIconGlyph {
                                            anchors.centerIn: parent
                                            glyph: modelData.icon
                                            size: 10
                                            color: submenuItem.isSelected ? "#ffffff" : submenuItem.brandColor
                                            widgetContext: root.widgetContext
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 18 - 6 - 20
                                        spacing: 0

                                        WidgetTextView {
                                            text: modelData.name
                                            role: "caption"
                                            colorOverride: submenuItem.isSelected ? StyleTokens.textPrimary : StyleTokens.textSecondary
                                            widgetContext: root.widgetContext
                                        }

                                        Row {
                                            spacing: 3

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: submenuItem.isRunning ? StyleTokens.success : StyleTokens.textDisabled
                                            }

                                            WidgetTextView {
                                                text: submenuItem.sessionCount > 0
                                                    ? (submenuItem.sessionCount + (submenuItem.sessionCount === 1 ? " session" : " sessions"))
                                                    : (submenuItem.isRunning ? "Running" : "Idle")
                                                role: "caption"
                                                colorOverride: submenuItem.isRunning ? StyleTokens.success : StyleTokens.textDisabled
                                                widgetContext: root.widgetContext
                                            }
                                        }
                                    }

                                    WidgetIconGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        glyph: "󰄲"
                                        size: 11
                                        color: StyleTokens.accent
                                        visible: submenuItem.isSelected
                                        widgetContext: root.widgetContext
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        AIAgentsBackend.setSelectedProvider(modelData.id);
                                        root.agentSubmenuOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
