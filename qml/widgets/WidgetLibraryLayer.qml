import QtQuick
import IslandBackend
import "."

// Clean, minimal Widget Library Showcase
// Pure black background matching notch app.
// Direct widget previews with no redundant titles or separators.
// Only displays the size variations each widget actually implements.
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
        if (req === "full" && (!currentWidget.fullComponent || currentWidget.fullComponent === "")) return false;
        if (req === "minimum" && (!currentWidget.minimumComponent || currentWidget.minimumComponent === "")) return false;
        if (req === "circle" && (!currentWidget.circleComponent || currentWidget.circleComponent === "")) return false;
        return currentWidget.supportedSizes.indexOf(req) !== -1;
    }

    readonly property bool currentSupportsFull: currentWidget && currentWidget.supportedSizes
        && currentWidget.supportedSizes.indexOf("full") !== -1
        && !!currentWidget.fullComponent && currentWidget.fullComponent !== ""
    readonly property bool currentSupportsMinimum: currentWidget && currentWidget.supportedSizes
        && currentWidget.supportedSizes.indexOf("minimum") !== -1
        && !!currentWidget.minimumComponent && currentWidget.minimumComponent !== ""
    readonly property bool currentSupportsCircle: currentWidget && currentWidget.supportedSizes
        && currentWidget.supportedSizes.indexOf("circle") !== -1
        && !!currentWidget.circleComponent && currentWidget.circleComponent !== ""

    readonly property real contentHeight: mainCol.implicitHeight + 28

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
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
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
                if (accumulatedX < -20) {
                    root.nextWidget();
                    accumulatedX = 0;
                    event.accepted = true;
                } else if (accumulatedX > 20) {
                    root.prevWidget();
                    accumulatedX = 0;
                    event.accepted = true;
                }
            }
        }
    }

    // Pure black background matching notch app
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 26
        color: "#000000"
        border.width: 1
        border.color: "#242426"
        clip: true

        Column {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ── Minimal Top Navigation Bar ──────────────────────────────────
            Item {
                width: parent.width
                height: 24

                // Dot pagination indicator & counter
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: root.widgetCount

                        Rectangle {
                            width: index === root.currentIndex ? 14 : 4
                            height: 4
                            radius: 2
                            color: index === root.currentIndex ? "#b56cff" : "#333336"

                            Behavior on width {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 180 }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.currentIndex + 1) + "/" + root.widgetCount
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: "#66666a"
                    }
                }

                // Target mode selector pills
                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "expanded", label: "Expanded" },
                            { id: "minimum", label: "Closed" },
                            { id: "circle", label: "Circle" }
                        ]

                        Rectangle {
                            readonly property bool isSelected: root.targetMode === modelData.id
                            width: modeText.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: isSelected ? "#2a1c3d" : (modeMouse.containsMouse ? "#1c1c1f" : "#111113")
                            border.width: 1
                            border.color: isSelected ? "#b56cff" : "#242426"

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                font.weight: parent.isSelected ? Font.Bold : Font.Normal
                                color: parent.isSelected ? "#d8b4fe" : "#77777c"
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

                // Minimal close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.containsMouse ? "#222225" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                        color: closeMouse.containsMouse ? "white" : "#77777c"
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

            // ── Widget Card (Describes Widget & Shows Available Variations) ──
            Rectangle {
                id: widgetCard
                width: parent.width
                height: 74
                radius: 14
                color: "#0d0d0f"
                border.width: 1
                border.color: "#1e1e22"

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
                        if (moved && Math.abs(dx) > 26) {
                            if (dx < 0)
                                root.nextWidget();
                            else
                                root.prevWidget();
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Previous widget button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: prevMouse.containsMouse ? "#25252a" : "#161619"
                        border.width: 1
                        border.color: "#28282d"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
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

                    // Title and description
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 136
                        spacing: 3

                        Text {
                            text: root.currentWidget ? root.currentWidget.name : ""
                            font.family: root.textFontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "white"
                        }

                        Text {
                            width: parent.width
                            text: root.currentWidget ? root.currentWidget.description : ""
                            font.family: root.textFontFamily
                            font.pixelSize: 11
                            color: "#88888e"
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // Add button: Icon only!
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: root.currentSupportsTargetMode
                            ? (addMouse.containsMouse ? "#c285ff" : "#b56cff")
                            : "#1a1a1d"
                        border.width: 1
                        border.color: root.currentSupportsTargetMode ? "#d8b4fe" : "#28282d"
                        opacity: root.currentSupportsTargetMode ? 1.0 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: root.currentSupportsTargetMode ? "white" : "#555"
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.currentSupportsTargetMode ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.currentSupportsTargetMode && root.currentWidget && userConfig) {
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
                        width: 26
                        height: 26
                        radius: 13
                        color: nextMouse.containsMouse ? "#25252a" : "#161619"
                        border.width: 1
                        border.color: "#28282d"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
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

            // ── Stacked Widget Variations Previews (Only Implemented Ones, No Titles) ──
            Flickable {
                id: previewsFlickable
                width: parent.width
                height: Math.max(80, parent.height - 24 - 74 - 24)
                contentWidth: width
                contentHeight: previewsColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: previewsColumn
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: {
                            if (!root.currentWidget) return [];
                            const list = [];
                            if (root.currentSupportsFull) {
                                list.push({
                                    type: "full",
                                    source: root.currentWidget.fullComponent,
                                    itemHeight: 134,
                                    cardWidth: previewsColumn.width,
                                    cardHeight: 134,
                                    cardRadius: 12,
                                    slotSpan: root.currentWidget.defaultSlotSpan || 2
                                });
                            }
                            if (root.currentSupportsMinimum) {
                                list.push({
                                    type: "minimum",
                                    source: root.currentWidget.minimumComponent,
                                    itemHeight: 38,
                                    cardWidth: Math.min(previewsColumn.width - 24, 240),
                                    cardHeight: 34,
                                    cardRadius: 17,
                                    slotSpan: 1
                                });
                            }
                            if (root.currentSupportsCircle) {
                                list.push({
                                    type: "circle",
                                    source: root.currentWidget.circleComponent,
                                    itemHeight: 62,
                                    cardWidth: 58,
                                    cardHeight: 58,
                                    cardRadius: 29,
                                    slotSpan: 1
                                });
                            }
                            return list;
                        }

                        Item {
                            id: previewDelegate
                            required property var modelData
                            width: previewsColumn.width
                            height: previewDelegate.modelData.itemHeight

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: previewDelegate.modelData.cardWidth
                                height: previewDelegate.modelData.cardHeight
                                radius: previewDelegate.modelData.cardRadius
                                color: "#08080a"
                                border.width: 1
                                border.color: "#1c1c20"
                                clip: true

                                Loader {
                                    anchors.fill: parent
                                    anchors.margins: previewDelegate.modelData.type === "full" ? 4 : 0
                                    source: previewDelegate.modelData.source

                                    onLoaded: {
                                        if (item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = previewDelegate.modelData.slotSpan;
                                            item.isEditMode = false;
                                        }
                                    }
                                    onStatusChanged: {
                                        if (status === Loader.Ready && item) {
                                            item.widgetContext = root.previewWidgetContext;
                                            item.slotSpan = previewDelegate.modelData.slotSpan;
                                            item.isEditMode = false;
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
}
