import QtQuick
import QtQuick.Controls
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
        anchors.margins: 6

        // -------------------------------------------------------------
        // CONSENT OVERLAY (Takes precedence when approval is needed)
        // -------------------------------------------------------------
            Column {
                id: consentView
                anchors.fill: parent
                spacing: 6
                visible: root.isWaitingConsent

                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: "#33f59e0b"
                        Text {
                            anchors.centerIn: parent
                            text: "󰀦"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#f59e0b"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        Text {
                            text: "Action Permission"
                            font.family: root.textFontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                        Text {
                            text: "Tool: " + (ClaudeCodeBackend.pendingConsentTool || ClaudeCodeBackend.currentTool || "Action")
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: "#d1d5db"
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                // Monospace detail box
                Rectangle {
                    width: parent.width
                    height: Math.max(30, parent.height - 68)
                    radius: 6
                    color: "#0f0f12"
                    border.width: 1
                    border.color: "#26ffffff"
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentWidth: detailText.width
                        contentHeight: detailText.height
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: detailText
                            text: ClaudeCodeBackend.pendingConsentDetail || ClaudeCodeBackend.toolDetail || "Execute command"
                            font.family: "Monospace"
                            font.pixelSize: 10
                            color: "#93c5fd"
                            wrapMode: Text.WrapAnywhere
                            width: parent.width - 4
                        }
                    }
                }

                // Button row: Allow / Always / Deny
                Row {
                    width: parent.width
                    height: 24
                    spacing: 6

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: parent.height
                        radius: 6
                        color: allowMouse.pressed ? "#059669" : (allowMouse.containsMouse ? "#10b981" : "#1a10b981")
                        border.width: 1
                        border.color: "#34d399"

                        Text {
                            anchors.centerIn: parent
                            text: "Allow"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                        MouseArea {
                            id: allowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ClaudeCodeBackend.allowConsent(false)
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: parent.height
                        radius: 6
                        color: alwaysMouse.pressed ? "#2563eb" : (alwaysMouse.containsMouse ? "#3b82f6" : "#1a3b82f6")
                        border.width: 1
                        border.color: "#60a5fa"

                        Text {
                            anchors.centerIn: parent
                            text: "Always"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                        MouseArea {
                            id: alwaysMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ClaudeCodeBackend.allowConsent(true)
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: parent.height
                        radius: 6
                        color: denyMouse.pressed ? "#dc2626" : (denyMouse.containsMouse ? "#ef4444" : "#1aef4444")
                        border.width: 1
                        border.color: "#f87171"

                        Text {
                            anchors.centerIn: parent
                            text: "Deny"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                        MouseArea {
                            id: denyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ClaudeCodeBackend.denyConsent()
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // STANDARD MONITORING VIEW (Single-slot or Multi-slot)
            // -------------------------------------------------------------
            Column {
                id: standardView
                anchors.fill: parent
                spacing: 6
                visible: !root.isWaitingConsent

                // Top row: Avatar/Status + Project/Branch + Action buttons
                Row {
                    width: parent.width
                    height: 24
                    spacing: 6

                    // Status dot & Icon
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#27272a"

                        Text {
                            anchors.centerIn: parent
                            text: "󰚩"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: root.stateColor()
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
                            Text {
                                text: ClaudeCodeBackend.projectName || "Claude Code"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: "white"
                                elide: Text.ElideRight
                                maximumLineCount: 1
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
                                    Text {
                                        text: "󰘬"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 8
                                        color: "#9ca3af"
                                    }
                                    Text {
                                        text: ClaudeCodeBackend.gitBranch
                                        font.family: root.textFontFamily
                                        font.pixelSize: 9
                                        color: "#d1d5db"
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.stateText() + (ClaudeCodeBackend.currentTool ? " (" + ClaudeCodeBackend.currentTool + ")" : "")
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: root.stateColor()
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Action buttons (Terminal + Demo Simulator)
                    Row {
                        id: actionsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Demo Mode Toggle (lets user preview states without running Claude)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: demoBtnMouse.containsMouse ? "#3f3f46" : "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "󰍉"
                                font.family: root.iconFontFamily
                                font.pixelSize: 10
                                color: ClaudeCodeBackend.demoMode ? "#a855f7" : "#9ca3af"
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
                            radius: 10
                            color: termBtnMouse.containsMouse ? "#3f3f46" : "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "󰆍"
                                font.family: root.iconFontFamily
                                font.pixelSize: 10
                                color: "#e4e4e7"
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
                    width: parent.width
                    height: 28
                    radius: 6
                    color: root.state === "error" ? "#221113" : "#111113"
                    border.width: 1
                    border.color: root.state === "error" ? "#33ef4444" : "#1affffff"
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.state === "thinking") ? "󰑣" : ((root.state === "running_tool") ? "󰞷" : ((root.state === "error") ? "󰅚" : "󰋼"))
                            font.family: root.iconFontFamily
                            font.pixelSize: 11
                            color: root.stateColor()

                            RotationAnimation on rotation {
                                running: root.state === "thinking"
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - (dismissErrorBtn.visible ? 20 : 0)
                            text: ClaudeCodeBackend.toolDetail || ClaudeCodeBackend.lastMessage || "Ready to assist"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: root.state === "error" ? "#fca5a5" : "#e4e4e7"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Item {
                            id: dismissErrorBtn
                            visible: root.state === "error"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: root.iconFontFamily
                                font.pixelSize: 10
                                color: dismissMouse.containsMouse ? "#ffffff" : "#ef4444"
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
                    width: parent.width
                    spacing: 3

                    Row {
                        width: parent.width
                        Text {
                            text: Math.round(ClaudeCodeBackend.contextUsagePercent * 100) + "% Context"
                            font.family: root.textFontFamily
                            font.pixelSize: 9
                            color: "#9ca3af"
                        }
                        Item { width: parent.width - costLabel.implicitWidth - 70; height: 1 }
                        Text {
                            id: costLabel
                            text: "$" + ClaudeCodeBackend.estimatedCost.toFixed(2) + " · " + (ClaudeCodeBackend.modelName || "Claude")
                            font.family: root.textFontFamily
                            font.pixelSize: 9
                            color: "#9ca3af"
                        }
                    }

                    // Progress bar
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: "#27272a"

                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: Math.max(4, parent.width * Math.min(1.0, Math.max(0.0, ClaudeCodeBackend.contextUsagePercent)))
                            color: {
                                const p = ClaudeCodeBackend.contextUsagePercent;
                                if (p > 0.85) return "#ef4444";
                                if (p > 0.65) return "#f59e0b";
                                return "#a855f7";
                            }
                        }
                    }
                }

                // Bottom: Quick Prompt Bar
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 13
                    color: "#27272a"
                    border.width: 1
                    border.color: promptInput.activeFocus ? "#a855f7" : "#1affffff"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.family: root.iconFontFamily
                            font.pixelSize: 11
                            color: "#9ca3af"
                        }

                        TextInput {
                            id: promptInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: "white"
                            clip: true
                            onAccepted: {
                                if (text.trim() !== "") {
                                    ClaudeCodeBackend.sendQuickPrompt(text.trim());
                                    text = "";
                                }
                            }

                            Text {
                                text: "Ask Claude Code..."
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#71717a"
                                visible: !promptInput.text && !promptInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: sendMouse.containsMouse ? "#a855f7" : "#3f3f46"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: root.iconFontFamily
                                font.pixelSize: 9
                                color: "white"
                            }
                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (promptInput.text.trim() !== "") {
                                        ClaudeCodeBackend.sendQuickPrompt(promptInput.text.trim());
                                        promptInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
