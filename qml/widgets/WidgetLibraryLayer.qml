import QtQuick
import IslandBackend
import "."

// Revamped Widget Library Showcase
// Displays a detailed card for each widget describing it, indicating available
// size variations (Full, Minimum, Circle), and expanding downwards to display
// all available versions stacked on top of each other.
// Swiping left/right or using wheel/keyboard navigates between widgets.
Item {
    id: root

    property bool showCondition: false
    property string targetMode: "expanded" // "expanded" | "minimum" | "circle"
    property int targetPageIndex: 0
    property int targetSlotIndex: 0
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    // Live/contextual inputs
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property int batteryCapacity: 85
    property bool isCharging: false
    property real currentCpuUsage: 26
    property real currentRamUsage: 44
    property string currentTime: "12:00"
    property string currentDateLabel: "Mon, 7"

    signal widgetSelected(string widgetId)
    signal closeRequested()

    readonly property var userConfig: UserConfig
    readonly property var catalog: WidgetRegistry.catalog
    readonly property int widgetCount: catalog ? catalog.length : 0

    property int currentIndex: 0
    readonly property var currentWidget: (catalog && widgetCount > 0) ? catalog[currentIndex] : null

    // Compatibility check for target mode
    readonly property bool currentSupportsTargetMode: {
        if (!currentWidget || !currentWidget.supportedSizes) return false;
        const req = targetMode === "expanded" ? "full" : (targetMode === "circle" ? "circle" : "minimum");
        return currentWidget.supportedSizes.indexOf(req) !== -1;
    }

    readonly property bool currentSupportsFull: currentWidget && currentWidget.supportedSizes && currentWidget.supportedSizes.indexOf("full") !== -1
    readonly property bool currentSupportsMinimum: currentWidget && currentWidget.supportedSizes && currentWidget.supportedSizes.indexOf("minimum") !== -1
    readonly property bool currentSupportsCircle: currentWidget && currentWidget.supportedSizes && currentWidget.supportedSizes.indexOf("circle") !== -1

    function nextWidget() {
        if (widgetCount <= 0) return;
        currentIndex = (currentIndex + 1) % widgetCount;
    }

    function prevWidget() {
        if (widgetCount <= 0) return;
        currentIndex = (currentIndex - 1 + widgetCount) % widgetCount;
    }

    // Shared mock/live context for preview loaders
    readonly property var previewWidgetContext: ({
        activePlayer: null,
        currentTrack: root.currentTrack !== "" ? root.currentTrack : "Starboy",
        currentArtist: root.currentArtist !== "" ? root.currentArtist : "The Weeknd",
        currentArtUrl: root.currentArtUrl,
        lyricsText: "I'm tryna put you in the worst mood, ah...",
        timePlayed: "1:42",
        timeTotal: "3:50",
        trackProgress: 0.44,
        isPlaying: true,
        batteryCapacity: root.batteryCapacity >= 0 ? root.batteryCapacity : 82,
        isCharging: root.isCharging,
        currentCpuUsage: root.currentCpuUsage > 0 ? root.currentCpuUsage : 28,
        currentRamUsage: root.currentRamUsage > 0 ? root.currentRamUsage : 46,
        currentTime: root.currentTime !== "" ? root.currentTime : "14:32",
        currentDateLabel: root.currentDateLabel !== "" ? root.currentDateLabel : "Mon, Sep 7",
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.textFontFamily,
        uiScale: 1.0,
        isEditMode: false,
        faceScale: 0.72,
        circleDiameter: 64
    })

    opacity: showCondition ? 1.0 : 0.0
    scale: showCondition ? 1.0 : 0.96
    visible: opacity > 0.001
    focus: showCondition

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }

    Keys.onLeftPressed: root.prevWidget()
    Keys.onRightPressed: root.nextWidget()
    Keys.onEscapePressed: root.closeRequested()

    // Horizontal wheel navigation between widgets
    WheelHandler {
        id: wheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulatedX: 0

        onWheel: function(event) {
            if (event.phase === Qt.ScrollMomentum) return;
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : (event.angleDelta.x / 5);
            if (Math.abs(dx) > 1) {
                accumulatedX += dx;
                if (accumulatedX < -22) {
                    root.nextWidget();
                    accumulatedX = 0;
                    event.accepted = true;
                } else if (accumulatedX > 22) {
                    root.prevWidget();
                    accumulatedX = 0;
                    event.accepted = true;
                }
            }
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 24
        color: "#18181b"
        border.width: 1
        border.color: "#343438"
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Header Bar ───────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 8
                        color: "#271c38"
                        border.width: 1
                        border.color: "#b56cff"

                        Text {
                            anchors.centerIn: parent
                            text: "󰏖"
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            color: "#b56cff"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: "Widget Library"
                            font.family: root.textFontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "white"
                        }

                        Text {
                            text: "Swipe left/right to browse available widgets"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: "#8e8e93"
                        }
                    }
                }

                // Target mode selector pills
                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "expanded", label: "Expanded (Full)" },
                            { id: "minimum", label: "Closed (Min)" },
                            { id: "circle", label: "Circle (Dial)" }
                        ]

                        Rectangle {
                            readonly property bool isSelected: root.targetMode === modelData.id
                            width: modeText.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: isSelected ? "#b56cff" : (modeMouse.containsMouse ? "#2c2c30" : "#222225")
                            border.width: 1
                            border.color: isSelected ? "#c285ff" : "#323236"

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                font.weight: parent.isSelected ? Font.Bold : Font.Normal
                                color: parent.isSelected ? "white" : "#a1a1a6"
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.targetMode = modelData.id
                            }
                        }
                    }
                }

                // Close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: closeMouse.containsMouse ? "#323236" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 13
                        color: closeMouse.containsMouse ? "white" : "#8e8e93"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ── Widget Hero Card & Swiper Controls ───────────────────────────
            Rectangle {
                id: heroCard
                width: parent.width
                height: 116
                radius: 16
                color: "#222226"
                border.width: 1
                border.color: "#38383e"

                // Touch / Mouse Drag to swipe left/right
                MouseArea {
                    id: swipeArea
                    anchors.fill: parent
                    property real startX: 0
                    property bool moved: false

                    onPressed: (mouse) => {
                        startX = mouse.x;
                        moved = false;
                    }
                    onPositionChanged: (mouse) => {
                        if (Math.abs(mouse.x - startX) > 10)
                            moved = true;
                    }
                    onReleased: (mouse) => {
                        const dx = mouse.x - startX;
                        if (moved && Math.abs(dx) > 28) {
                            if (dx < 0)
                                root.nextWidget();
                            else
                                root.prevWidget();
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Previous widget button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: prevMouse.containsMouse ? "#383840" : "#2a2a2e"
                        border.width: 1
                        border.color: "#3a3a42"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: root.iconFontFamily
                            font.pixelSize: 14
                            color: "white"
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevWidget()
                        }
                    }

                    // Widget icon
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        height: 50
                        radius: 14
                        color: "#18181c"
                        border.width: 1.5
                        border.color: root.currentSupportsTargetMode ? "#b56cff" : "#444448"

                        Text {
                            anchors.centerIn: parent
                            text: root.currentWidget ? root.currentWidget.icon : "󰏖"
                            font.family: root.iconFontFamily
                            font.pixelSize: 26
                            color: root.currentSupportsTargetMode ? "#b56cff" : "#8e8e93"
                        }
                    }

                    // Main info: title, description, variations available
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28 - 50 - 140 - 48
                        spacing: 4

                        Row {
                            spacing: 8
                            Text {
                                text: root.currentWidget ? root.currentWidget.name : ""
                                font.family: root.textFontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: "white"
                            }

                            // Carousel indicator tag: "2 of 7"
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: countText.implicitWidth + 8
                                height: 16
                                radius: 8
                                color: "#2e2e34"

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: (root.currentIndex + 1) + " of " + root.widgetCount
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: "#8e8e93"
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.currentWidget ? root.currentWidget.description : ""
                            font.family: root.textFontFamily
                            font.pixelSize: 11
                            color: "#a1a1a6"
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // Available variations badges
                        Row {
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Sizes:"
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#6e6e73"
                            }

                            // Full badge
                            Rectangle {
                                width: 54
                                height: 18
                                radius: 5
                                color: root.currentSupportsFull ? "#14281a" : "#1c1c1e"
                                border.width: 1
                                border.color: root.currentSupportsFull ? "#30d158" : "#2e2e32"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍹 Full"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: root.currentSupportsFull ? "#30d158" : "#555"
                                }
                            }

                            // Min badge
                            Rectangle {
                                width: 50
                                height: 18
                                radius: 5
                                color: root.currentSupportsMinimum ? "#0e1e36" : "#1c1c1e"
                                border.width: 1
                                border.color: root.currentSupportsMinimum ? "#0a84ff" : "#2e2e32"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍺 Min"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: root.currentSupportsMinimum ? "#0a84ff" : "#555"
                                }
                            }

                            // Circle badge
                            Rectangle {
                                width: 58
                                height: 18
                                radius: 5
                                color: root.currentSupportsCircle ? "#2b1b0e" : "#1c1c1e"
                                border.width: 1
                                border.color: root.currentSupportsCircle ? "#ff9f0a" : "#2e2e32"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰚌 Circle"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: root.currentSupportsCircle ? "#ff9f0a" : "#555"
                                }
                            }
                        }
                    }

                    // Add button & Next button column
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Action button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            height: 36
                            radius: 10
                            color: root.currentSupportsTargetMode
                                ? (addMouse.containsMouse ? "#a34bfb" : "#b56cff")
                                : "#28282c"
                            border.width: 1
                            border.color: root.currentSupportsTargetMode ? "#c285ff" : "#38383e"
                            enabled: root.currentSupportsTargetMode

                            Column {
                                anchors.centerIn: parent
                                spacing: 0

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.currentSupportsTargetMode ? "+ Add to Notch" : "Unsupported"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.currentSupportsTargetMode ? "white" : "#666"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.currentSupportsTargetMode ? ("in " + root.targetMode) : ("for " + root.targetMode)
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    color: root.currentSupportsTargetMode ? "#e9d5ff" : "#555"
                                }
                            }

                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.currentSupportsTargetMode ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (root.currentWidget && userConfig) {
                                        userConfig.setSlotWidget(
                                            root.targetMode,
                                            root.targetPageIndex,
                                            root.targetSlotIndex,
                                            root.currentWidget.id,
                                            root.currentWidget.defaultSlotSpan || 1
                                        );
                                        root.widgetSelected(root.currentWidget.id);
                                        root.closeRequested();
                                    }
                                }
                            }
                        }

                        // Next widget button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: nextMouse.containsMouse ? "#383840" : "#2a2a2e"
                            border.width: 1
                            border.color: "#3a3a42"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: root.iconFontFamily
                                font.pixelSize: 14
                                color: "white"
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextWidget()
                            }
                        }
                    }
                }
            }

            // ── Section Divider Label ────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "AVAILABLE VARIATIONS (EXPANDED BELOW)"
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#8e8e93"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    height: 1
                    width: parent.width - 250
                    color: "#2c2c30"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Dot pagination indicator
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: root.widgetCount

                        Rectangle {
                            width: index === root.currentIndex ? 16 : 5
                            height: 5
                            radius: 2.5
                            color: index === root.currentIndex ? "#b56cff" : "#38383e"

                            Behavior on width {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 180 }
                            }
                        }
                    }
                }
            }

            // ── Stacked Previews Container (Scrollable) ──────────────────────
            Flickable {
                id: previewsFlickable
                width: parent.width
                height: parent.height - 32 - 116 - 20 - 30
                contentWidth: width
                contentHeight: previewsColumn.implicitHeight + 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: previewsColumn
                    width: parent.width
                    spacing: 10

                    // 1. FULL VARIATION PREVIEW (Expanded Notch)
                    Rectangle {
                        visible: root.currentSupportsFull
                        width: parent.width
                        height: 144
                        radius: 14
                        color: "#131316"
                        border.width: 1
                        border.color: "#28282c"
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // Label header
                            Row {
                                spacing: 6
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: "#30d158"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Full Version (Expanded Notch — " + (root.currentWidget ? root.currentWidget.defaultSlotSpan : 1) + " Slot Span)"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#30d158"
                                }
                            }

                            // Component preview container
                            Item {
                                width: parent.width
                                height: parent.height - 20
                                clip: true

                                Loader {
                                    id: fullPreviewLoader
                                    anchors.fill: parent
                                    active: root.currentSupportsFull && !!root.currentWidget && !!root.currentWidget.fullComponent
                                    source: active ? root.currentWidget.fullComponent : ""

                                    onLoaded: {
                                        if (item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = root.currentWidget.defaultSlotSpan || 2;
                                            item.isEditMode = false;
                                        }
                                    }
                                    onStatusChanged: {
                                        if (status === Loader.Ready && item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = root.currentWidget.defaultSlotSpan || 2;
                                            item.isEditMode = false;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. MINIMUM VARIATION PREVIEW (Closed Notch Pill)
                    Rectangle {
                        visible: root.currentSupportsMinimum
                        width: parent.width
                        height: 64
                        radius: 14
                        color: "#131316"
                        border.width: 1
                        border.color: "#28282c"
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            // Label header
                            Row {
                                spacing: 6
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: "#0a84ff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Minimum Version (Closed Notch Pill)"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#0a84ff"
                                }
                            }

                            // Compact pill container
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width - 32, 260)
                                height: 32
                                radius: 16
                                color: "#000000"
                                border.width: 1
                                border.color: "#323236"
                                clip: true

                                Loader {
                                    id: minPreviewLoader
                                    anchors.fill: parent
                                    active: root.currentSupportsMinimum && !!root.currentWidget && !!root.currentWidget.minimumComponent
                                    source: active ? root.currentWidget.minimumComponent : ""

                                    onLoaded: {
                                        if (item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = false;
                                        }
                                    }
                                    onStatusChanged: {
                                        if (status === Loader.Ready && item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = false;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. CIRCLE VARIATION PREVIEW (Smartwatch Dial)
                    Rectangle {
                        visible: root.currentSupportsCircle
                        width: parent.width
                        height: 86
                        radius: 14
                        color: "#131316"
                        border.width: 1
                        border.color: "#28282c"
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            // Label header
                            Row {
                                spacing: 6
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: "#ff9f0a"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Circle Version (Smartwatch Dial Complication)"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#ff9f0a"
                                }
                            }

                            // Circular dial container
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 54
                                height: 54
                                radius: 27
                                color: "#000000"
                                border.width: 1
                                border.color: "#323236"
                                clip: true

                                Loader {
                                    id: circlePreviewLoader
                                    anchors.fill: parent
                                    active: root.currentSupportsCircle && !!root.currentWidget && !!root.currentWidget.circleComponent
                                    source: active ? root.currentWidget.circleComponent : ""

                                    onLoaded: {
                                        if (item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = false;
                                        }
                                    }
                                    onStatusChanged: {
                                        if (status === Loader.Ready && item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = false;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Note when a widget only implements Circle (e.g. boring face)
                    Rectangle {
                        visible: !root.currentSupportsFull && !root.currentSupportsMinimum && root.currentSupportsCircle
                        width: parent.width
                        height: 38
                        radius: 10
                        color: "#1c1824"
                        border.width: 1
                        border.color: "#3d2a54"

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "󰚌"
                                font.family: root.iconFontFamily
                                font.pixelSize: 14
                                color: "#ff9f0a"
                            }

                            Text {
                                text: "This widget is exclusively designed as a Circle Mode complication."
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                color: "#bfa3dd"
                            }
                        }
                    }
                }
            }
        }
    }
}
