import QtQuick
import QtQuick.Controls
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 2
    property bool isEditMode: false

    readonly property string iconFontFamily: (widgetContext && widgetContext.iconFontFamily !== undefined) ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: (widgetContext && widgetContext.textFontFamily !== undefined) ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: (widgetContext && widgetContext.bodyFontSize !== undefined) ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: (widgetContext && widgetContext.titleFontSize !== undefined) ? widgetContext.titleFontSize : 20
    readonly property int iconFontSize: (widgetContext && widgetContext.iconFontSize !== undefined) ? widgetContext.iconFontSize : 18

    readonly property bool connected: PomotroidBackend.connected
    readonly property bool isRunning: PomotroidBackend.running
    readonly property bool isPaused: PomotroidBackend.paused
    readonly property string roundType: PomotroidBackend.roundType
    readonly property int elapsedSeconds: PomotroidBackend.elapsedSeconds
    readonly property int totalSeconds: PomotroidBackend.totalSeconds
    readonly property int remainingSeconds: PomotroidBackend.remainingSeconds
    readonly property double progress: PomotroidBackend.progress
    readonly property int roundNumber: PomotroidBackend.roundNumber
    readonly property int roundsTotal: PomotroidBackend.roundsTotal
    readonly property int sessionWorkCount: PomotroidBackend.sessionWorkCount
    readonly property int goalRounds: PomotroidBackend.goalRounds

    readonly property bool isWork: roundType === "work"
    readonly property bool isLongBreak: roundType === "long-break"
    readonly property bool isShortBreak: roundType === "short-break" || (!isWork && !isLongBreak)

    readonly property color themeColor: isWork ? StyleTokens.danger : (isLongBreak ? StyleTokens.accent : StyleTokens.success)
    readonly property color themeColorBg: Qt.rgba(themeColor.r, themeColor.g, themeColor.b, 0.15)
    readonly property string roundLabel: isWork ? "Focus" : (isLongBreak ? "Long Break" : "Short Break")

    // Local tag inputs bound to backend state
    property string currentSubject: PomotroidBackend.subject
    property string currentTopic: PomotroidBackend.subjectTopic
    property string currentStudyType: PomotroidBackend.studyType
    property string currentNotes: PomotroidBackend.notes

    // Active autocomplete dropdown ("" | "subject" | "topic" | "type")
    property string activeDropdown: ""
    property string lastActiveDropdown: ""
    onActiveDropdownChanged: {
        if (activeDropdown !== "") {
            lastActiveDropdown = activeDropdown;
        }
    }

    // Visual save confirmation indicator
    property bool showSavedIndicator: false
    Timer {
        id: savedTimer
        interval: 1500
        repeat: false
        onTriggered: root.showSavedIndicator = false
    }

    Connections {
        target: PomotroidBackend
        function onTagsChanged() {
            root.currentSubject = PomotroidBackend.subject;
            root.currentTopic = PomotroidBackend.subjectTopic;
            root.currentStudyType = PomotroidBackend.studyType;
            root.currentNotes = PomotroidBackend.notes;
        }
    }

    function commitTags() {
        PomotroidBackend.setTags(
            root.currentSubject.trim(),
            root.currentTopic.trim(),
            root.currentStudyType.trim(),
            root.currentNotes.trim()
        );
        root.showSavedIndicator = true;
        savedTimer.restart();
    }

    // Single-slot view mode: 0 = Timer controls, 1 = Tags & metadata
    property int singleSlotTab: 0

    readonly property bool isWide: width >= 340

    anchors.fill: parent

    // Dismiss any open dropdown when clicking background
    MouseArea {
        anchors.fill: parent
        z: 25
        visible: root.activeDropdown !== ""
        onClicked: root.activeDropdown = ""
    }

    // -------------------------------------------------------------
    // OFFLINE BANNER (shown when Pomotroid is not running)
    // -------------------------------------------------------------
    Item {
        id: offlineView
        anchors.fill: parent
        anchors.margins: 4
        visible: !root.connected

        Column {
            anchors.centerIn: parent
            spacing: 6

            WidgetIconGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                glyph: "󰄉"
                size: root.isWide ? 26 : 20
                color: StyleTokens.danger
                widgetContext: root.widgetContext
            }

            WidgetTextView {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pomotroid Offline"
                role: root.isWide ? "title" : "body"
                colorOverride: StyleTokens.textPrimary
                widgetContext: root.widgetContext
            }

            WidgetTextView {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Launch Pomotroid to start tracking sessions"
                role: "caption"
                colorOverride: StyleTokens.textSecondary
                visible: root.isWide
                widgetContext: root.widgetContext
            }

            Item { width: 1; height: 2 }

            WidgetActionButton {
                anchors.horizontalCenter: parent.horizontalCenter
                variant: "capsule"
                buttonStyle: "danger"
                icon: "󰐊"
                label: root.isWide ? "Launch Pomotroid" : "Launch"
                widgetContext: root.widgetContext
                onClicked: PomotroidBackend.launchPomotroid()
            }
        }
    }

    // -------------------------------------------------------------
    // MAIN CONNECTED VIEW
    // -------------------------------------------------------------
    Item {
        id: connectedView
        anchors.fill: parent
        anchors.margins: 4
        visible: root.connected

        // ═══════════════════════════════════════════════════════════
        // WIDE LAYOUT (width >= 340)
        // ═══════════════════════════════════════════════════════════
        Item {
            id: wideView
            anchors.fill: parent
            visible: root.isWide

            // --- RIGHT COLUMN: Session Tags & Autocompletion (decreased width) ---
            Item {
                id: rightCol
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: Math.min(200, Math.max(140, Math.round(parent.width * 0.35)))

                // Title bar for tags (macOS minimalist section header)
                Item {
                    id: tagTitleBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        WidgetIconGlyph {
                            glyph: "󰓹"
                            size: 10
                            color: StyleTokens.textTertiary
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            text: "SESSION TAGS"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }
                    }

                    // Saved indicator badge
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: root.showSavedIndicator

                        WidgetIconGlyph {
                            glyph: "󰄲"
                            size: 9
                            color: StyleTokens.success
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            text: "Saved"
                            role: "caption"
                            colorOverride: StyleTokens.success
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }
                    }
                }

                // Reusable Tag Editor (fills 100% of remaining vertical space)
                Item {
                    id: tagEditorContainer
                    anchors.top: tagTitleBar.bottom
                    anchors.topMargin: 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Loader {
                        anchors.fill: parent
                        active: root.isWide
                        sourceComponent: tagFieldsComponent
                    }
                }
            }

            // Vertical divider
            Rectangle {
                id: colDivider
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                anchors.right: rightCol.left
                anchors.rightMargin: 8
                width: 1
                color: StyleTokens.track
            }

            // --- LEFT COLUMN: Timer & Controls (majority width) ---
            Item {
                id: leftCol
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: colDivider.left
                anchors.rightMargin: 8

                Column {
                    anchors.fill: parent
                    spacing: 4

                    // Top header: Goal Stepper & Window Buttons
                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // Goal Stepper: Decrement (-), Number of Rounds, Increment (+)
                            Row {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                // Decrement (-) button
                                WidgetActionButton {
                                    width: 20
                                    height: 20
                                    variant: "icon"
                                    buttonStyle: "secondary"
                                    icon: "-"
                                    enabled: root.goalRounds > 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                    onClicked: PomotroidBackend.setGoalRounds(Math.max(1, root.goalRounds - 1))
                                }

                                // Number of rounds between increase and decrease buttons
                                WidgetTextView {
                                    text: (root.isWork ? Math.max(0, root.sessionWorkCount - 1) : root.sessionWorkCount) + "/" + root.goalRounds
                                    role: "caption"
                                    tabularFigures: true
                                    colorOverride: StyleTokens.textPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                }

                                // Increment (+) button
                                WidgetActionButton {
                                    width: 20
                                    height: 20
                                    variant: "icon"
                                    buttonStyle: "secondary"
                                    icon: "+"
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                    onClicked: PomotroidBackend.setGoalRounds(root.goalRounds + 1)
                                }
                            }
                        }

                        // Right: Window actions
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            WidgetActionButton {
                                width: 20
                                height: 20
                                variant: "icon"
                                buttonStyle: "ghost"
                                icon: "󰄫"
                                widgetContext: root.widgetContext
                                onClicked: PomotroidBackend.openStatsWindow()
                            }

                            WidgetActionButton {
                                width: 20
                                height: 20
                                variant: "icon"
                                buttonStyle: "ghost"
                                icon: "󰖰"
                                widgetContext: root.widgetContext
                                onClicked: PomotroidBackend.openMainWindow()
                            }
                        }
                    }

                    // Center: Countdown clock centered in the pomodoro side
                    Item {
                        width: parent.width
                        height: parent.height - 24 - 30 - 8

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            WidgetTextView {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: PomotroidBackend.formatTime(root.remainingSeconds)
                                role: "hero"
                                horizontalAlignment: Text.AlignHCenter
                                tabularFigures: true
                                colorOverride: StyleTokens.textPrimary
                                widgetContext: root.widgetContext
                            }

                            WidgetTextView {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.isRunning ? "RUNNING" : (root.isPaused ? "PAUSED" : "IDLE")
                                role: "caption"
                                horizontalAlignment: Text.AlignHCenter
                                colorOverride: root.isRunning ? root.themeColor : StyleTokens.textTertiary
                                widgetContext: root.widgetContext
                            }
                        }
                    }

                    // Bottom: Control Buttons (Start button centered with the timer)
                    Item {
                        width: parent.width
                        height: 30

                        // Previous / Restart button (opposite of skip button)
                        WidgetActionButton {
                            id: prevBtn
                            anchors.right: playPauseBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰒮"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.restartRound()
                        }

                        // Play / Pause / Resume (Start button centered with timer)
                        WidgetActionButton {
                            id: playPauseBtn
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(120, Math.max(72, Math.round(parent.width * 0.28)))
                            height: 28
                            variant: "capsule"
                            buttonStyle: root.isWork ? "danger" : "primary"
                            icon: root.isRunning ? "󰏤" : "󰐊"
                            label: root.isRunning ? "Pause" : (root.isPaused ? "Resume" : "Start")
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.toggleTimer()
                        }

                        // Controls to the right of Start button (Next, Reset, Round Badge)
                        Row {
                            anchors.left: playPauseBtn.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Next / Skip button
                            WidgetActionButton {
                                width: 28
                                height: 28
                                variant: "icon"
                                buttonStyle: "secondary"
                                icon: "󰒭"
                                widgetContext: root.widgetContext
                                onClicked: PomotroidBackend.skipRound()
                            }

                            // Reset button (same secondary style as previous & skip)
                            WidgetActionButton {
                                width: 28
                                height: 28
                                variant: "icon"
                                buttonStyle: "secondary"
                                icon: "󰦛"
                                widgetContext: root.widgetContext
                                onClicked: PomotroidBackend.resetTimer()
                            }

                            // Current Round Badge (moved to the right side of the buttons)
                            Rectangle {
                                height: 22
                                width: roundBadgeRow.implicitWidth + 12
                                radius: 11
                                color: root.themeColorBg
                                border.width: 1
                                border.color: root.themeColor
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    id: roundBadgeRow
                                    anchors.centerIn: parent

                                    WidgetTextView {
                                        text: root.roundNumber + "/" + root.roundsTotal
                                        role: "caption"
                                        tabularFigures: true
                                        colorOverride: root.themeColor
                                        widgetContext: root.widgetContext
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // COMPACT / 1-SLOT LAYOUT (width < 340)
        // ═══════════════════════════════════════════════════════════
        Column {
            anchors.fill: parent
            spacing: 5
            visible: !root.isWide

            // Top Header: Round Badge + Tab switch (Timer / Tags) + Actions
            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Round Badge
                    Rectangle {
                        height: 20
                        width: compactBadgeRow.implicitWidth + 8
                        radius: 10
                        color: root.themeColorBg
                        border.width: 1
                        border.color: root.themeColor

                        Row {
                            id: compactBadgeRow
                            anchors.centerIn: parent

                            WidgetTextView {
                                text: root.roundNumber + "/" + root.roundsTotal
                                role: "caption"
                                tabularFigures: true
                                colorOverride: root.themeColor
                                widgetContext: root.widgetContext
                            }
                        }
                    }

                    // Tab Switcher Pills: Timer | Tags
                    Row {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        WidgetActionButton {
                            variant: "pill"
                            label: "Timer"
                            buttonStyle: root.singleSlotTab === 0 ? "primary" : "ghost"
                            widgetContext: root.widgetContext
                            onClicked: root.singleSlotTab = 0
                        }

                        WidgetActionButton {
                            variant: "pill"
                            label: "Tags"
                            buttonStyle: root.singleSlotTab === 1 ? "primary" : "ghost"
                            widgetContext: root.widgetContext
                            onClicked: root.singleSlotTab = 1
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    WidgetActionButton {
                        width: 20
                        height: 20
                        variant: "icon"
                        buttonStyle: "ghost"
                        icon: "󰄫"
                        widgetContext: root.widgetContext
                        onClicked: PomotroidBackend.openStatsWindow()
                    }

                    WidgetActionButton {
                        width: 20
                        height: 20
                        variant: "icon"
                        buttonStyle: "ghost"
                        icon: "󰖰"
                        widgetContext: root.widgetContext
                        onClicked: PomotroidBackend.openMainWindow()
                    }
                }
            }

            // Tab 0: Timer & Controls
            Item {
                width: parent.width
                height: parent.height - 29
                visible: root.singleSlotTab === 0

                Column {
                    anchors.fill: parent
                    spacing: 5

                    // Center countdown & subject label
                    Column {
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        WidgetTextView {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: PomotroidBackend.formatTime(root.remainingSeconds)
                            role: "hero"
                            tabularFigures: true
                            horizontalAlignment: Text.AlignHCenter
                            colorOverride: StyleTokens.textPrimary
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentSubject ? (root.currentSubject + (root.currentTopic ? " • " + root.currentTopic : "")) : (root.isRunning ? "RUNNING" : "IDLE")
                            role: "caption"
                            colorOverride: root.currentSubject ? StyleTokens.textSecondary : StyleTokens.textTertiary
                            overflowMode: "elide"
                            width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            widgetContext: root.widgetContext
                        }
                    }

                    // Standard Progress bar
                    WidgetProgressBar {
                        width: parent.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: 1.0 - root.progress
                        fillColor: root.themeColor
                        trackColor: StyleTokens.track
                        barHeight: 4
                    }

                    // Standard Buttons Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        // Previous / Restart button (opposite of skip)
                        WidgetActionButton {
                            width: 28
                            height: 26
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰒮"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.restartRound()
                        }

                        WidgetActionButton {
                            width: Math.max(46, parent.width - 28 * 3 - 4 * 3 - 8)
                            height: 26
                            variant: "capsule"
                            buttonStyle: root.isWork ? "danger" : "primary"
                            icon: root.isRunning ? "󰏤" : "󰐊"
                            label: root.isRunning ? "Pause" : (root.isPaused ? "Resume" : "Start")
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.toggleTimer()
                        }

                        // Next / Skip button
                        WidgetActionButton {
                            width: 28
                            height: 26
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰒭"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.skipRound()
                        }

                        // Reset button (same secondary style as previous & skip)
                        WidgetActionButton {
                            width: 28
                            height: 26
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰦛"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.resetTimer()
                        }
                    }
                }
            }

            // Tab 1: Tags & Autocompletion in single slot
            Item {
                width: parent.width
                height: parent.height - 29
                visible: root.singleSlotTab === 1

                // Title bar with saved feedback
                Item {
                    id: compactTagTitleBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        WidgetIconGlyph {
                            glyph: "󰓹"
                            size: 10
                            color: StyleTokens.textTertiary
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            text: "SESSION TAGS"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }
                    }

                    // Saved indicator badge
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: root.showSavedIndicator

                        WidgetIconGlyph {
                            glyph: "󰄲"
                            size: 9
                            color: StyleTokens.success
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            text: "Saved"
                            role: "caption"
                            colorOverride: StyleTokens.success
                            anchors.verticalCenter: parent.verticalCenter
                            widgetContext: root.widgetContext
                        }
                    }
                }

                // Tag editor filling remaining vertical space
                Item {
                    anchors.top: compactTagTitleBar.bottom
                    anchors.topMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Loader {
                        anchors.fill: parent
                        active: !root.isWide && root.singleSlotTab === 1
                        sourceComponent: tagFieldsComponent
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------
    // REUSABLE TAG FIELDS & AUTOCOMPLETE OVERLAY
    // -------------------------------------------------------------
    Component {
        id: tagFieldsComponent

        Item {
            id: tagFieldsRoot
            anchors.fill: parent

            // Dynamic equal vertical distribution to fill 100% of available height
            readonly property int rowCount: 4
            readonly property real rowSpacing: Math.max(4, Math.min(8, Math.floor(height * 0.045)))
            readonly property real rowHeight: Math.max(22, (height - (rowCount - 1) * rowSpacing) / rowCount)

            Column {
                anchors.fill: parent
                spacing: tagFieldsRoot.rowSpacing

                // --- Row 1: Subject ---
                Item {
                    id: subRow
                    width: parent.width
                    height: tagFieldsRoot.rowHeight

                    // Persistent soft translucent background + focus feedback
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: subInput.activeFocus ? StyleTokens.moduleHover : Qt.rgba(1, 1, 1, 0.05)
                        border.width: subInput.activeFocus ? 1 : 0
                        border.color: root.themeColor
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: subMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: subInput.forceActiveFocus()
                    }

                    WidgetIconGlyph {
                        id: subIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰑴"
                        size: 11
                        color: subInput.activeFocus ? root.themeColor : (root.currentSubject ? StyleTokens.textSecondary : StyleTokens.textTertiary)
                        widgetContext: root.widgetContext
                    }

                    Rectangle {
                        id: subActionBtn
                        width: 18
                        height: 18
                        radius: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: subActionMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                        readonly property bool showClear: root.currentSubject.length > 0 && subMouse.containsMouse && root.activeDropdown !== "subject"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: subActionBtn.showClear ? "󰅖" : "󰅀"
                            size: 8
                            color: subActionMouse.containsMouse ? StyleTokens.textOnButtonFill : (root.activeDropdown === "subject" ? root.themeColor : StyleTokens.textTertiary)
                            widgetContext: root.widgetContext
                        }

                        MouseArea {
                            id: subActionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (subActionBtn.showClear) {
                                    root.currentSubject = "";
                                    root.commitTags();
                                } else {
                                    root.activeDropdown = (root.activeDropdown === "subject" ? "" : "subject");
                                }
                            }
                        }
                    }

                    TextInput {
                        id: subInput
                        anchors.left: subIcon.right
                        anchors.leftMargin: 6
                        anchors.right: subActionBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentSubject
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: StyleTokens.textPrimary
                        selectionColor: StyleTokens.accentSoft
                        selectedTextColor: StyleTokens.textPrimary
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: {
                            root.currentSubject = text;
                            if (activeFocus) {
                                PomotroidBackend.fetchTopicsForSubject(text.trim());
                            }
                        }
                        onEditingFinished: root.commitTags()
                        Keys.onReturnPressed: { root.commitTags(); focus = false; }
                        Keys.onEnterPressed: { root.commitTags(); focus = false; }
                        Keys.onEscapePressed: { focus = false; }

                        WidgetTextView {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Subject"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            visible: !subInput.text && !subInput.activeFocus
                            overflowMode: "elide"
                            widgetContext: root.widgetContext
                        }
                    }
                }

                // --- Row 2: Topic ---
                Item {
                    id: topRow
                    width: parent.width
                    height: tagFieldsRoot.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: topInput.activeFocus ? StyleTokens.moduleHover : Qt.rgba(1, 1, 1, 0.05)
                        border.width: topInput.activeFocus ? 1 : 0
                        border.color: root.themeColor
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: topMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: topInput.forceActiveFocus()
                    }

                    WidgetIconGlyph {
                        id: topIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰅍"
                        size: 11
                        color: topInput.activeFocus ? root.themeColor : (root.currentTopic ? StyleTokens.textSecondary : StyleTokens.textTertiary)
                        widgetContext: root.widgetContext
                    }

                    Rectangle {
                        id: topActionBtn
                        width: 18
                        height: 18
                        radius: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: topActionMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                        readonly property bool showClear: root.currentTopic.length > 0 && topMouse.containsMouse && root.activeDropdown !== "topic"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: topActionBtn.showClear ? "󰅖" : "󰅀"
                            size: 8
                            color: topActionMouse.containsMouse ? StyleTokens.textOnButtonFill : (root.activeDropdown === "topic" ? root.themeColor : StyleTokens.textTertiary)
                            widgetContext: root.widgetContext
                        }

                        MouseArea {
                            id: topActionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (topActionBtn.showClear) {
                                    root.currentTopic = "";
                                    root.commitTags();
                                } else {
                                    root.activeDropdown = (root.activeDropdown === "topic" ? "" : "topic");
                                }
                            }
                        }
                    }

                    TextInput {
                        id: topInput
                        anchors.left: topIcon.right
                        anchors.leftMargin: 6
                        anchors.right: topActionBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentTopic
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: StyleTokens.textPrimary
                        selectionColor: StyleTokens.accentSoft
                        selectedTextColor: StyleTokens.textPrimary
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.currentTopic = text
                        onEditingFinished: root.commitTags()
                        Keys.onReturnPressed: { root.commitTags(); focus = false; }
                        Keys.onEnterPressed: { root.commitTags(); focus = false; }
                        Keys.onEscapePressed: { focus = false; }

                        WidgetTextView {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Topic"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            visible: !topInput.text && !topInput.activeFocus
                            overflowMode: "elide"
                            widgetContext: root.widgetContext
                        }
                    }
                }

                // --- Row 3: Study Type ---
                Item {
                    id: typRow
                    width: parent.width
                    height: tagFieldsRoot.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: typInput.activeFocus ? StyleTokens.moduleHover : Qt.rgba(1, 1, 1, 0.05)
                        border.width: typInput.activeFocus ? 1 : 0
                        border.color: root.themeColor
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: typMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: typInput.forceActiveFocus()
                    }

                    WidgetIconGlyph {
                        id: typIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰑤"
                        size: 11
                        color: typInput.activeFocus ? root.themeColor : (root.currentStudyType ? StyleTokens.textSecondary : StyleTokens.textTertiary)
                        widgetContext: root.widgetContext
                    }

                    Rectangle {
                        id: typActionBtn
                        width: 18
                        height: 18
                        radius: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: typActionMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                        readonly property bool showClear: root.currentStudyType.length > 0 && typMouse.containsMouse && root.activeDropdown !== "type"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: typActionBtn.showClear ? "󰅖" : "󰅀"
                            size: 8
                            color: typActionMouse.containsMouse ? StyleTokens.textOnButtonFill : (root.activeDropdown === "type" ? root.themeColor : StyleTokens.textTertiary)
                            widgetContext: root.widgetContext
                        }

                        MouseArea {
                            id: typActionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typActionBtn.showClear) {
                                    root.currentStudyType = "";
                                    root.commitTags();
                                } else {
                                    root.activeDropdown = (root.activeDropdown === "type" ? "" : "type");
                                }
                            }
                        }
                    }

                    TextInput {
                        id: typInput
                        anchors.left: typIcon.right
                        anchors.leftMargin: 6
                        anchors.right: typActionBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentStudyType
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: StyleTokens.textPrimary
                        selectionColor: StyleTokens.accentSoft
                        selectedTextColor: StyleTokens.textPrimary
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.currentStudyType = text
                        onEditingFinished: root.commitTags()
                        Keys.onReturnPressed: { root.commitTags(); focus = false; }
                        Keys.onEnterPressed: { root.commitTags(); focus = false; }
                        Keys.onEscapePressed: { focus = false; }

                        WidgetTextView {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Type"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            visible: !typInput.text && !typInput.activeFocus
                            overflowMode: "elide"
                            widgetContext: root.widgetContext
                        }
                    }
                }

                // --- Row 4: Notes ---
                Item {
                    id: notRow
                    width: parent.width
                    height: tagFieldsRoot.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: notInput.activeFocus ? StyleTokens.moduleHover : Qt.rgba(1, 1, 1, 0.05)
                        border.width: notInput.activeFocus ? 1 : 0
                        border.color: root.themeColor
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: notMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notInput.forceActiveFocus()
                    }

                    WidgetIconGlyph {
                        id: notIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰎞"
                        size: 11
                        color: notInput.activeFocus ? root.themeColor : (root.currentNotes ? StyleTokens.textSecondary : StyleTokens.textTertiary)
                        widgetContext: root.widgetContext
                    }

                    Rectangle {
                        id: notActionBtn
                        width: 18
                        height: 18
                        radius: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.currentNotes.length > 0 && notMouse.containsMouse
                        color: notActionMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: "󰅖"
                            size: 8
                            color: notActionMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textTertiary
                            widgetContext: root.widgetContext
                        }

                        MouseArea {
                            id: notActionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentNotes = "";
                                root.commitTags();
                            }
                        }
                    }

                    TextInput {
                        id: notInput
                        anchors.left: notIcon.right
                        anchors.leftMargin: 6
                        anchors.right: notActionBtn.visible ? notActionBtn.left : parent.right
                        anchors.rightMargin: notActionBtn.visible ? 4 : 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentNotes
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: StyleTokens.textPrimary
                        selectionColor: StyleTokens.accentSoft
                        selectedTextColor: StyleTokens.textPrimary
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.currentNotes = text
                        onEditingFinished: root.commitTags()
                        Keys.onReturnPressed: { root.commitTags(); focus = false; }
                        Keys.onEnterPressed: { root.commitTags(); focus = false; }
                        Keys.onEscapePressed: { focus = false; }

                        WidgetTextView {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Add note..."
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            visible: !notInput.text && !notInput.activeFocus
                            overflowMode: "elide"
                            widgetContext: root.widgetContext
                        }
                    }
                }
            }

            // Outside-click dismissal for the overlay inside the tags column
            MouseArea {
                anchors.fill: parent
                z: 30
                visible: root.activeDropdown !== ""
                onClicked: root.activeDropdown = ""
            }

            // Dropdown Suggestion Popover (macOS floating menu style)
            Rectangle {
                id: dropdownOverlay
                anchors.fill: parent
                anchors.margins: 1
                z: 50
                readonly property bool isOpen: root.activeDropdown !== ""
                readonly property string displaySection: root.activeDropdown !== "" ? root.activeDropdown : root.lastActiveDropdown

                visible: opacity > 0.001
                opacity: isOpen ? 1.0 : 0.0
                scale: isOpen ? 1.0 : 0.95
                transformOrigin: Item.Top
                radius: 8
                color: StyleTokens.module
                border.width: 1
                border.color: StyleTokens.inputBorder
                clip: true

                transform: Translate {
                    y: dropdownOverlay.isOpen ? 0 : -6
                    Behavior on y {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Prevent click-through into tag fields while menu is open
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 3

                    // Popover Header
                    Item {
                        width: parent.width
                        height: 20

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            WidgetIconGlyph {
                                glyph: dropdownOverlay.displaySection === "subject" ? "󰑴" : (dropdownOverlay.displaySection === "topic" ? "󰅍" : "󰑤")
                                size: 10
                                color: root.themeColor
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }

                            WidgetTextView {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dropdownOverlay.displaySection === "subject" ? "SUBJECTS" : (dropdownOverlay.displaySection === "topic" ? "TOPICS" : "STUDY TYPES")
                                role: "caption"
                                colorOverride: StyleTokens.textSecondary
                                widgetContext: root.widgetContext
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: closeMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰅖"
                                size: 9
                                color: closeMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textTertiary
                                widgetContext: root.widgetContext
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeDropdown = ""
                            }
                        }
                    }

                    // Hairline separator under popover header
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Suggestions ListView
                    ListView {
                        id: suggestionList
                        width: parent.width
                        height: Math.max(0, parent.height - 28)
                        clip: true
                        spacing: 2
                        model: {
                            if (dropdownOverlay.displaySection === "subject") return PomotroidBackend.cachedSubjects;
                            if (dropdownOverlay.displaySection === "topic") return PomotroidBackend.cachedTopics;
                            if (dropdownOverlay.displaySection === "type") return PomotroidBackend.cachedStudyTypes;
                            return [];
                        }
                        delegate: Rectangle {
                            width: suggestionList.width
                            height: 22
                            radius: 5
                            color: itemMouse.containsMouse ? StyleTokens.buttonFillHover : StyleTokens.transparent

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                WidgetIconGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "󰄲"
                                    size: 9
                                    color: itemMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textTertiary
                                    widgetContext: root.widgetContext
                                }

                                WidgetTextView {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    role: "caption"
                                    colorOverride: itemMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dropdownOverlay.displaySection === "subject") {
                                        root.currentSubject = modelData;
                                        PomotroidBackend.fetchTopicsForSubject(modelData);
                                    } else if (dropdownOverlay.displaySection === "topic") {
                                        root.currentTopic = modelData;
                                    } else if (dropdownOverlay.displaySection === "type") {
                                        root.currentStudyType = modelData;
                                    }
                                    root.commitTags();
                                    root.activeDropdown = "";
                                }
                            }
                        }

                        WidgetTextView {
                            anchors.centerIn: parent
                            visible: suggestionList.count === 0
                            text: "No suggestions"
                            role: "caption"
                            colorOverride: StyleTokens.textTertiary
                            widgetContext: root.widgetContext
                        }
                    }
                }
            }
        }
    }
}
