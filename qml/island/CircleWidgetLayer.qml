import QtQuick
import IslandBackend
import "../widgets"

// Circle mode widget layer.
// Reads widgetLayouts.circle and renders Circle-size widgets.
// Replaces the hardcoded CircleClosedLayer.
Item {
    id: root

    signal expandRequested()
    signal widgetLibraryRequested(string mode, int pageIndex, int slotIndex)

    readonly property var userConfig: UserConfig

    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property real trackProgress: 0
    property int batteryCapacity: -1
    property bool isCharging: false
    property real currentCpuUsage: 0
    property real currentRamUsage: 0
    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    property int currentPageIndex: {
        const circL = (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.circle) ? userConfig.widgetLayouts.circle : null;
        return (circL && circL.activePageIndex !== undefined) ? circL.activePageIndex : 0;
    }
    property bool isDropTargetActive: false
    property bool dotsVisible: true
    property bool isEditMode: false

    Timer {
        id: dotsFadeTimer
        interval: 2500
        repeat: false
        running: true
        onTriggered: root.dotsVisible = false
    }

    onCurrentPageIndexChanged: {
        root.dotsVisible = true;
        dotsFadeTimer.restart();
        if (userConfig) {
            userConfig.setActivePage("circle", currentPageIndex);
        }
        root.updateActivePageRequestedSizes();
    }

    onIsEditModeChanged: {
        root.dotsVisible = true;
        if (isEditMode) {
            dotsFadeTimer.stop();
        } else {
            dotsFadeTimer.restart();
            if (currentPageIndex >= realPageCount) {
                currentPageIndex = Math.max(0, realPageCount - 1);
            }
        }
    }

    // Hold-to-add-page progress (0.0 to 1.0)
    property real holdProgress: 0.0

    function setPageDirect(target) {
        const clamped = Math.max(0, Math.min(pageCount - 1, target));
        currentPageIndex = clamped;
    }

    readonly property real circleDiameter: Math.min(width, height)
    readonly property real faceScale: Math.max(0.5, Math.min(1.0, 0.62 + (circleDiameter - 44.0) * 0.008))

    readonly property var circleLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.circle)
        ? userConfig.widgetLayouts.circle : null
    readonly property var circlePages: circleLayouts ? (circleLayouts.pages || []) : []
    readonly property int realPageCount: Math.max(1, circlePages.length)
    readonly property int totalPageCount: realPageCount + (isEditMode ? 1 : 0)
    readonly property int pageCount: totalPageCount

    property real requestedContentWidth: 0
    property real requestedContentHeight: 0

    function updateActivePageRequestedSizes() {
        const curPage = circlePageRepeater.itemAt(root.currentPageIndex);
        root.requestedContentWidth = (curPage && curPage.requestedContentWidth !== undefined)
            ? Number(curPage.requestedContentWidth) : 0;
        root.requestedContentHeight = (curPage && curPage.requestedContentHeight !== undefined)
            ? Number(curPage.requestedContentHeight) : 0;
    }

    // Shared context passed into each Circle widget
    readonly property var sharedWidgetContext: ({
        activePlayer: null,
        currentTrack: root.currentTrack,
        currentArtist: root.currentArtist,
        currentArtUrl: root.currentArtUrl,
        isPlaying: root.isPlaying,
        trackProgress: root.trackProgress,
        timePlayed: "0:00",
        timeTotal: "0:00",
        batteryCapacity: root.batteryCapacity,
        isCharging: root.isCharging,
        currentCpuUsage: root.currentCpuUsage,
        currentRamUsage: root.currentRamUsage,
        currentTime: root.currentTime,
        currentDateLabel: root.currentDateLabel,
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.textFontFamily,
        faceScale: root.faceScale,
        circleDiameter: root.circleDiameter,
        uiScale: root.faceScale,
        isEditMode: root.isEditMode
    })

    anchors.fill: parent
    clip: true

    // Auto-advance to media widget page when music starts (if media_player is on a circle page)
    onCurrentTrackChanged: {
        if (currentTrack !== "") {
            for (let i = 0; i < circlePages.length; ++i) {
                const pg = circlePages[i];
                if (pg && pg.items) {
                    for (let j = 0; j < pg.items.length; ++j) {
                        if (pg.items[j].widgetId === "media_player") {
                            root.currentPageIndex = i;
                            return;
                        }
                    }
                }
            }
        }
    }

    // Gesture navigation
    readonly property real swipeDistanceThreshold: 95

    Timer {
        id: wheelResetTimer
        interval: 420
        repeat: false
        onTriggered: {
            circleWheelHandler.accumulated = 0;
            circleWheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: circleWheelHandler
        target: null
        orientation: Qt.Horizontal | Qt.Vertical
        acceptedDevices: PointerDevice.AllDevices
        property real accumulated: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            if (event.phase === Qt.ScrollEnd) {
                circleWheelHandler.accumulated = 0;
                circleWheelHandler.gestureLocked = false;
                event.accepted = true;
                return;
            }
            if (circleWheelHandler.gestureLocked) {
                wheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            const rawAx = (event.angleDelta && event.angleDelta.x !== undefined) ? event.angleDelta.x : 0;
            const rawAy = (event.angleDelta && event.angleDelta.y !== undefined) ? event.angleDelta.y : 0;
            const px = (event.pixelDelta && event.pixelDelta.x !== undefined) ? event.pixelDelta.x : 0;
            const py = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0;
            const ax = rawAx / 5;
            const ay = rawAy / 5;

            // Discrete mouse wheel notches are multiples of 120 with zero pixelDelta
            const isDiscreteWheel = (Math.abs(px) < 0.001 && Math.abs(py) < 0.001) &&
                                    ((rawAx !== 0 && Math.abs(rawAx) % 120 === 0) || (rawAy !== 0 && Math.abs(rawAy) % 120 === 0));
            const threshold = isDiscreteWheel ? 20 : root.swipeDistanceThreshold;

            const dx = Math.abs(px) > 0.001 ? px : ax;
            const dy = Math.abs(py) > 0.001 ? py : ay;
            const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;

            if (Math.abs(delta) < 0.5) return;

            root.dotsVisible = true;
            dotsFadeTimer.restart();

            wheelResetTimer.restart();
            accumulated += delta;

            if (accumulated < -threshold) {
                root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                accumulated = 0;
                gestureLocked = true;
                event.accepted = true;
            } else if (accumulated > threshold) {
                root.currentPageIndex = Math.max(0, root.currentPageIndex - 1);
                accumulated = 0;
                gestureLocked = true;
                event.accepted = true;
            }
        }
    }

    SequentialAnimation {
        id: holdProgressAnim

        // Delay before radial progress starts filling — prevents progress ring from flashing on quick clicks
        PauseAnimation {
            duration: 250
        }

        NumberAnimation {
            target: root
            property: "holdProgress"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.Linear
        }

        ScriptAction {
            script: {
                if (tapArea.pressed && !tapArea.moved) {
                    tapArea.isHoldTriggered = true;
                    root.holdProgress = 0.0;
                    if (!root.isEditMode) {
                        root.isEditMode = true;
                    }
                    popAnim.restart();
                }
            }
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.08
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: 150
            easing.type: Easing.OutBack
        }
    }

    // Circular hold progress ring canvas
    Canvas {
        id: holdProgressCanvas
        anchors.fill: parent
        z: 90
        visible: root.holdProgress > 0.01

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.holdProgress <= 0.01) return;
            const center = width / 2;
            const radius = Math.max(8, center - 3);
            ctx.beginPath();
            ctx.arc(center, center, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * root.holdProgress, false);
            ctx.lineWidth = 3;
            ctx.strokeStyle = "#d9ffffff";
            ctx.lineCap = "round";
            ctx.stroke();
        }

        Connections {
            target: root
            function onHoldProgressChanged() {
                holdProgressCanvas.requestPaint();
            }
        }
    }

    // Drop target highlight when dragging a circle widget over circle mode
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: "#66ffffff"
        visible: root.isDropTargetActive
        z: 95

        SequentialAnimation on border.color {
            running: root.isDropTargetActive
            loops: Animation.Infinite
            ColorAnimation { from: "#59ffffff"; to: "#bfffffff"; duration: 600 }
            ColorAnimation { from: "#bfffffff"; to: "#59ffffff"; duration: 600 }
        }
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startX: 0
        property real startY: 0
        property bool moved: false
        property bool isHoldTriggered: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                return;
            }
            startX = mouse.x;
            startY = mouse.y;
            moved = false;
            isHoldTriggered = false;
            root.holdProgress = 0.0;
            holdProgressAnim.restart();
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons & Qt.LeftButton) {
                if (Math.abs(mouse.x - startX) > 8 || Math.abs(mouse.y - startY) > 8) {
                    moved = true;
                    root.dotsVisible = true;
                    dotsFadeTimer.restart();
                    holdProgressAnim.stop();
                    root.holdProgress = 0.0;
                }
            }
        }

        onCanceled: {
            holdProgressAnim.stop();
            root.holdProgress = 0.0;
            moved = false;
            isHoldTriggered = false;
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.widgetLibraryRequested("circle", Math.min(root.realPageCount - 1, root.currentPageIndex), 0);
                return;
            }
            holdProgressAnim.stop();
            root.holdProgress = 0.0;
            if (isHoldTriggered) {
                isHoldTriggered = false;
                moved = false;
                return;
            }

            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (moved) {
                if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 12) {
                    if (dx < 0)
                        root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                    else
                        root.currentPageIndex = Math.max(0, root.currentPageIndex - 1);
                }
            } else {
                if (root.isEditMode) {
                    root.isEditMode = false;
                    if (root.currentPageIndex >= root.realPageCount)
                        root.currentPageIndex = Math.max(0, root.realPageCount - 1);
                } else {
                    root.expandRequested();
                }
            }
            moved = false;
        }
    }

    // Widget faces — each page renders its widget filling the circle (or Add Widget, or Offer Page)
    Repeater {
        id: circlePageRepeater
        model: root.pageCount

        Item {
            id: pageItem
            readonly property int pIdx: index
            readonly property bool isOfferPage: root.isEditMode && pIdx === root.realPageCount
            readonly property var pageData: !isOfferPage ? (root.circlePages[pIdx] || null) : null
            readonly property var items: (pageData && pageData.items) ? pageData.items : []
            readonly property var firstItem: items.length > 0 ? items[0] : null
            readonly property string widgetId: firstItem ? (firstItem.widgetId || "") : ""
            readonly property bool hasWidget: !isOfferPage && widgetId !== ""
            readonly property bool isDeletePageAction: !hasWidget && pIdx > 0
            readonly property bool isRemoveWidgetAction: hasWidget
            readonly property bool showTopButton: root.isEditMode && !isOfferPage && (isRemoveWidgetAction || isDeletePageAction)
            readonly property var widgetItem: pageWidgetLoader.item
            property real requestedContentWidth: 0
            property real requestedContentHeight: 0

            function updatePageRequestedSizes() {
                pageItem.requestedContentWidth = (widgetItem && widgetItem.requestedContentWidth !== undefined)
                    ? Number(widgetItem.requestedContentWidth) : 0;
                pageItem.requestedContentHeight = (widgetItem && widgetItem.requestedContentHeight !== undefined)
                    ? Number(widgetItem.requestedContentHeight) : 0;
                if (pageItem.pIdx === root.currentPageIndex) {
                    root.updateActivePageRequestedSizes();
                }
            }

            onRequestedContentWidthChanged: {
                if (pageItem.pIdx === root.currentPageIndex) {
                    root.updateActivePageRequestedSizes();
                }
            }
            onRequestedContentHeightChanged: {
                if (pageItem.pIdx === root.currentPageIndex) {
                    root.updateActivePageRequestedSizes();
                }
            }
            Component.onCompleted: {
                if (pageItem.pIdx === root.currentPageIndex) {
                    root.updateActivePageRequestedSizes();
                }
            }

            anchors.fill: parent
            opacity: pIdx === root.currentPageIndex ? 1.0 : 0.0
            visible: pIdx === root.currentPageIndex || opacity > 0.001
            enabled: pIdx === root.currentPageIndex

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }

            onVisibleChanged: {
                if (visible && pageWidgetLoader.item && typeof pageWidgetLoader.item.requestPaint === "function") {
                    pageWidgetLoader.item.requestPaint();
                }
            }

            Connections {
                target: root
                function onCurrentPageIndexChanged() {
                    if (pageItem.pIdx === root.currentPageIndex && pageWidgetLoader.item) {
                        if (typeof pageWidgetLoader.item.requestPaint === "function") {
                            pageWidgetLoader.item.requestPaint();
                        }
                    }
                }
            }

            // Top action button in edit mode:
            // - When page has a widget: removes widget (standard dark color, red on hover)
            // - When custom page has no widget: deletes page (RED color)
            Rectangle {
                id: topActionBtn
                anchors.top: parent.top
                anchors.topMargin: 2
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 14
                height: 14
                radius: 7
                z: 99
                visible: pageItem.showTopButton

                color: pageItem.isDeletePageAction
                    ? (topActionMouse.containsMouse ? "#ff6961" : "#ff453a")
                    : (topActionMouse.containsMouse ? "#ff453a" : "#40000000")
                border.width: 1
                border.color: pageItem.isDeletePageAction
                    ? (topActionMouse.containsMouse ? "#ffffff" : "#ff9f9a")
                    : "#55ffffff"

                transformOrigin: Item.Center
                rotation: (root.isEditMode && pageItem.hasWidget) ? circleJiggleContainer.currentRotation : 0
                transform: Translate {
                    x: (root.isEditMode && pageItem.hasWidget) ? circleJiggleContainer.xOffset : 0
                    y: (root.isEditMode && pageItem.hasWidget) ? circleJiggleContainer.yOffset : 0
                }

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: root.iconFontFamily
                    font.pixelSize: 8
                    color: "white"
                }

                MouseArea {
                    id: topActionMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!userConfig) return;
                        if (pageItem.isDeletePageAction) {
                            const targetIdx = pageItem.pIdx;
                            userConfig.removePage("circle", targetIdx);
                            root.currentPageIndex = Math.max(0, targetIdx - 1);
                        } else if (pageItem.isRemoveWidgetAction) {
                            userConfig.removeSlotWidget("circle", pageItem.pIdx, 0);
                        }
                    }
                }
            }

            // 1. Populated widget container with iOS home screen editing wiggle effect
            Item {
                id: circleJiggleContainer
                anchors.fill: parent
                visible: pageItem.hasWidget

                readonly property real angleAmplitude: 1.2 * (pageItem.pIdx % 2 === 0 ? 1.0 : -1.0)
                readonly property int rotDuration: 145 + ((pageItem.pIdx * 33) % 25)
                readonly property int transDuration: 170 + ((pageItem.pIdx * 41) % 30)

                property real currentRotation: 0
                property real xOffset: 0
                property real yOffset: 0

                transformOrigin: Item.Center
                rotation: root.isEditMode ? currentRotation : 0

                transform: Translate {
                    x: root.isEditMode ? circleJiggleContainer.xOffset : 0
                    y: root.isEditMode ? circleJiggleContainer.yOffset : 0
                }

                Loader {
                    id: pageWidgetLoader
                    anchors.fill: parent
                    enabled: false
                    active: pageItem.hasWidget
                    source: active ? WidgetRegistry.getComponentUrl(pageItem.widgetId, "circle") : ""

                    onLoaded: {
                        if (item) {
                            item.widgetContext = root.sharedWidgetContext;
                            item.slotSpan = 1;
                            item.isEditMode = root.isEditMode;
                            if (typeof item.requestPaint === "function") {
                                item.requestPaint();
                            }
                        }
                        pageItem.updatePageRequestedSizes();
                    }
                    onStatusChanged: {
                        if (status === Loader.Ready && item) {
                            item.widgetContext = root.sharedWidgetContext;
                            item.slotSpan = 1;
                            item.isEditMode = root.isEditMode;
                            if (typeof item.requestPaint === "function") {
                                item.requestPaint();
                            }
                        }
                        pageItem.updatePageRequestedSizes();
                    }

                    Connections {
                        target: pageWidgetLoader.item
                        ignoreUnknownSignals: true
                        function onRequestedContentWidthChanged() { pageItem.updatePageRequestedSizes(); }
                        function onRequestedContentHeightChanged() { pageItem.updatePageRequestedSizes(); }
                    }
                }

                Binding {
                    target: pageWidgetLoader.item
                    property: "isEditMode"
                    value: root.isEditMode
                    when: pageWidgetLoader.item !== null
                }
                Binding {
                    target: pageWidgetLoader.item
                    property: "widgetContext"
                    value: root.sharedWidgetContext
                    when: pageWidgetLoader.item !== null
                }

                // Rotation wiggle animation
                SequentialAnimation {
                    running: root.isEditMode && pageItem.hasWidget
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: circleJiggleContainer
                        property: "currentRotation"
                        from: -circleJiggleContainer.angleAmplitude
                        to: circleJiggleContainer.angleAmplitude
                        duration: circleJiggleContainer.rotDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: circleJiggleContainer
                        property: "currentRotation"
                        from: circleJiggleContainer.angleAmplitude
                        to: -circleJiggleContainer.angleAmplitude
                        duration: circleJiggleContainer.rotDuration
                        easing.type: Easing.InOutSine
                    }
                }

                // Translation wiggle animation
                SequentialAnimation {
                    running: root.isEditMode && pageItem.hasWidget
                    loops: Animation.Infinite

                    ParallelAnimation {
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "xOffset"
                            from: -(pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            to: (pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            duration: circleJiggleContainer.transDuration
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "yOffset"
                            from: -0.5
                            to: 0.5
                            duration: Math.round(circleJiggleContainer.transDuration * 1.08)
                            easing.type: Easing.InOutQuad
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "xOffset"
                            from: (pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            to: -(pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            duration: circleJiggleContainer.transDuration
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "yOffset"
                            from: 0.5
                            to: -0.5
                            duration: Math.round(circleJiggleContainer.transDuration * 1.08)
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // 2. Subtle outline ring on empty pages when NOT in edit mode
            Item {
                anchors.fill: parent
                visible: !pageItem.hasWidget && !pageItem.isOfferPage && !root.isEditMode

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 2
                    height: parent.height - 2
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#28282a"
                }
            }

            // 3. Empty page state in edit mode (Home or custom page with Add Widget and Delete buttons)
            Item {
                id: customEmptyPage
                readonly property int pageIndex: pageItem.pIdx
                anchors.fill: parent
                visible: !pageItem.hasWidget && !pageItem.isOfferPage && root.isEditMode
                enabled: !pageItem.hasWidget && !pageItem.isOfferPage && root.isEditMode && pageItem.pIdx === root.currentPageIndex

                // Centered prominent Add Widget button
                Rectangle {
                    id: addBtnRect
                    anchors.centerIn: parent
                    width: Math.min(42, parent.width - 10)
                    height: width
                    radius: width / 2
                    color: addCircleWidgetMouse.containsMouse ? "#30ffffff" : "#18ffffff"
                    border.width: 1
                    border.color: addCircleWidgetMouse.containsMouse ? "#55ffffff" : "#30ffffff"
                    z: 20

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Add"
                            font.family: root.textFontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: addCircleWidgetMouse.containsMouse ? "#ffffff" : "#c4c4c8"
                        }
                    }

                    MouseArea {
                        id: addCircleWidgetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.widgetLibraryRequested("circle", pageItem.pIdx, 0);
                        }
                    }
                }
            }

            // 5. Offer Page at the end (shown in edit mode to offer adding that last page)
            Item {
                id: offerPageItem
                anchors.fill: parent
                visible: pageItem.isOfferPage && pageItem.pIdx === root.currentPageIndex
                enabled: pageItem.isOfferPage && pageItem.pIdx === root.currentPageIndex

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(42, parent.width - 10)
                    height: width
                    radius: width / 2
                    color: addCirclePageMouse.containsMouse ? "#38ffffff" : "#20ffffff"
                    border.width: 1.5
                    border.color: addCirclePageMouse.containsMouse ? "#77ffffff" : "#44ffffff"
                    z: 20

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Page"
                            font.family: root.textFontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: addCirclePageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const newPageIndex = root.realPageCount;
                                const nextTitle = "Page " + (newPageIndex + 1);
                                userConfig.addPage("circle", nextTitle, 1);
                                root.currentPageIndex = newPageIndex;
                            }
                        }
                    }
                }
            }
        }
    }

    // Page indicator dots (only when > 1 page, fades out after 2.5s)
    Row {
        id: pageDotsRow
        visible: root.pageCount > 1
        opacity: (root.dotsVisible || root.isEditMode) ? 1.0 : 0.0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3
        z: 90

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }

        Repeater {
            model: root.pageCount

            Rectangle {
                readonly property int dotIndex: index
                readonly property bool isOfferDot: root.isEditMode && dotIndex === root.realPageCount
                readonly property bool isActive: dotIndex === root.currentPageIndex
                width: isActive ? 10 : 3
                height: 3
                radius: 1.5
                color: isActive ? "white" : (isOfferDot ? "#66ffffff" : "#48484a")
                border.width: isOfferDot && !isActive ? 0.5 : 0
                border.color: "#88ffffff"

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 180 }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentPageIndex = parent.dotIndex
                }
            }
        }
    }
}
