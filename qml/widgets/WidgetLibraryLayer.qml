import QtQuick
import IslandBackend
import "."

// Clean, minimal Widget Library Showcase
// Pure black background matching notch app.
// Direct widget previews with no redundant titles or separators.
// Only displays the size variations each widget actually implements.
Item {
    id: root
    anchors.fill: parent

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
    signal widgetStaged(string widgetId, string sizeType, int slotSpan)
    signal widgetDragStarted(string widgetId, string sizeType, int slotSpan, real winX, real winY)
    signal widgetDragMoved(real winX, real winY)
    signal widgetDragEnded(real winX, real winY)

    property bool isDraggingWidget: false

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

    readonly property real contentHeight: 520

    // ── Widget Switching Transition Animation ─────────────────────────────
    readonly property real slideDistance: 280
    property real animOffset: 0
    property real animOpacity: 1.0
    property int transitionDirection: 1
    property int pendingIndex: 0

    ParallelAnimation {
        id: dragSettleAnim
        NumberAnimation {
            target: root
            property: "animOffset"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "animOpacity"
            to: 1.0
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root
            property: "animOffset"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "animOpacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: switchSequence

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "animOffset"
                to: -root.transitionDirection * root.slideDistance
                duration: 150
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "animOpacity"
                to: 0.35
                duration: 150
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                root.currentIndex = root.pendingIndex;
                root.animOffset = root.transitionDirection * root.slideDistance;
                root.animOpacity = 0.35;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "animOffset"
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "animOpacity"
                to: 1.0
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
    }

    function triggerSwitch(targetIdx, direction) {
        if (widgetCount <= 0 || targetIdx === currentIndex) return;
        dragSettleAnim.stop();
        transitionDirection = direction;
        pendingIndex = targetIdx;

        if (switchSequence.running) {
            switchSequence.stop();
            currentIndex = targetIdx;
            animOffset = direction * root.slideDistance;
            animOpacity = 0.35;
            enterAnim.restart();
            return;
        }

        switchSequence.restart();
    }

    function nextWidget() {
        if (widgetCount <= 0) return;
        const nextIdx = (currentIndex + 1) % widgetCount;
        triggerSwitch(nextIdx, 1);
    }

    function prevWidget() {
        if (widgetCount <= 0) return;
        const prevIdx = (currentIndex - 1 + widgetCount) % widgetCount;
        triggerSwitch(prevIdx, -1);
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
    y: showCondition ? 0 : -28
    visible: showCondition
    focus: showCondition

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
    }
    Behavior on y {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    Keys.onLeftPressed: root.prevWidget()
    Keys.onRightPressed: root.nextWidget()
    Keys.onEscapePressed: root.closeRequested()

    // Horizontal wheel navigation between widgets
    Timer {
        id: libWheelResetTimer
        interval: 200
        repeat: false
        onTriggered: {
            wheelHandler.accumulatedX = 0;
            wheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: wheelHandler
        target: null
        orientation: Qt.Horizontal | Qt.Vertical
        acceptedDevices: PointerDevice.AllDevices
        property real accumulatedX: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            if (event.phase === Qt.ScrollEnd) {
                wheelHandler.accumulatedX = 0;
                wheelHandler.gestureLocked = false;
                event.accepted = true;
                return;
            }
            if (wheelHandler.gestureLocked) {
                libWheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            const px = (event.pixelDelta && event.pixelDelta.x !== undefined) ? event.pixelDelta.x : 0;
            const py = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0;
            const ax = (event.angleDelta && event.angleDelta.x !== undefined) ? (event.angleDelta.x / 5) : 0;
            const ay = (event.angleDelta && event.angleDelta.y !== undefined) ? (event.angleDelta.y / 5) : 0;

            const dx = Math.abs(px) > 0.001 ? px : ax;
            const dy = Math.abs(py) > 0.001 ? py : ay;

            if (Math.abs(dx) < 0.5) return;
            if (Math.abs(dy) > Math.abs(dx) * 1.5) return;

            libWheelResetTimer.restart();
            wheelHandler.accumulatedX += dx;

            if (wheelHandler.accumulatedX < -14) {
                root.nextWidget();
                wheelHandler.accumulatedX = 0;
                wheelHandler.gestureLocked = true;
                event.accepted = true;
            } else if (wheelHandler.accumulatedX > 14) {
                root.prevWidget();
                wheelHandler.accumulatedX = 0;
                wheelHandler.gestureLocked = true;
                event.accepted = true;
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
        opacity: 1.0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // ── Minimal Top Navigation Bar ──────────────────────────────────
        Item {
            id: topNavBar
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: 24

                // Dot pagination indicator & counter
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: root.widgetCount

                        Rectangle {
                            readonly property int dotIndex: index
                            width: dotIndex === root.currentIndex ? 14 : 4
                            height: 4
                            radius: 2
                            color: dotIndex === root.currentIndex ? "#ffffff" : (dotMouse.containsMouse ? "#636366" : "#38383a")

                            Behavior on width {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 180 }
                            }

                            MouseArea {
                                id: dotMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.triggerSwitch(parent.dotIndex, parent.dotIndex > root.currentIndex ? 1 : -1)
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
                            color: isSelected ? "#29ffffff" : (modeMouse.containsMouse ? "#14ffffff" : "transparent")
                            border.width: 1
                            border.color: isSelected ? "#38ffffff" : "#0fffffff"

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                font.weight: parent.isSelected ? Font.Bold : Font.Normal
                                color: parent.isSelected ? "#ffffff" : "#77777c"
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
                anchors.top: topNavBar.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                height: 74
                radius: 14
                color: "#0d0d0f"
                border.width: 1
                border.color: "#1e1e22"

                Behavior on anchors.topMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // Touch / Mouse Drag to swipe left/right
                MouseArea {
                    id: swipeArea
                    anchors.fill: parent
                    property real startX: 0
                    property bool moved: false

                    onPressed: (mouse) => {
                        startX = mouse.x;
                        moved = false;
                        dragSettleAnim.stop();
                    }
                    onPositionChanged: (mouse) => {
                        const dx = mouse.x - startX;
                        if (Math.abs(dx) > 6) {
                            moved = true;
                            if (!switchSequence.running) {
                                root.animOffset = Math.max(-160, Math.min(160, dx * 0.7));
                                root.animOpacity = Math.max(0.65, 1.0 - Math.abs(root.animOffset) / 360.0);
                            }
                        }
                    }
                    onReleased: (mouse) => {
                        const dx = mouse.x - startX;
                        if (moved && Math.abs(dx) > 28) {
                            if (dx < 0)
                                root.nextWidget();
                            else
                                root.prevWidget();
                        } else if (moved) {
                            dragSettleAnim.restart();
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

                    // Title and description with smooth transition animation
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 136
                        height: parent.height
                        clip: true

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 3
                            x: root.animOffset
                            opacity: root.animOpacity

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
                    }

                    // Add button: Icon only!
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: root.currentSupportsTargetMode
                            ? (addMouse.pressed ? "#3dffffff" : (addMouse.containsMouse ? "#29ffffff" : "#1affffff"))
                            : "#0affffff"
                        border.width: 1
                        border.color: root.currentSupportsTargetMode ? (addMouse.containsMouse ? "#40ffffff" : "#1fffffff") : "#0fffffff"
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
            anchors.top: widgetCard.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: stagingSection.top
            anchors.bottomMargin: root.isDraggingWidget ? 8 : 14
            contentWidth: width
            contentHeight: previewsColumn.implicitHeight
            clip: !root.isDraggingWidget
            boundsBehavior: Flickable.StopAtBounds
            z: 20

            Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                id: previewsColumn
                width: previewsFlickable.width
                spacing: 10
                x: Math.round(root.animOffset * 1.25)
                opacity: root.animOpacity

                Repeater {
                    model: {
                        if (!root.currentWidget) return [];
                        const list = [];
                        if (root.currentSupportsFull) {
                            const span = root.currentWidget.defaultSlotSpan || 1;
                            list.push({
                                type: "full",
                                source: root.currentWidget.fullComponent,
                                itemHeight: 134,
                                cardWidth: span >= 2 ? Math.min(previewsColumn.width, 520) : Math.min(previewsColumn.width, 320),
                                cardHeight: 130,
                                cardRadius: 16,
                                slotSpan: span
                            });
                        }
                        if (root.currentSupportsMinimum) {
                            list.push({
                                type: "minimum",
                                source: root.currentWidget.minimumComponent,
                                itemHeight: 44,
                                cardWidth: Math.min(previewsColumn.width - 24, 260),
                                cardHeight: 38,
                                cardRadius: 19,
                                slotSpan: 1
                            });
                        }
                        if (root.currentSupportsCircle) {
                            list.push({
                                type: "circle",
                                source: root.currentWidget.circleComponent,
                                itemHeight: 74,
                                cardWidth: 68,
                                cardHeight: 68,
                                cardRadius: 34,
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
                        z: cardMouse.dragging ? 100 : 1

                        Rectangle {
                            id: cardRect
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: previewDelegate.modelData.cardWidth
                            height: previewDelegate.modelData.cardHeight
                            radius: previewDelegate.modelData.cardRadius
                            color: "#08080a"
                            border.width: 1
                            border.color: cardMouse.containsMouse ? "#40ffffff" : "#14ffffff"
                            scale: cardMouse.dragging ? 1.04 : 1.0
                            clip: true
                            z: cardMouse.dragging ? 100 : 1

                            property real dragOffsetX: 0
                            property real dragOffsetY: 0

                            transform: Translate {
                                x: cardRect.dragOffsetX
                                y: cardRect.dragOffsetY
                            }

                            ParallelAnimation {
                                id: returnAnimation
                                NumberAnimation { target: cardRect; property: "dragOffsetX"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { target: cardRect; property: "dragOffsetY"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                            }

                            Behavior on scale { NumberAnimation { duration: 120 } }

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

                            // Interactive Drag & Direct Click Handler
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                preventStealing: dragging
                                propagateComposedEvents: true

                                property real grabPointerInBgX: 0
                                property real grabPointerInBgY: 0
                                property real cardStartInBgX: 0
                                property real cardStartInBgY: 0
                                property real grabOffsetX: 0
                                property real grabOffsetY: 0
                                property bool dragging: false
                                property bool wasDragging: false

                                onPressed: (mouse) => {
                                    if (mouse.button !== Qt.LeftButton) return;
                                    returnAnimation.stop();
                                    cardRect.dragOffsetX = 0;
                                    cardRect.dragOffsetY = 0;
                                    dragging = false;
                                    wasDragging = false;
                                    const pInBg = cardMouse.mapToItem(bg, mouse.x, mouse.y);
                                    grabPointerInBgX = pInBg.x;
                                    grabPointerInBgY = pInBg.y;
                                    const cInBg = cardRect.mapToItem(bg, 0, 0);
                                    cardStartInBgX = cInBg.x;
                                    cardStartInBgY = cInBg.y;
                                    grabOffsetX = pInBg.x - cInBg.x;
                                    grabOffsetY = pInBg.y - cInBg.y;
                                }

                                onPositionChanged: (mouse) => {
                                    if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) return;
                                    const curPInBg = cardMouse.mapToItem(bg, mouse.x, mouse.y);
                                    const totalDx = curPInBg.x - grabPointerInBgX;
                                    const totalDy = curPInBg.y - grabPointerInBgY;
                                    if (!dragging && (Math.abs(totalDx) > 4 || Math.abs(totalDy) > 4)) {
                                        dragging = true;
                                        wasDragging = true;
                                        root.isDraggingWidget = true;
                                        previewsFlickable.interactive = false;
                                    }
                                    if (dragging) {
                                        const rawX = curPInBg.x - grabOffsetX;
                                        const rawY = curPInBg.y - grabOffsetY;
                                        const minX = 12;
                                        const maxX = Math.max(minX, bg.width - cardRect.width - 12);
                                        const minY = 12;
                                        const maxY = Math.max(minY, bg.height - cardRect.height - 12);
                                        const clampedX = Math.max(minX, Math.min(maxX, rawX));
                                        const clampedY = Math.max(minY, Math.min(maxY, rawY));
                                        cardRect.dragOffsetX = clampedX - cardStartInBgX;
                                        cardRect.dragOffsetY = clampedY - cardStartInBgY;

                                        const cardCenterInBg = Qt.point(clampedX + cardRect.width / 2, clampedY + cardRect.height / 2);
                                        const sPosInBg = stagingSection.mapToItem(bg, 0, 0);
                                        stagingSection.isHovered = (
                                            (cardCenterInBg.y >= sPosInBg.y - 20 &&
                                             cardCenterInBg.x >= sPosInBg.x - 20 &&
                                             cardCenterInBg.x <= sPosInBg.x + stagingSection.width + 20) ||
                                            (curPInBg.y >= sPosInBg.y - 20 &&
                                             curPInBg.x >= sPosInBg.x - 20 &&
                                             curPInBg.x <= sPosInBg.x + stagingSection.width + 20)
                                        );
                                    }
                                }

                                onReleased: (mouse) => {
                                    previewsFlickable.interactive = true;
                                    if (dragging) {
                                        const currentCardX = cardStartInBgX + cardRect.dragOffsetX;
                                        const currentCardY = cardStartInBgY + cardRect.dragOffsetY;
                                        const cardCenterInBg = Qt.point(currentCardX + cardRect.width / 2, currentCardY + cardRect.height / 2);
                                        const curPInBg = cardMouse.mapToItem(bg, mouse.x, mouse.y);
                                        const sPosInBg = stagingSection.mapToItem(bg, 0, 0);
                                        const droppedInStaging = stagingSection.isHovered ||
                                            (cardCenterInBg.y >= sPosInBg.y - 20 &&
                                             cardCenterInBg.x >= sPosInBg.x - 20 &&
                                             cardCenterInBg.x <= sPosInBg.x + stagingSection.width + 20) ||
                                            (curPInBg.y >= sPosInBg.y - 20 &&
                                             curPInBg.x >= sPosInBg.x - 20 &&
                                             curPInBg.x <= sPosInBg.x + stagingSection.width + 20);

                                        if (droppedInStaging) {
                                            root.widgetStaged(
                                                root.currentWidget.id,
                                                previewDelegate.modelData.type,
                                                previewDelegate.modelData.slotSpan || 1
                                            );
                                            stagingSection.isHovered = false;
                                            dragging = false;
                                            root.isDraggingWidget = false;
                                            cardRect.dragOffsetX = 0;
                                            cardRect.dragOffsetY = 0;
                                            root.closeRequested();
                                            return;
                                        }

                                        stagingSection.isHovered = false;
                                        dragging = false;
                                        root.isDraggingWidget = false;
                                        returnAnimation.restart();
                                    }
                                }

                                onCanceled: {
                                    previewsFlickable.interactive = true;
                                    if (dragging) {
                                        stagingSection.isHovered = false;
                                        dragging = false;
                                        root.isDraggingWidget = false;
                                        returnAnimation.restart();
                                    }
                                }

                                onClicked: (mouse) => {
                                    if (!wasDragging && !dragging && mouse.button === Qt.LeftButton && root.currentWidget && userConfig) {
                                        const targetModeForType = (previewDelegate.modelData.type === "full") ? "expanded"
                                                               : (previewDelegate.modelData.type === "minimum") ? "minimum" : "circle";
                                        const targetPage = (root.targetMode === targetModeForType) ? root.targetPageIndex : 0;
                                        const targetSlot = (root.targetMode === targetModeForType) ? root.targetSlotIndex : 0;
                                        userConfig.setSlotWidget(
                                            targetModeForType,
                                            targetPage,
                                            targetSlot,
                                            root.currentWidget.id,
                                            previewDelegate.modelData.slotSpan || 1
                                        );
                                        root.widgetSelected(root.currentWidget.id);
                                        root.closeRequested();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Staging Drop Section (Clean bottom area with notch background & "Drop here") ────
        Rectangle {
            id: stagingSection
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isDraggingWidget ? 14 : 0
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: root.isDraggingWidget ? 50 : 0
            visible: height > 0
            clip: true
            radius: 16
            color: isHovered ? "#14ffffff" : "#08ffffff"
            border.width: 1.5
            border.color: isHovered ? "#47ffffff" : "#1affffff"
            opacity: root.isDraggingWidget ? 1.0 : 0.0
            property bool isHovered: false
            z: 10

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

            Text {
                anchors.centerIn: parent
                text: "Drop here"
                font.family: root.textFontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: stagingSection.isHovered ? "#ffffff" : "#8e8e93"
            }
        }
    }
}
