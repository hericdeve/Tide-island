import QtQuick
import QtQuick.Controls
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 2
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

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
    }

    // Single-slot view mode: 0 = Timer controls, 1 = Tags & metadata
    property int singleSlotTab: 0

    readonly property bool isWide: width >= 340 || slotSpan >= 2

    anchors.fill: parent

    // -------------------------------------------------------------
    // OFFLINE BANNER (shown when Pomotroid is not running)
    // -------------------------------------------------------------
    Item {
        id: offlineView
        anchors.fill: parent
        anchors.margins: 4
        visible: !root.connected

        // Wide layout (centered column)
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: root.isWide

            WidgetTextView {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pomotroid Offline"
                role: "title"
                colorOverride: "white"
                widgetContext: root.widgetContext
            }

            WidgetTextView {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Launch Pomotroid to start tracking sessions"
                role: "caption"
                colorOverride: "#a1a1aa"
                widgetContext: root.widgetContext
            }

            Item { width: 1; height: 4 }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: launchRow.implicitWidth + 20
                height: 26
                radius: 13
                color: launchMouse.pressed ? "#dc2626" : (launchMouse.containsMouse ? "#ef4444" : "#ff453a")

                Row {
                    id: launchRow
                    anchors.centerIn: parent
                    spacing: 6

                    WidgetIconGlyph {
                        glyph: "󰐊"
                        size: 11
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }

                    WidgetTextView {
                        text: "Launch Pomotroid"
                        role: "caption"
                        colorOverride: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }
                }

                MouseArea {
                    id: launchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PomotroidBackend.launchPomotroid()
                }
            }
        }

        // Compact layout (vertical column for narrow 1-slot views)
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: !root.isWide

            WidgetTextView {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pomotroid Offline"
                role: "body"
                colorOverride: "white"
                widgetContext: root.widgetContext
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: compactLaunchRow.implicitWidth + 16
                height: 22
                radius: 11
                color: compactLaunchMouse.pressed ? "#dc2626" : (compactLaunchMouse.containsMouse ? "#ef4444" : "#ff453a")

                Row {
                    id: compactLaunchRow
                    anchors.centerIn: parent
                    spacing: 4

                    WidgetIconGlyph {
                        glyph: "󰐊"
                        size: 10
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }

                    WidgetTextView {
                        text: "Launch"
                        role: "caption"
                        colorOverride: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }
                }

                MouseArea {
                    id: compactLaunchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PomotroidBackend.launchPomotroid()
                }
            }
        }
    }

    // -------------------------------------------------------------
    // MAIN CONNECTED VIEW
    // -------------------------------------------------------------
    Item {
        id: connectedView
        anchors.fill: parent
        anchors.margins: 2
        visible: root.connected

        // ═══════════════════════════════════════════════════════════
        // WIDE LAYOUT (slotSpan >= 2)
        // ═══════════════════════════════════════════════════════════
        Row {
            anchors.fill: parent
            spacing: 8
            visible: root.isWide

            // --- LEFT COLUMN: Timer & Controls ---
            Item {
                width: Math.max(220, parent.width * 0.62)
                height: parent.height

                Column {
                    anchors.fill: parent
                    spacing: 4

                    // Header Row: Round Badge + Goal Stepper + Quick Actions
                    Item {
                        width: parent.width
                        height: 22

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Round Badge
                            Rectangle {
                                height: 20
                                width: badgeRow.implicitWidth + 12
                                radius: 10
                                color: root.themeColorBg
                                border.width: 1
                                border.color: root.themeColor

                                Row {
                                    id: badgeRow
                                    anchors.centerIn: parent

                                    WidgetTextView {
                                        text: root.roundLabel + " " + root.roundNumber + "/" + root.roundsTotal
                                        role: "caption"
                                        tabularFigures: true
                                        colorOverride: root.themeColor
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }
                                }
                            }

                            // Goal Stepper Pill
                            Rectangle {
                                height: 20
                                width: goalRow.implicitWidth + 8
                                radius: 10
                                color: "#1e1e24"
                                border.width: 1
                                border.color: "#32323a"

                                Row {
                                    id: goalRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    WidgetIconGlyph {
                                        glyph: "󰓠"
                                        size: 9
                                        color: "#a1a1aa"
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }

                                    WidgetTextView {
                                        text: (root.isWork ? Math.max(0, root.sessionWorkCount - 1) : root.sessionWorkCount) + "/" + root.goalRounds
                                        role: "caption"
                                        tabularFigures: true
                                        colorOverride: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }

                                    // Decrement button
                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: StyleTokens.radiusButton
                                        color: decMouse.containsMouse ? "#3f3f46" : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        WidgetTextView {
                                            anchors.centerIn: parent
                                            text: "-"
                                            role: "caption"
                                            colorOverride: "#d4d4d8"
                                            widgetContext: root.widgetContext
                                        }
                                        MouseArea {
                                            id: decMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: PomotroidBackend.setGoalRounds(root.goalRounds - 1)
                                        }
                                    }

                                    // Increment button
                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: StyleTokens.radiusButton
                                        color: incMouse.containsMouse ? "#3f3f46" : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        WidgetTextView {
                                            anchors.centerIn: parent
                                            text: "+"
                                            role: "caption"
                                            colorOverride: "#d4d4d8"
                                            widgetContext: root.widgetContext
                                        }
                                        MouseArea {
                                            id: incMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: PomotroidBackend.setGoalRounds(root.goalRounds + 1)
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // Stats Window Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: statsMouse.containsMouse ? "#27272a" : "transparent"

                                WidgetIconGlyph {
                                    anchors.centerIn: parent
                                    glyph: "󰄫"
                                    size: 12
                                    color: statsMouse.containsMouse ? "white" : "#a1a1aa"
                                    widgetContext: root.widgetContext
                                }
                                MouseArea {
                                    id: statsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PomotroidBackend.openStatsWindow()
                                }
                            }

                            // Focus Main Window Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: mainWinMouse.containsMouse ? "#27272a" : "transparent"

                                WidgetIconGlyph {
                                    anchors.centerIn: parent
                                    glyph: "󰖰"
                                    size: 12
                                    color: mainWinMouse.containsMouse ? "white" : "#a1a1aa"
                                    widgetContext: root.widgetContext
                                }
                                MouseArea {
                                    id: mainWinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PomotroidBackend.openMainWindow()
                                }
                            }
                        }
                    }

                    // Center Display: Large Countdown Clock & Progress Arc/Pill
                    Item {
                        width: parent.width
                        height: parent.height - 22 - 32 - 12

                        Row {
                            anchors.centerIn: parent
                            spacing: 12

                            // Mini Dial Arc
                            Item {
                                width: 50
                                height: 50
                                anchors.verticalCenter: parent.verticalCenter

                                WidgetProgressRing {
                                    anchors.fill: parent
                                    value: 1.0 - root.progress
                                    strokeWidth: 4
                                    fillColor: root.themeColor
                                    trackColor: StyleTokens.track
                                }

                                WidgetTextView {
                                    anchors.centerIn: parent
                                    text: root.roundNumber
                                    role: "metric"
                                    colorOverride: root.themeColor
                                    widgetContext: root.widgetContext
                                }
                            }

                            // Big Time Display
                            Column {
                                width: 86
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                WidgetTextView {
                                    width: parent.width
                                    text: PomotroidBackend.formatTime(root.remainingSeconds)
                                    role: "hero"
                                    horizontalAlignment: Text.AlignHCenter
                                    tabularFigures: true
                                    widgetContext: root.widgetContext
                                }

                                WidgetTextView {
                                    width: parent.width
                                    text: root.isRunning ? "RUNNING" : (root.isPaused ? "PAUSED" : "IDLE")
                                    role: "caption"
                                    horizontalAlignment: Text.AlignHCenter
                                    colorOverride: root.isRunning ? root.themeColor : "#71717a"
                                    widgetContext: root.widgetContext
                                }
                            }
                        }
                    }

                    // Bottom: Control Buttons Row (Back to Start, Play/Pause, Skip, Reset)
                    Row {
                        width: parent.width
                        height: 30
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Back to Start (restartRound)
                        WidgetActionButton {
                            width: 32
                            height: 28
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰑐"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.restartRound()
                        }

                        // Play / Pause / Resume
                        WidgetActionButton {
                            width: parent.width - 32 - 32 - 32 - 24
                            height: 28
                            variant: "capsule"
                            buttonStyle: "primary"
                            icon: root.isRunning ? "󰏤" : "󰐊"
                            label: root.isRunning ? "Pause" : (root.isPaused ? "Resume" : "Start")
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.toggleTimer()
                        }

                        // Skip Round
                        WidgetActionButton {
                            width: 32
                            height: 28
                            variant: "icon"
                            buttonStyle: "secondary"
                            icon: "󰒭"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.skipRound()
                        }

                        // Reset
                        WidgetActionButton {
                            width: 32
                            height: 28
                            variant: "icon"
                            buttonStyle: "danger"
                            icon: "󰦛"
                            widgetContext: root.widgetContext
                            onClicked: PomotroidBackend.resetTimer()
                        }
                    }
                }
            }

            // Vertical divider
            Rectangle {
                width: 1
                height: parent.height - 8
                anchors.verticalCenter: parent.verticalCenter
                color: "#27272a"
            }

            // --- RIGHT COLUMN: Session Tags & Autocompletion ---
            Item {
                width: parent.width - Math.max(220, parent.width * 0.62) - 1 - 20
                height: parent.height

                Column {
                    anchors.fill: parent
                    spacing: 5

                    // Title bar for tags
                    Item {
                        width: parent.width
                        height: 18

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            WidgetIconGlyph {
                                glyph: "󰓹"
                                size: 11
                                color: "#a1a1aa"
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }

                            WidgetTextView {
                                text: "Session Tags"
                                role: "caption"
                                colorOverride: "#a1a1aa"
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }
                        }

                        WidgetTextView {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Auto-synced"
                            role: "caption"
                            colorOverride: "#52525b"
                            widgetContext: root.widgetContext
                        }
                    }

                    // Field 1: Subject (with autocomplete)
                    Item {
                        width: parent.width
                        height: 24
                        z: subjectPopup.visible ? 50 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: subjectInput.activeFocus ? root.themeColor : "#27272a"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                WidgetIconGlyph {
                                    glyph: "󰑴"
                                    size: 10
                                    color: "#71717a"
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                }

                                TextInput {
                                    id: subjectInput
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.currentSubject
                                    font.family: root.textFontFamily
                                    font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                                    color: "white"
                                    clip: true
                                    onTextChanged: {
                                        root.currentSubject = text;
                                        if (activeFocus) {
                                            PomotroidBackend.fetchTopicsForSubject(text.trim());
                                        }
                                    }
                                    onEditingFinished: root.commitTags()

                                    WidgetTextView {
                                        text: "Subject (e.g. Math, Physics)..."
                                        role: "caption"
                                        colorOverride: "#52525b"
                                        visible: !subjectInput.text && !subjectInput.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }
                                }

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: subDropMouse.containsMouse ? "#27272a" : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    WidgetIconGlyph {
                                        anchors.centerIn: parent
                                        glyph: "󰅀"
                                        size: 8
                                        color: "#71717a"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: subDropMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: subjectPopup.visible = !subjectPopup.visible
                                    }
                                }
                            }
                        }

                        // Subject Autocomplete Dropdown
                        Rectangle {
                            id: subjectPopup
                            width: parent.width
                            height: Math.min(100, subList.contentHeight + 4)
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#3f3f46"
                            visible: false
                            clip: true

                            ListView {
                                id: subList
                                anchors.fill: parent
                                anchors.margins: 2
                                model: PomotroidBackend.cachedSubjects
                                delegate: Rectangle {
                                    width: subList.width
                                    height: 20
                                    radius: 4
                                    color: subItemMouse.containsMouse ? "#27272a" : "transparent"

                                    WidgetTextView {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        role: "caption"
                                        colorOverride: "white"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: subItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSubject = modelData;
                                            subjectInput.text = modelData;
                                            subjectPopup.visible = false;
                                            root.commitTags();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Field 2: Topic (with autocomplete filtered by subject)
                    Item {
                        width: parent.width
                        height: 24
                        z: topicPopup.visible ? 40 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: topicInput.activeFocus ? root.themeColor : "#27272a"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                WidgetIconGlyph {
                                    glyph: "󰅍"
                                    size: 10
                                    color: "#71717a"
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                }

                                TextInput {
                                    id: topicInput
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.currentTopic
                                    font.family: root.textFontFamily
                                    font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                                    color: "white"
                                    clip: true
                                    onTextChanged: root.currentTopic = text
                                    onEditingFinished: root.commitTags()

                                    WidgetTextView {
                                        text: "Topic / Chapter..."
                                        role: "caption"
                                        colorOverride: "#52525b"
                                        visible: !topicInput.text && !topicInput.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }
                                }

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: topicDropMouse.containsMouse ? "#27272a" : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    WidgetIconGlyph {
                                        anchors.centerIn: parent
                                        glyph: "󰅀"
                                        size: 8
                                        color: "#71717a"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: topicDropMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: topicPopup.visible = !topicPopup.visible
                                    }
                                }
                            }
                        }

                        // Topic Autocomplete Dropdown
                        Rectangle {
                            id: topicPopup
                            width: parent.width
                            height: Math.min(100, topicList.contentHeight + 4)
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#3f3f46"
                            visible: false
                            clip: true

                            ListView {
                                id: topicList
                                anchors.fill: parent
                                anchors.margins: 2
                                model: PomotroidBackend.cachedTopics
                                delegate: Rectangle {
                                    width: topicList.width
                                    height: 20
                                    radius: 4
                                    color: topicItemMouse.containsMouse ? "#27272a" : "transparent"

                                    WidgetTextView {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        role: "caption"
                                        colorOverride: "white"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: topicItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentTopic = modelData;
                                            topicInput.text = modelData;
                                            topicPopup.visible = false;
                                            root.commitTags();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Field 3: Study Type (with chips / autocomplete)
                    Item {
                        width: parent.width
                        height: 24
                        z: typePopup.visible ? 30 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: typeInput.activeFocus ? root.themeColor : "#27272a"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                WidgetIconGlyph {
                                    glyph: "󰌵"
                                    size: 10
                                    color: "#71717a"
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                }

                                TextInput {
                                    id: typeInput
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.currentStudyType
                                    font.family: root.textFontFamily
                                    font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                                    color: "white"
                                    clip: true
                                    onTextChanged: root.currentStudyType = text
                                    onEditingFinished: root.commitTags()

                                    WidgetTextView {
                                        text: "Type (Teoria, Exercicio, Leitura)..."
                                        role: "caption"
                                        colorOverride: "#52525b"
                                        visible: !typeInput.text && !typeInput.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                        widgetContext: root.widgetContext
                                    }
                                }

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: typeDropMouse.containsMouse ? "#27272a" : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    WidgetIconGlyph {
                                        anchors.centerIn: parent
                                        glyph: "󰅀"
                                        size: 8
                                        color: "#71717a"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: typeDropMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: typePopup.visible = !typePopup.visible
                                    }
                                }
                            }
                        }

                        // Study Type Dropdown
                        Rectangle {
                            id: typePopup
                            width: parent.width
                            height: Math.min(100, typeList.contentHeight + 4)
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#3f3f46"
                            visible: false
                            clip: true

                            ListView {
                                id: typeList
                                anchors.fill: parent
                                anchors.margins: 2
                                model: PomotroidBackend.cachedStudyTypes
                                delegate: Rectangle {
                                    width: typeList.width
                                    height: 20
                                    radius: 4
                                    color: typeItemMouse.containsMouse ? "#27272a" : "transparent"

                                    WidgetTextView {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        role: "caption"
                                        colorOverride: "white"
                                        widgetContext: root.widgetContext
                                    }
                                    MouseArea {
                                        id: typeItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentStudyType = modelData;
                                            typeInput.text = modelData;
                                            typePopup.visible = false;
                                            root.commitTags();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Field 4: Notes
                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: 6
                        color: "#18181b"
                        border.width: 1
                        border.color: notesInput.activeFocus ? root.themeColor : "#27272a"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            WidgetIconGlyph {
                                glyph: "󰎞"
                                size: 10
                                color: "#71717a"
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }

                            TextInput {
                                id: notesInput
                                width: parent.width - 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentNotes
                                font.family: root.textFontFamily
                                font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                                color: "white"
                                clip: true
                                onTextChanged: root.currentNotes = text
                                onEditingFinished: root.commitTags()

                                WidgetTextView {
                                    text: "Session notes..."
                                    role: "caption"
                                    colorOverride: "#52525b"
                                    visible: !notesInput.text && !notesInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    widgetContext: root.widgetContext
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // COMPACT / 1-SLOT LAYOUT (slotSpan == 1 or narrow)
        // ═══════════════════════════════════════════════════════════
        Column {
            anchors.fill: parent
            spacing: 6
            visible: !root.isWide

            // Top Header: Round Badge + Tab switch (Timer / Tags) + Actions
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Round Badge
                    Rectangle {
                        height: 20
                        width: compactBadgeRow.implicitWidth + 10
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

                    // Tab Switcher Pill: Timer | Tags
                    Rectangle {
                        height: 20
                        width: 80
                        radius: 10
                        color: "#18181b"
                        border.width: 1
                        border.color: "#27272a"

                        Row {
                            anchors.fill: parent

                            Rectangle {
                                width: 40
                                height: parent.height
                                radius: 10
                                color: root.singleSlotTab === 0 ? "#27272a" : "transparent"
                                WidgetTextView {
                                    anchors.centerIn: parent
                                    text: "Timer"
                                    role: "caption"
                                    colorOverride: root.singleSlotTab === 0 ? "white" : "#71717a"
                                    widgetContext: root.widgetContext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.singleSlotTab = 0
                                }
                            }

                            Rectangle {
                                width: 40
                                height: parent.height
                                radius: 10
                                color: root.singleSlotTab === 1 ? "#27272a" : "transparent"
                                WidgetTextView {
                                    anchors.centerIn: parent
                                    text: "Tags"
                                    role: "caption"
                                    colorOverride: root.singleSlotTab === 1 ? "white" : "#71717a"
                                    widgetContext: root.widgetContext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.singleSlotTab = 1
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Stats Button
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: cStatsMouse.containsMouse ? "#27272a" : "transparent"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: "󰄫"
                            size: 11
                            color: "#a1a1aa"
                            widgetContext: root.widgetContext
                        }
                        MouseArea {
                            id: cStatsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PomotroidBackend.openStatsWindow()
                        }
                    }

                    // Main Window Button
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: cMainMouse.containsMouse ? "#27272a" : "transparent"

                        WidgetIconGlyph {
                            anchors.centerIn: parent
                            glyph: "󰖰"
                            size: 11
                            color: "#a1a1aa"
                            widgetContext: root.widgetContext
                        }
                        MouseArea {
                            id: cMainMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PomotroidBackend.openMainWindow()
                        }
                    }
                }
            }

            // Tab 0: Timer & Controls
            Item {
                width: parent.width
                height: parent.height - 28
                visible: root.singleSlotTab === 0

                Column {
                    anchors.fill: parent
                    spacing: 6

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
                            colorOverride: "white"
                            widgetContext: root.widgetContext
                        }

                        WidgetTextView {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentSubject ? (root.currentSubject + (root.currentTopic ? " • " + root.currentTopic : "")) : (root.isRunning ? "RUNNING" : "IDLE")
                            role: "caption"
                            colorOverride: root.currentSubject ? "#d4d4d8" : "#71717a"
                            overflowMode: "elide"
                            width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            widgetContext: root.widgetContext
                        }
                    }

                    // Progress bar
                    Rectangle {
                        width: parent.width - 24
                        height: 4
                        radius: 2
                        color: "#27272a"
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: parent.width * (1.0 - root.progress)
                            height: parent.height
                            radius: 2
                            color: root.themeColor
                        }
                    }

                    // Buttons Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        // Back to start
                        Rectangle {
                            width: 28
                            height: 26
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰑐"
                                size: 12
                                color: "#d4d4d8"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: PomotroidBackend.restartRound()
                            }
                        }

                        // Play/Pause
                        Rectangle {
                            width: 50
                            height: 26
                            radius: 6
                            color: root.themeColor
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: root.isRunning ? "󰏤" : "󰐊"
                                size: 13
                                color: "white"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: PomotroidBackend.toggleTimer()
                            }
                        }

                        // Skip
                        Rectangle {
                            width: 28
                            height: 26
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰒭"
                                size: 12
                                color: "#d4d4d8"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: PomotroidBackend.skipRound()
                            }
                        }

                        // Reset
                        Rectangle {
                            width: 28
                            height: 26
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            WidgetIconGlyph {
                                anchors.centerIn: parent
                                glyph: "󰦛"
                                size: 12
                                color: "#ef4444"
                                widgetContext: root.widgetContext
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: PomotroidBackend.resetTimer()
                            }
                        }
                    }
                }
            }

            // Tab 1: Tags & Autocompletion in single slot
            Item {
                width: parent.width
                height: parent.height - 28
                visible: root.singleSlotTab === 1

                Column {
                    anchors.fill: parent
                    spacing: 4

                    // Subject
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 5
                        color: "#18181b"
                        border.width: 1
                        border.color: cSubInput.activeFocus ? root.themeColor : "#27272a"

                        TextInput {
                            id: cSubInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.currentSubject
                            font.family: root.textFontFamily
                            font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                            color: "white"
                            clip: true
                            onTextChanged: root.currentSubject = text
                            onEditingFinished: root.commitTags()

                            WidgetTextView {
                                text: "Subject..."
                                role: "caption"
                                colorOverride: "#52525b"
                                visible: !cSubInput.text && !cSubInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }
                        }
                    }

                    // Topic
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 5
                        color: "#18181b"
                        border.width: 1
                        border.color: cTopInput.activeFocus ? root.themeColor : "#27272a"

                        TextInput {
                            id: cTopInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.currentTopic
                            font.family: root.textFontFamily
                            font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                            color: "white"
                            clip: true
                            onTextChanged: root.currentTopic = text
                            onEditingFinished: root.commitTags()

                            WidgetTextView {
                                text: "Topic..."
                                role: "caption"
                                colorOverride: "#52525b"
                                visible: !cTopInput.text && !cTopInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }
                        }
                    }

                    // Type
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 5
                        color: "#18181b"
                        border.width: 1
                        border.color: cTypInput.activeFocus ? root.themeColor : "#27272a"

                        TextInput {
                            id: cTypInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.currentStudyType
                            font.family: root.textFontFamily
                            font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                            color: "white"
                            clip: true
                            onTextChanged: root.currentStudyType = text
                            onEditingFinished: root.commitTags()

                            WidgetTextView {
                                text: "Study Type..."
                                role: "caption"
                                colorOverride: "#52525b"
                                visible: !cTypInput.text && !cTypInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }
                        }
                    }

                    // Notes
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 5
                        color: "#18181b"
                        border.width: 1
                        border.color: cNotInput.activeFocus ? root.themeColor : "#27272a"

                        TextInput {
                            id: cNotInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.currentNotes
                            font.family: root.textFontFamily
                            font.pixelSize: Math.round(10 * root.bodyFontSize / 16.0)
                            color: "white"
                            clip: true
                            onTextChanged: root.currentNotes = text
                            onEditingFinished: root.commitTags()

                            WidgetTextView {
                                text: "Notes..."
                                role: "caption"
                                colorOverride: "#52525b"
                                visible: !cNotInput.text && !cNotInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                widgetContext: root.widgetContext
                            }
                        }
                    }
                }
            }
        }
    }
}
