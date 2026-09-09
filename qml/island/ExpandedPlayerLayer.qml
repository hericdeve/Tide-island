import QtQuick
import IslandBackend
import Quickshell.Services.Mpris
import "../widgets"

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal closeRequested()
    signal keyboardFocusRequested()
    signal keyboardFocusReleased()
    signal previousRequested()
    signal pageChanged(int page)
    signal shelfRequested()
    signal widgetLibraryRequested(string mode, int pageIndex, int slotIndex)
    signal timerToggleRequested(int hours, int minutes)
    signal timerResetRequested()
    signal timerDurationRequested(int hours, int minutes)

    readonly property var userConfig: UserConfig

    property int batteryCapacity: -1
    property bool isCharging: false
    property bool cameraMirrorActive: false
    property bool isEditMode: false
    property bool dynamicResizeToastOpen: false
    property int hoveredSlotIndex: -1
    property bool isDraggingWidget: false

    readonly property int currentPage: expandedPageStrip ? expandedPageStrip.currentPage : 0

    readonly property real requestedContentWidth: {
        if (!expandedPageStrip) return 0;
        const stripReqW = expandedPageStrip.requestedContentWidth;
        return stripReqW > 0 ? (stripReqW + 32) : 0;
    }

    readonly property real requestedContentHeight: {
        if (!expandedPageStrip) return 0;
        const stripReqH = expandedPageStrip.requestedContentHeight;
        return stripReqH > 0 ? (stripReqH + (statusBar ? statusBar.height : 28) + 28) : 0;
    }

    function showPage(pageIdx, immediate) {
        if (expandedPageStrip) {
            if (immediate) {
                expandedPageStrip.setPageDirect(pageIdx);
            } else {
                expandedPageStrip.settlePage(pageIdx);
            }
        }
    }

    property int initialPage: 0
    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string lyricsText: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: userConfig ? userConfig.iconFontFamily : "Sans Serif"
    property string textFontFamily: userConfig ? userConfig.textFontFamily : "Sans Serif"
    property int timerSelectedHours: 0
    property int timerSelectedMinutes: 5
    property int timerTotalSeconds: 300
    property int timerRemainingSeconds: 0
    property bool timerRunning: false
    property bool timerActive: false
    property real uiScale: userConfig ? Math.max(0.85, Math.min(1.35, (userConfig.notchOpenHeight / 190.0) * (userConfig.bodyFontSize / 16.0))) : 1.0

    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property var sharedWidgetContext: ({
        activePlayer: root.activePlayer,
        currentTrack: root.currentTrack,
        currentArtist: root.currentArtist,
        currentArtUrl: root.currentArtUrl,
        lyricsText: root.lyricsText,
        timePlayed: root.timePlayed,
        timeTotal: root.timeTotal,
        trackProgress: root.trackProgress,
        isPlaying: root.isPlaying,
        batteryCapacity: root.batteryCapacity,
        isCharging: root.isCharging,
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.userConfig ? root.userConfig.heroFontFamily : "Sans Serif",
        bodyFontSize: root.userConfig ? root.userConfig.bodyFontSize : 16,
        titleFontSize: root.userConfig ? root.userConfig.titleFontSize : 20,
        iconFontSize: root.userConfig ? root.userConfig.iconFontSize : 18,
        uiScale: root.uiScale,
        isEditMode: root.isEditMode
    })

    anchors.fill: parent
    focus: showCondition
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (!showCondition) {
            root.dynamicResizeToastOpen = false;
        }
    }

    Keys.onEscapePressed: event => {
        if (root.dynamicResizeToastOpen) {
            root.dynamicResizeToastOpen = false;
        } else if (root.isEditMode) {
            root.isEditMode = false;
        } else {
            root.closeRequested();
        }
        event.accepted = true;
    }

    Item {
        id: viewport
        anchors.fill: parent
        clip: true

        Timer {
            id: wheelResetTimer
            interval: 200
            repeat: false
            onTriggered: {
                horizontalWheelHandler.accumulated = 0;
                horizontalWheelHandler.gestureLocked = false;
            }
        }

        WheelHandler {
            id: horizontalWheelHandler
            target: null
            orientation: Qt.Horizontal | Qt.Vertical
            acceptedDevices: PointerDevice.AllDevices
            property real accumulated: 0
            property bool gestureLocked: false

            onWheel: function(event) {
                if (!expandedPageStrip || expandedPageStrip.pageCount <= 1) return;
                if (event.phase === Qt.ScrollMomentum) {
                    event.accepted = true;
                    return;
                }
                if (event.phase === Qt.ScrollEnd) {
                    horizontalWheelHandler.accumulated = 0;
                    horizontalWheelHandler.gestureLocked = false;
                    event.accepted = true;
                    return;
                }
                if (horizontalWheelHandler.gestureLocked) {
                    wheelResetTimer.restart();
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

                wheelResetTimer.restart();
                horizontalWheelHandler.accumulated += dx;

                if (horizontalWheelHandler.accumulated < -12) {
                    expandedPageStrip.settlePage(expandedPageStrip.currentPage + 1);
                    horizontalWheelHandler.accumulated = 0;
                    horizontalWheelHandler.gestureLocked = true;
                    event.accepted = true;
                } else if (horizontalWheelHandler.accumulated > 12) {
                    expandedPageStrip.settlePage(expandedPageStrip.currentPage - 1);
                    horizontalWheelHandler.accumulated = 0;
                    horizontalWheelHandler.gestureLocked = true;
                    event.accepted = true;
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 5

            // 1. Persistent Top Status Bar
            NotchStatusBar {
                id: statusBar
                width: parent.width
                pages: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.expanded) ? userConfig.widgetLayouts.expanded.pages : []
                currentPage: expandedPageStrip.currentPage
                isEditMode: root.isEditMode
                cameraMirrorActive: root.cameraMirrorActive
                dynamicResizeToastActive: root.dynamicResizeToastOpen
                batteryCapacity: root.batteryCapacity
                isCharging: root.isCharging
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily

                onPageSelected: (idx) => expandedPageStrip.settlePage(idx)
                onAddPageRequested: {
                    if (userConfig)
                        userConfig.addPage("expanded", "", 3);
                }
                onSetSlotsRequested: (pIdx, sCount) => {
                    if (userConfig)
                        userConfig.setPageSlots("expanded", pIdx, sCount);
                }
                onShelfRequested: root.shelfRequested()
                onCameraToggleRequested: root.cameraMirrorActive = !root.cameraMirrorActive
                onEditModeToggleRequested: root.isEditMode = !root.isEditMode
                onDynamicResizeToggleRequested: root.dynamicResizeToastOpen = !root.dynamicResizeToastOpen
                onSettingsRequested: SystemServices.openConfigApp()
                onCloseRequested: root.closeRequested()
            }

            // 2. Multi-Page Slot Grid Viewport
            ExpandedWidgetPageStrip {
                id: expandedPageStrip
                width: parent.width
                height: Math.max(0, parent.height - statusBar.height - parent.spacing)
                initialPage: root.initialPage
                pages: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.expanded) ? userConfig.widgetLayouts.expanded.pages : []
                isEditMode: root.isEditMode
                cameraMirrorActive: root.cameraMirrorActive
                widgetContext: root.sharedWidgetContext
                hoveredSlotIndex: root.hoveredSlotIndex
                isDraggingWidget: root.isDraggingWidget

                onPageChanged: (newPage) => root.pageChanged(newPage)
                onAddWidgetRequested: (pIdx, sIdx) => root.widgetLibraryRequested("expanded", pIdx, sIdx)
                onRemoveSlotWidgetRequested: (pIdx, sIdx) => {
                    if (userConfig)
                        userConfig.removeSlotWidget("expanded", pIdx, sIdx);
                }
                onSpanChangeRequested: (pIdx, sIdx, nSpan) => {
                    if (!userConfig || !userConfig.widgetLayouts || !userConfig.widgetLayouts.expanded) return;
                    const pagesArr = userConfig.widgetLayouts.expanded.pages;
                    const p = pagesArr[pIdx];
                    if (p && p.items) {
                        for (let i = 0; i < p.items.length; ++i) {
                            if (p.items[i].slotIndex === sIdx) {
                                userConfig.setSlotWidget("expanded", pIdx, sIdx, p.items[i].widgetId, nSpan);
                                break;
                            }
                        }
                    }
                }
                onSetSlotsRequested: (pIdx, sCount) => {
                    if (userConfig)
                        userConfig.setPageSlots("expanded", pIdx, sCount);
                }
                onDeletePageRequested: (pIdx) => {
                    if (userConfig)
                        userConfig.removePage("expanded", pIdx);
                }
            }
        }

        DynamicResizeToast {
            id: resizeToast
            open: root.dynamicResizeToastOpen
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            onCloseRequested: root.dynamicResizeToastOpen = false
            onOpenSettingsRequested: {
                root.dynamicResizeToastOpen = false;
                SystemServices.openConfigApp();
            }
        }
    }
}
