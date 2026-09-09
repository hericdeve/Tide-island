import QtQuick
import IslandBackend
import "../widgets"

// Closed notch (pill/notch mode) widget layer.
// Reads widgetLayouts.minimum and renders Minimum-size widgets.
// Features unified horizontal swipe navigation matching expanded notch:
// DragHandler, WheelHandler, and MultiPointTouchArea with velocity and rubber-banding.
Item {
    id: root

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property int batteryCapacity: -1
    property bool isCharging: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property real trackProgress: 0
    property string currentTime: "00:00"
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"
    property string heroFontFamily: "Sans Serif"

    // Current page tracking & animation
    property int currentPage: {
        const minL = (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.minimum) ? userConfig.widgetLayouts.minimum : null;
        return (minL && minL.activePageIndex !== undefined) ? minL.activePageIndex : 0;
    }
    property alias currentPageIndex: root.currentPage
    property real pageProgress: 0
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

    onPageProgressChanged: {
        root.dotsVisible = true;
        dotsFadeTimer.restart();
    }

    onIsEditModeChanged: {
        root.dotsVisible = true;
        if (isEditMode) {
            dotsFadeTimer.stop();
        } else {
            dotsFadeTimer.restart();
            if (currentPage >= realPageCount) {
                settlePage(Math.max(0, realPageCount - 1));
            }
        }
    }

    // Hold-to-add-page progress (0.0 to 1.0)
    property real holdProgress: 0.0

    signal expandRequested()
    signal widgetLibraryRequested(string mode, int pageIndex, int slotIndex)
    signal pageChanged(int newPage)

    readonly property var minimumLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.minimum)
        ? userConfig.widgetLayouts.minimum : null
    readonly property var minimumPages: minimumLayouts ? (minimumLayouts.pages || []) : []
    readonly property int realPageCount: Math.max(1, minimumPages.length)
    readonly property int totalPageCount: realPageCount + (isEditMode ? 1 : 0)
    readonly property int pageCount: totalPageCount
    readonly property real clampedPageProgress: Math.max(0, Math.min(pageCount - 1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, width + 16)

    property real requestedContentWidth: 0
    property real requestedContentHeight: 0

    function updateActivePageRequestedSizes() {
        const curPageItem = pageStripRepeater.itemAt(root.currentPage);
        root.requestedContentWidth = (curPageItem && curPageItem.requestedContentWidth !== undefined)
            ? Number(curPageItem.requestedContentWidth) : 0;
        root.requestedContentHeight = (curPageItem && curPageItem.requestedContentHeight !== undefined)
            ? Number(curPageItem.requestedContentHeight) : 0;
    }

    function settlePage(target) {
        const clampedTarget = Math.max(0, Math.min(pageCount - 1, target));
        settleAnimation.stop();
        settleAnimation.from = pageProgress;
        settleAnimation.to = clampedTarget;
        settleAnimation.restart();
    }

    function setPageDirect(target) {
        settleAnimation.stop();
        const clamped = Math.max(0, Math.min(pageCount - 1, target));
        currentPage = clamped;
        pageProgress = clamped;
    }

    NumberAnimation {
        id: settleAnimation
        target: root
        property: "pageProgress"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root.currentPage = Math.round(root.pageProgress);
            root.pageChanged(root.currentPage);
            if (userConfig) {
                userConfig.setActivePage("minimum", root.currentPage);
            }
        }
    }

    onCurrentPageChanged: {
        root.dotsVisible = true;
        dotsFadeTimer.restart();
        if (!settleAnimation.running) {
            pageProgress = currentPage;
        }
        root.updateActivePageRequestedSizes();
    }

    // Shared context passed down into each Minimum widget
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
        currentTime: root.currentTime,
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.heroFontFamily,
        uiScale: 1.0,
        isEditMode: root.isEditMode
    })

    // Hold-to-add-page animations (matching circle mode with 250ms pause delay)
    SequentialAnimation {
        id: holdProgressAnim

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
            to: 1.05
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

    // Capsule hold progress perimeter canvas
    Canvas {
        id: holdProgressCanvas
        anchors.fill: parent
        z: 90
        visible: root.holdProgress > 0.01

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.holdProgress <= 0.01) return;
            const W = width;
            const H = height;
            const m = 2;
            const r = (H - 2 * m) / 2;
            const x1 = m + r;
            const x2 = W - m - r;
            const y1 = m;
            const y2 = H - m;
            const L = Math.max(0, x2 - x1);
            const P = 2 * L + 2 * Math.PI * r;

            ctx.beginPath();
            ctx.moveTo(W / 2, y1);
            ctx.lineTo(x2, y1);
            ctx.arc(x2, y1 + r, r, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(x1, y2);
            ctx.arc(x1, y1 + r, r, Math.PI / 2, 3 * Math.PI / 2, false);
            ctx.lineTo(W / 2, y1);
            ctx.closePath();

            ctx.lineWidth = 3;
            ctx.strokeStyle = "#d9ffffff";
            ctx.lineCap = "round";
            ctx.setLineDash([P * root.holdProgress, P]);
            ctx.stroke();
        }

        Connections {
            target: root
            function onHoldProgressChanged() {
                holdProgressCanvas.requestPaint();
            }
        }
    }

    // Interactive tap/hold area for closed pill mode:
    // - Click expands the notch (or primary action)
    // - Right-click opens widget library for minimum widgets
    // - Click & hold (with delay) adds a new page
    // - Dragging cancels hold and lets DragHandler take over for page swiping
    MouseArea {
        id: tapArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0

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
                root.widgetLibraryRequested("minimum", Math.min(root.realPageCount - 1, root.currentPage), 0);
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
                        root.settlePage(root.currentPage + 1);
                    else
                        root.settlePage(root.currentPage - 1);
                }
            } else {
                if (root.isEditMode) {
                    root.isEditMode = false;
                    if (root.currentPage >= root.realPageCount)
                        root.settlePage(Math.max(0, root.realPageCount - 1));
                } else {
                    root.expandRequested();
                }
            }
            moved = false;
        }
    }

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? 200 : 140
            easing.type: Easing.InOutQuad
        }
    }

    // 1. Interactive horizontal swipe/drag gesture handling for page switching (matching expanded notch)
    DragHandler {
        id: swipeDragHandler
        target: null
        enabled: root.pageCount > 1 && !root.isDropTargetActive
        acceptedButtons: Qt.LeftButton
        xAxis.enabled: true
        yAxis.enabled: false
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesTakeOverByAnything

        property real startPageProgress: 0
        property double swipeStartTime: 0

        onActiveChanged: {
            if (active) {
                settleAnimation.stop();
                startPageProgress = root.pageProgress;
                swipeStartTime = Date.now();
            } else {
                const elapsedMs = Math.max(16, Date.now() - swipeStartTime);
                const velocityX = activeTranslation.x / elapsedMs;

                let target = Math.round(root.pageProgress);
                if (velocityX > 0.35) {
                    target = Math.floor(root.pageProgress);
                } else if (velocityX < -0.35) {
                    target = Math.ceil(root.pageProgress);
                }
                root.settlePage(target);
            }
        }

        onActiveTranslationChanged: {
            if (active) {
                const deltaPages = -activeTranslation.x / root.pageSlideDistance;
                let newProgress = startPageProgress + deltaPages;
                if (newProgress < 0) {
                    newProgress = newProgress * 0.25;
                } else if (newProgress > root.pageCount - 1) {
                    newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
                }
                root.pageProgress = newProgress;
            }
        }
    }

    // 2. Direct multi-touch swipe support (when 2 fingers are detected on touch input)
    MultiPointTouchArea {
        id: twoFingerTouchStrip
        anchors.fill: parent
        enabled: root.pageCount > 1 && !root.isDropTargetActive
        mouseEnabled: false
        minimumTouchPoints: 2
        maximumTouchPoints: 2

        property real startTouchX: 0
        property real startPageProgress: 0

        onPressed: (touchPoints) => {
            settleAnimation.stop();
            startTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            startPageProgress = root.pageProgress;
        }

        onUpdated: (touchPoints) => {
            const currentTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            const deltaPages = -(currentTouchX - startTouchX) / root.pageSlideDistance;
            let newProgress = startPageProgress + deltaPages;
            if (newProgress < 0) {
                newProgress = newProgress * 0.25;
            } else if (newProgress > root.pageCount - 1) {
                newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
            }
            root.pageProgress = newProgress;
        }

        onReleased: (touchPoints) => {
            root.settlePage(Math.round(root.pageProgress));
        }
    }

    // 3. Wheel handler for touchpad / mouse wheel horizontal swipe cycling
    Timer {
        id: closedWheelResetTimer
        interval: 200
        repeat: false
        onTriggered: {
            closedWheelHandler.accumulated = 0;
            closedWheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: closedWheelHandler
        target: null
        orientation: Qt.Horizontal | Qt.Vertical
        acceptedDevices: PointerDevice.AllDevices
        property real accumulated: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (root.pageCount <= 1) return;
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            if (event.phase === Qt.ScrollEnd) {
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = false;
                event.accepted = true;
                return;
            }
            if (closedWheelHandler.gestureLocked) {
                closedWheelResetTimer.restart();
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

            closedWheelResetTimer.restart();
            closedWheelHandler.accumulated += dx;

            if (closedWheelHandler.accumulated < -12) {
                root.settlePage(root.currentPage + 1);
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = true;
                event.accepted = true;
            } else if (closedWheelHandler.accumulated > 12) {
                root.settlePage(root.currentPage - 1);
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = true;
                event.accepted = true;
            }
        }
    }

    // 4. Page strip: slides and fades pages interactively according to clampedPageProgress
    Item {
        id: pageStrip
        anchors.fill: parent
        clip: true

        Repeater {
            id: pageStripRepeater
            model: root.pageCount

            Item {
                id: pageDelegateItem
                readonly property int pIdx: index
                readonly property bool isOfferPage: root.isEditMode && pIdx === root.realPageCount
                readonly property var pageData: !isOfferPage ? (root.minimumPages[pIdx] || null) : null
                readonly property int slotCount: Math.max(1, Math.min(6, (pageData && pageData.slots !== undefined) ? pageData.slots : 1))
                readonly property var items: (pageData && pageData.items) ? pageData.items : []
                readonly property bool isCustomPage: pIdx > 0
                readonly property bool isPageEmpty: (items || []).length === 0

                property real requestedContentWidth: 0
                property real requestedContentHeight: 0

                function recalculateRequestedSizes() {
                    let extraWidth = 0;
                    let maxH = 0;
                    const basePageWidth = UserConfig ? UserConfig.notchClosedWidth : 185;
                    const totalSpacing = (pageDelegateItem.slotCount - 1) * 8;
                    const baseSlotWidth = Math.max(50, (basePageWidth - totalSpacing - 24) / Math.max(1, pageDelegateItem.slotCount));

                    for (let i = 0; i < pageSlotsRepeater.count; ++i) {
                        const slot = pageSlotsRepeater.itemAt(i);
                        if (slot && slot.widgetItem && slot.hasWidget) {
                            const reqW = (slot.widgetItem.requestedContentWidth !== undefined)
                                ? Number(slot.widgetItem.requestedContentWidth) : 0;
                            if (reqW > baseSlotWidth) {
                                extraWidth += (reqW - baseSlotWidth);
                            }
                            const reqH = (slot.widgetItem.requestedContentHeight !== undefined)
                                ? Number(slot.widgetItem.requestedContentHeight) : 0;
                            if (reqH > maxH) {
                                maxH = reqH;
                            }
                        }
                    }
                    pageDelegateItem.requestedContentWidth = extraWidth > 0 ? (basePageWidth + extraWidth) : 0;
                    pageDelegateItem.requestedContentHeight = maxH > 0 ? Math.max(root.height, maxH) : 0;
                }

                onRequestedContentWidthChanged: {
                    if (pageDelegateItem.pIdx === root.currentPage) {
                        root.updateActivePageRequestedSizes();
                    }
                }
                onRequestedContentHeightChanged: {
                    if (pageDelegateItem.pIdx === root.currentPage) {
                        root.updateActivePageRequestedSizes();
                    }
                }
                Component.onCompleted: {
                    if (pageDelegateItem.pIdx === root.currentPage) {
                        root.updateActivePageRequestedSizes();
                    }
                }

                readonly property real pageOffset: (pIdx - root.clampedPageProgress) * root.pageSlideDistance
                width: pageStrip.width
                height: pageStrip.height
                x: pageOffset
                opacity: Math.max(0, 1 - Math.abs(pIdx - root.clampedPageProgress))
                visible: opacity > 0.001
                enabled: pIdx === root.currentPage

                // Delete custom page button on empty custom pages
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: delCustomPageMouse.containsMouse ? "#ff453a" : "#2a2a2e"
                    z: 50
                    visible: root.isEditMode && !pageDelegateItem.isOfferPage && pageDelegateItem.isCustomPage && pageDelegateItem.isPageEmpty

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 9
                        color: "white"
                    }

                    MouseArea {
                        id: delCustomPageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const targetIdx = pageDelegateItem.pIdx;
                                userConfig.removePage("minimum", targetIdx);
                                root.settlePage(Math.max(0, targetIdx - 1));
                            }
                        }
                    }
                }

                // Horizontal row of Minimum slots for this page (hidden on offer page)
                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: root.pageCount > 1 ? -2 : 0
                    spacing: 8
                    visible: !pageDelegateItem.isOfferPage

                    Repeater {
                        id: pageSlotsRepeater
                        model: pageDelegateItem.isOfferPage ? 0 : pageDelegateItem.slotCount

                        Item {
                            id: slotItem
                            readonly property int sIdx: index
                            readonly property var placedItem: {
                                const its = pageDelegateItem.items || [];
                                for (let i = 0; i < its.length; ++i) {
                                    if (its[i] && its[i].slotIndex === sIdx)
                                        return its[i];
                                }
                                return null;
                            }
                            readonly property string widgetId: placedItem ? (placedItem.widgetId || "") : ""
                            readonly property bool hasWidget: widgetId !== ""
                            readonly property var widgetItem: widgetLoader.item

                            width: closedSlotWidth
                            height: pageStrip.height

                            readonly property real closedSlotWidth: {
                                const totalSpacing = (pageDelegateItem.slotCount - 1) * 8;
                                return Math.max(50, (pageStrip.width - totalSpacing - 24) / Math.max(1, pageDelegateItem.slotCount));
                            }

                            // 1. Populated widget container with iOS home screen editing wiggle effect
                            Item {
                                id: pillJiggleContainer
                                anchors.fill: parent
                                visible: parent.hasWidget

                                readonly property real angleAmplitude: 0.7 * (parent.sIdx % 2 === 0 ? 1.0 : -1.0)
                                readonly property int rotDuration: 150 + ((parent.sIdx * 37) % 25)
                                readonly property int transDuration: 175 + ((parent.sIdx * 43) % 30)

                                property real currentRotation: 0
                                property real xOffset: 0
                                property real yOffset: 0

                                transformOrigin: Item.Center
                                rotation: root.isEditMode ? currentRotation : 0

                                transform: Translate {
                                    x: root.isEditMode ? pillJiggleContainer.xOffset : 0
                                    y: root.isEditMode ? pillJiggleContainer.yOffset : 0
                                }

                                Loader {
                                    id: widgetLoader
                                    anchors.fill: parent
                                    enabled: false
                                    active: slotItem.hasWidget
                                    source: active ? WidgetRegistry.getComponentUrl(slotItem.widgetId, "minimum") : ""

                                    onLoaded: {
                                        if (item) {
                                            item.widgetContext = root.sharedWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = root.isEditMode;
                                        }
                                        pageDelegateItem.recalculateRequestedSizes();
                                    }
                                    onStatusChanged: {
                                        if (status === Loader.Ready && item) {
                                            item.widgetContext = root.sharedWidgetContext;
                                            item.slotSpan = 1;
                                            item.isEditMode = root.isEditMode;
                                        }
                                        pageDelegateItem.recalculateRequestedSizes();
                                    }

                                    Connections {
                                        target: widgetLoader.item
                                        ignoreUnknownSignals: true
                                        function onRequestedContentWidthChanged() { pageDelegateItem.recalculateRequestedSizes(); }
                                        function onRequestedContentHeightChanged() { pageDelegateItem.recalculateRequestedSizes(); }
                                    }
                                }

                                // Remove widget button in edit mode
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.topMargin: 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: 2
                                    width: 13
                                    height: 13
                                    radius: 6.5
                                    color: removePillWidgetMouse.containsMouse ? "#ff453a" : "#40000000"
                                    border.width: 1
                                    border.color: "#55ffffff"
                                    visible: root.isEditMode
                                    z: 99

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 8
                                        color: "white"
                                    }

                                    MouseArea {
                                        id: removePillWidgetMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (userConfig) {
                                                userConfig.removeSlotWidget("minimum", pageDelegateItem.pIdx, parent.parent.sIdx);
                                            }
                                        }
                                    }
                                }

                                // Rotation wiggle animation
                                SequentialAnimation {
                                    running: root.isEditMode && parent.hasWidget
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        target: pillJiggleContainer
                                        property: "currentRotation"
                                        from: -pillJiggleContainer.angleAmplitude
                                        to: pillJiggleContainer.angleAmplitude
                                        duration: pillJiggleContainer.rotDuration
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: pillJiggleContainer
                                        property: "currentRotation"
                                        from: pillJiggleContainer.angleAmplitude
                                        to: -pillJiggleContainer.angleAmplitude
                                        duration: pillJiggleContainer.rotDuration
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                // Translation wiggle animation
                                SequentialAnimation {
                                    running: root.isEditMode && parent.hasWidget
                                    loops: Animation.Infinite

                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: pillJiggleContainer
                                            property: "xOffset"
                                            from: -(parent.sIdx % 2 === 0 ? 0.35 : -0.35)
                                            to: (parent.sIdx % 2 === 0 ? 0.35 : -0.35)
                                            duration: pillJiggleContainer.transDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            target: pillJiggleContainer
                                            property: "yOffset"
                                            from: -0.45
                                            to: 0.45
                                            duration: Math.round(pillJiggleContainer.transDuration * 1.08)
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: pillJiggleContainer
                                            property: "xOffset"
                                            from: (parent.sIdx % 2 === 0 ? 0.35 : -0.35)
                                            to: -(parent.sIdx % 2 === 0 ? 0.35 : -0.35)
                                            duration: pillJiggleContainer.transDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            target: pillJiggleContainer
                                            property: "yOffset"
                                            from: 0.45
                                            to: -0.45
                                            duration: Math.round(pillJiggleContainer.transDuration * 1.08)
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }

                            // Empty slot button in closed mode (prominent button to add a new widget)
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 8, 72)
                                height: 20
                                radius: 10
                                color: emptySlotMouse.containsMouse ? "#30ffffff" : (root.isEditMode ? "#22ffffff" : "#14ffffff")
                                border.width: 1
                                border.color: emptySlotMouse.containsMouse ? "#55ffffff" : (root.isEditMode ? "#3affffff" : "#22ffffff")
                                visible: !parent.hasWidget && root.isEditMode
                                z: 20

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰐕"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: 10
                                        color: "#ffffff"
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Add"
                                        font.family: root.textFontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        color: emptySlotMouse.containsMouse ? "#ffffff" : "#c4c4c8"
                                    }
                                }

                                MouseArea {
                                    id: emptySlotMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.widgetLibraryRequested("minimum", pageDelegateItem.pIdx, parent.sIdx);
                                    }
                                }
                            }

                            // Empty slot placeholder in closed mode when NOT in edit mode — subtle dash
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 8, 32)
                                height: 2
                                radius: 1
                                color: "#48484a"
                                visible: !parent.hasWidget && !root.isEditMode
                            }
                        }
                    }
                }

                // Offer Page Card at the end (shown in edit mode offering to add that last page)
                Rectangle {
                    id: pillOfferCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, 115)
                    height: 22
                    radius: 11
                    color: addPillPageMouse.containsMouse ? "#38ffffff" : "#20ffffff"
                    border.width: 1
                    border.color: addPillPageMouse.containsMouse ? "#77ffffff" : "#44ffffff"
                    visible: pageDelegateItem.isOfferPage && pageDelegateItem.pIdx === root.currentPage
                    enabled: pageDelegateItem.isOfferPage && pageDelegateItem.pIdx === root.currentPage
                    z: 30

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 11
                            color: "#ffffff"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Page"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: addPillPageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const newPageIndex = root.realPageCount;
                                const nextTitle = "Page " + (newPageIndex + 1);
                                userConfig.addPage("minimum", nextTitle, 1);
                                root.settlePage(newPageIndex);
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Page indicator dots (visible when > 1 page, fades out after 2.5s)
    Row {
        id: pageDotsRow
        visible: root.pageCount > 1
        opacity: (root.dotsVisible || root.isEditMode) ? 1.0 : 0.0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2.5
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        z: 10

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }

        Repeater {
            model: root.pageCount

            Rectangle {
                readonly property int dotIndex: index
                readonly property bool isOfferDot: root.isEditMode && dotIndex === root.realPageCount
                readonly property bool isActive: dotIndex === root.currentPage
                width: isActive ? 12 : 4
                height: 3.5
                radius: 1.75
                color: isActive ? "#ffffff" : (isOfferDot ? "#66ffffff" : "#48484a")
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
                    onClicked: root.settlePage(dotIndex)
                }
            }
        }
    }

    // Drop target highlight when dragging a minimum widget over closed pill
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.5
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
}
