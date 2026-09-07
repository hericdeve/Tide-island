import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import IslandBackend
import "qml/common"
import "qml/controlcenter"
import "qml/connectivity"
import "qml/island"
import "qml/widgets"
import "qml/workspace"

PanelWindow {
    id: root
    property var shellRootController: null
    property string overviewPhase: "closed"
    property bool overviewPreloading: false
    readonly property bool overviewPreparing: overviewPhase === "preparing"
    readonly property bool overviewVisible: overviewPhase === "preparing" || overviewPhase === "opening" || overviewPhase === "open"
    readonly property bool overviewMounted: overviewPhase !== "closed" || overviewPreloading
    readonly property bool overviewLoaderActive: !compositorIsNiri
        && (overviewMounted || overviewUnloadGraceTimer.running)
    readonly property bool overviewDataReady: overviewLoader.item
        ? !!overviewLoader.item.overviewDataReady
        : false
    readonly property bool overviewWallpaperReady: overviewWallpaperCache.ready
    readonly property bool overviewVisualReady: overviewDataReady && overviewWallpaperReady
    readonly property bool overviewContentVisible: (overviewPhase === "opening" || overviewPhase === "open")
        && overviewVisualReady
    readonly property bool compositorIsNiri: CompositorBackend.compositor === "niri"
    readonly property int compositorRevision: CompositorBackend.revision
    readonly property string screenOutputName: screen && screen.name !== undefined ? String(screen.name) : ""
    readonly property var hyprlandIntegration: hyprlandIntegrationLoader.item
    readonly property var hyprMonitor: hyprlandIntegration ? hyprlandIntegration.monitor : null
    readonly property string hyprMonitorName: hyprlandIntegration ? hyprlandIntegration.monitorName : ""
    readonly property string compositorOutputName: compositorIsNiri ? screenOutputName : hyprMonitorName
    readonly property bool monitorFocused: {
        compositorRevision;
        return compositorIsNiri
            ? CompositorBackend.isOutputFocused(screenOutputName)
            : (hyprlandIntegration ? hyprlandIntegration.monitorFocused : false);
    }
    readonly property bool connectivityPromptActive: controlCenterLoader.item
        ? controlCenterLoader.item.hasConnectivityPrompt
        : false
    readonly property var controlCenterRef: controlCenterLoader.item
    readonly property int currentMonitorWorkspaceId: {
        compositorRevision;
        return compositorIsNiri
            ? CompositorBackend.activeWorkspaceIndexForOutput(screenOutputName)
            : (hyprlandIntegration ? hyprlandIntegration.workspaceId : 1);
    }
    readonly property bool screenRecordingActive: shellRootController
        && shellRootController.screenRecordingActive !== undefined
        ? !!shellRootController.screenRecordingActive
        : false
    property bool autoHideVisible: false
    property bool autoHidePointerInside: false
    property bool autoHideForcedHidden: false
    property string autoHideRevealSource: "none"

    readonly property var userConfig: UserConfig

    Loader {
        id: hyprlandIntegrationLoader

        active: !root.compositorIsNiri
        asynchronous: false
        source: active ? "qml/island/HyprlandWindowIntegration.qml" : ""
    }

    Binding {
        target: hyprlandIntegrationLoader.item
        property: "screenObject"
        value: root.screen
        when: hyprlandIntegrationLoader.item !== null
    }

    color: StyleTokens.transparent
    anchors { top: true; left: true; right: true }
    mask: Region {
        // Input is the union of the island's visible surfaces plus a compact top
        // gesture strip. The gesture strip must not grow with expanded content.
        Region {
            x: Math.floor(root.topGestureInputX)
            y: 0
            width: Math.ceil(root.topGestureInputWidth)
            height: Math.ceil(root.topGestureInputHeight)
        }

        // Keep input active across the entire window when dragging a widget from the library
        Region {
            intersection: Intersection.Combine
            x: 0
            y: 0
            width: islandContainer.isDraggingWidgetFromLibrary ? root.width : 0
            height: islandContainer.isDraggingWidgetFromLibrary ? root.height : 0
        }

        // Keep input active over floating staging tray when staging a widget
        Region {
            intersection: Intersection.Combine
            x: stagingTrayItem.visible ? Math.floor(stagingTrayItem.x) : 0
            y: stagingTrayItem.visible ? Math.floor(stagingTrayItem.y) : 0
            width: stagingTrayItem.visible ? Math.ceil(stagingTrayItem.width) : 0
            height: stagingTrayItem.visible ? Math.ceil(stagingTrayItem.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(mainCapsule.x)
            y: Math.floor(mainCapsule.y)
            width: Math.ceil(mainCapsule.width)
            height: Math.ceil(mainCapsule.height)
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(fileShelfBubble.x)
            y: Math.floor(fileShelfBubble.y)
            width: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.width) : 0
            height: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.height) : 0
        }
        
        // Add existing detail shells
        Region {
            intersection: Intersection.Combine
            x: Math.floor(wifiConnectivityDetailShell.x)
            y: Math.floor(wifiConnectivityDetailShell.y)
            width: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.width) : 0
            height: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(bluetoothConnectivityDetailShell.x)
            y: Math.floor(bluetoothConnectivityDetailShell.y)
            width: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.width) : 0
            height: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(powerConnectivityDetailShell.x)
            y: Math.floor(powerConnectivityDetailShell.y)
            width: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.width) : 0
            height: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.height) : 0
        }
    }
    readonly property real capsuleTopMargin: (userConfig.notchMode === "notch") ? 0 : Math.max(4, userConfig.islandTopMargin)
    readonly property real capsuleWindowHeight: Math.ceil(
        root.capsuleTopMargin + mainCapsule.targetHeight + 12
    )
    readonly property real connectivityDetailWindowHeight: root.anyConnectivityDetailMounted
        ? Math.ceil(userConfig.islandTopMargin + root.connectivityDetailHeight + 12)
        : 0
    readonly property real overviewWindowHeight: root.overviewVisible
        ? Math.ceil(userConfig.islandTopMargin + root.overviewCapsuleHeight + 8)
        : 0
    readonly property real requestedWindowHeight: Math.max(
        root.notificationCenterWindowHeight,
        root.capsuleWindowHeight,
        root.connectivityDetailWindowHeight,
        root.overviewWindowHeight,
        Math.ceil(root.controlCenterWindowHeight),
        islandContainer.isDraggingWidgetFromLibrary ? 560 : 0,
        islandContainer.widgetStagingActive ? Math.ceil(mainCapsule.y + mainCapsule.height + 14 + (stagingTrayItem.height > 0 ? stagingTrayItem.height : 76) + 24) : 0
    )
    // Grow the layer surface immediately, but keep the old extent while the
    // capsule finishes its collapse animation. A later expansion interrupts
    // the pending shrink instead of letting a stale timer clip new content.
    property real retainedWindowHeight: 0
    implicitHeight: Math.max(root.requestedWindowHeight, root.retainedWindowHeight)

    function reconcileWindowHeight() {
        if (root.requestedWindowHeight >= root.retainedWindowHeight) {
            windowShrinkTimer.stop();
            root.retainedWindowHeight = root.requestedWindowHeight;
            return;
        }

        windowShrinkTimer.restart();
    }

    onRequestedWindowHeightChanged: root.reconcileWindowHeight()
    Component.onCompleted: {
        root.retainedWindowHeight = root.requestedWindowHeight;
        if (userConfig.notchMode === "circle") {
            islandContainer.islandState = "normal";
            islandContainer.restingState = "normal";
            mainCapsule.displayedWidth = userConfig.notchCircleClosedSize;
        }
    }

    exclusiveZone: Math.ceil(root.baseExclusiveZone * root.exclusiveZoneProgress)
    WlrLayershell.layer: {
        if (userConfig.islandLayer === "overlay")
            return WlrLayer.Overlay;
        if (islandContainer.wallpaperPickerLayerVisible
                || islandContainer.applicationLauncherLayerVisible
                || islandContainer.fileShelfLayerVisible
                || islandContainer.islandState === "widget_library"
                || islandContainer.isDraggingWidgetFromLibrary
                || islandContainer.widgetStagingActive)
            return WlrLayer.Overlay;
        return WlrLayer.Top;
    }
    WlrLayershell.keyboardFocus: {
        if (islandContainer.controlCenterLayerVisible
                || islandContainer.wallpaperPickerLayerVisible
                || islandContainer.applicationLauncherLayerVisible)
            return WlrKeyboardFocus.Exclusive;
        if (islandContainer.fileShelfLayerVisible
                || islandContainer.islandState === "widget_library")
            return WlrKeyboardFocus.OnDemand;
        // Keep keyboard focus on the overview until an overview action closes it.
        // Click-to-focus closes the overview before focusing the selected client.
        if (root.monitorFocused && root.overviewVisible)
            return WlrKeyboardFocus.Exclusive;
        if (islandContainer.expandedPlayerKeyboardFocusRequested)
            return WlrKeyboardFocus.OnDemand;
        if (root.monitorFocused && root.connectivityPromptActive)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }
    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property int bodyFontSize: userConfig.bodyFontSize
    readonly property int titleFontSize: userConfig.titleFontSize
    readonly property int iconFontSize: userConfig.iconFontSize
    readonly property string defaultSplitIcon: "\ud83c\udfa7"
    readonly property string notificationStatusIcon: "\uf0f3"
    readonly property real overviewWindowCornerRadius: 12
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([
        1,
        userConfig.dynamicIslandPrimaryButton,
        userConfig.dynamicIslandSecondaryButton
    ])
    readonly property int configuredHoverExpandAction: {
        const action = Number(userConfig.hoverExpandAction);
        return isNaN(action) ? 0 : Math.max(0, Math.min(2, Math.round(action)));
    }
    readonly property real baseExclusiveZone: userConfig.islandExclusiveZone
    readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0
    readonly property bool islandPointerInside: {
        if (capsuleHoverHandler.hovered)
            return true;
        if (wifiConnectivityDetailShell.mounted && wifiConnectivityDetailShell.hovered)
            return true;
        if (bluetoothConnectivityDetailShell.mounted && bluetoothConnectivityDetailShell.hovered)
            return true;
        if (powerConnectivityDetailShell.mounted && powerConnectivityDetailShell.hovered)
            return true;
        return false;
    }
    readonly property bool topGestureInputActive: !root.overviewVisible && islandContainer.canShowSideSwipe
    readonly property bool autoHideRuntimeEnabled: !shellRootController
        || shellRootController.islandAutoHideRuntimeEnabled === undefined
        || !!shellRootController.islandAutoHideRuntimeEnabled
    readonly property bool autoHideEnabled: userConfig.islandAutoHideEnabled && autoHideRuntimeEnabled
    readonly property bool autoHideRestingState: islandContainer.islandState === "normal"
        || islandContainer.islandState === "custom"
        || islandContainer.islandState === "lyrics"
    readonly property bool autoHideCanHideNow: autoHideEnabled
        && autoHideRestingState
        && !root.overviewVisible
        && !root.connectivityPromptActive
        && !root.anyConnectivityDetailMounted
    readonly property bool autoHideMustShow: !autoHideRestingState
        || root.overviewVisible
        || root.connectivityPromptActive
        || root.anyConnectivityDetailMounted
    readonly property bool isFullscreenActive: hyprlandIntegration ? !!hyprlandIntegration.isFullscreen : false
    readonly property bool fullscreenAutoHide: userConfig.hideNotchInFullscreen
        && isFullscreenActive
        && !islandContainer.expandedLayerVisible
        && !root.overviewVisible
    readonly property bool autoHideTargetVisible: !fullscreenAutoHide && (autoHideMustShow
        || (!autoHideForcedHidden && (!autoHideEnabled || autoHideVisible)))
    readonly property bool autoHideSuppressesTransientReveal: (autoHideEnabled || autoHideForcedHidden)
        && !autoHideTargetVisible
    property real autoHideProgress: autoHideTargetVisible ? 1 : 0
    readonly property bool exclusiveZoneTargetActive: (!autoHideEnabled && autoHideTargetVisible)
        || (autoHideRevealSource === "edge" && autoHideTargetVisible)
        || islandContainer.notificationLayerVisible
    property real exclusiveZoneProgress: exclusiveZoneTargetActive ? 1 : 0
    readonly property real autoHideRevealWidth: Math.min(root.width, Math.max(userConfig.islandWidth + 120, 240))
    readonly property real autoHideRevealHeight: autoHideEnabled ? 10 : 0
    readonly property real autoHideRevealX: Math.max(
        0,
        Math.min(root.width - autoHideRevealWidth, root.width * userConfig.islandPositionX / 100 - autoHideRevealWidth / 2)
    )
    readonly property real topGestureInputX: autoHideEnabled ? autoHideRevealX : 0
    readonly property real topGestureInputWidth: topGestureInputActive
        ? (autoHideEnabled ? autoHideRevealWidth : root.width)
        : 0
    readonly property real topGestureInputHeight: topGestureInputActive
        ? (autoHideEnabled ? autoHideRevealHeight : root.baseExclusiveZone)
        : 0
    readonly property real overviewCapsuleWidth: islandContainer.overviewView ? islandContainer.overviewView.width : 760
    readonly property real overviewCapsuleHeight: islandContainer.overviewView ? islandContainer.overviewView.height : 308
    readonly property real overviewCapsuleRadius: islandContainer.overviewView
        ? islandContainer.overviewView.largeWorkspaceRadius + islandContainer.overviewView.outerPadding
        : 44
    readonly property color overviewCapsuleColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardColor
        : StyleTokens.overviewCard
    readonly property color overviewCapsuleBorderColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardBorderColor
        : StyleTokens.overviewBorder
    property bool wifiConnectivityDetailOpen: false
    property bool wifiConnectivityDetailMounted: false
    property bool bluetoothConnectivityDetailOpen: false
    property bool bluetoothConnectivityDetailMounted: false
    property bool powerConnectivityDetailOpen: false
    property bool powerConnectivityDetailMounted: false
    readonly property bool anyConnectivityDetailMounted: wifiConnectivityDetailMounted || bluetoothConnectivityDetailMounted || powerConnectivityDetailMounted
    readonly property real connectivityDetailWidth: 318
    readonly property real connectivityDetailHeight: 404
    readonly property real controlCenterMaximumExtraHeight: controlCenterLoader.item
        ? controlCenterLoader.item.controlCenterMaximumExtraHeight
        : 120
    readonly property real controlCenterWindowHeight: islandContainer.controlCenterLayerVisible
        ? userConfig.islandTopMargin + 320 + root.controlCenterMaximumExtraHeight + 12
        : 0

    readonly property real notificationCenterWindowHeight: islandContainer.notificationCenterLayerVisible
        ? userConfig.islandTopMargin + (notificationCenterLoader.item ? notificationCenterLoader.item.contentHeight : 400) + 6
        : 0
    readonly property real connectivityDetailGap: 16
    readonly property int connectivityDetailAnimationDuration: 360
    readonly property string overviewWallpaperSource: overviewWallpaperCache.effectiveSource
    property string wallpaperPickerActiveWallpaper: userConfig.wallpaperPath

    Behavior on autoHideProgress {
        NumberAnimation {
            duration: root.autoHideTargetVisible ? 120 : 300
            easing.type: root.autoHideTargetVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on exclusiveZoneProgress {
        NumberAnimation {
            duration: root.exclusiveZoneTargetActive ? 120 : 300
            easing.type: root.exclusiveZoneTargetActive ? Easing.OutCubic : Easing.InCubic
        }
    }

    function setAutoHideRevealSource(source) {
        if (source === undefined || source === null)
            return;

        const nextSource = String(source);
        autoHideRevealSource = nextSource === "edge" || nextSource === "state" || nextSource === "manual"
            ? nextSource
            : "manual";
    }

    function showAutoHiddenIsland(source) {
        setAutoHideRevealSource(source);
        autoHideForcedHidden = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        autoHideHideTimer.stop();
        autoHideVisible = true;
    }

    function scheduleAutoHide() {
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        if (!autoHideCanHideNow) {
            autoHideHideTimer.stop();
            showAutoHiddenIsland("state");
            return;
        }

        if (autoHidePointerInside) {
            autoHideHideTimer.stop();
            return;
        }

        autoHideHideTimer.interval = Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs));
        autoHideHideTimer.restart();
    }

    function hideAutoHiddenIsland(force) {
        if (force === undefined) force = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            if (!force && autoHideMustShow)
                return;
            autoHideForcedHidden = true;
            autoHideRevealSource = "none";
            autoHideVisible = false;
            return;
        }

        if (!force && (!autoHideCanHideNow || autoHidePointerInside))
            return;

        autoHideHideTimer.stop();
        autoHideForcedHidden = false;
        autoHideRevealSource = "none";
        autoHideVisible = false;
    }

    function toggleAutoHiddenIsland() {
        if (autoHideTargetVisible)
            hideAutoHiddenIsland(false);
        else
            showAutoHiddenIsland("manual");
    }

    function showIslandWindow() {
        showAutoHiddenIsland("manual");
    }

    function hideIslandWindow() {
        autoHidePointerInside = false;
        hideAutoHiddenIsland(false);
    }

    function toggleIslandWindow() {
        toggleAutoHiddenIsland();
    }

    function refreshAutoHideWindow() {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }

    function beginOverviewOpening() {
        if (!overviewPreparing) return;
        if (overviewLoader.status !== Loader.Ready || !overviewVisualReady) return;
        overviewPreloading = false;
        overviewPhase = "opening";
        overviewRevealTimer.restart();
    }

    function prepareOverview() {
        if (compositorIsNiri) return;
        if (overviewPhase !== "closed") return;
        overviewUnloadGraceTimer.stop();
        overviewPreloading = true;
        overviewPreloadExpireTimer.restart();
    }

    function cancelPreparedOverview() {
        if (compositorIsNiri) return;
        if (overviewPhase !== "closed") return;
        overviewPreloadExpireTimer.stop();
        overviewPreloading = false;
    }

    function openOverview() {
        if (compositorIsNiri)
            return;
        if (overviewPhase !== "closed") return;
        overviewUnloadGraceTimer.stop();
        overviewPreloadExpireTimer.stop();
        overviewPreloading = true;
        overviewPhase = "preparing";
        if (overviewLoader.status === Loader.Ready) {
            beginOverviewOpening();
        }
    }

    function closeOverview() {
        if (compositorIsNiri)
            return;
        if (!overviewMounted) return;
        if (overviewLoader.status === Loader.Ready)
            overviewUnloadGraceTimer.restart();
        overviewRevealTimer.stop();
        overviewPreloadExpireTimer.stop();
        islandContainer.restoreRestingCapsule(true);
        overviewPreloading = false;
        overviewPhase = "closed";
    }

    function closeOverviewEverywhere() {
        if (shellRootController && shellRootController.closeOverviewAll) {
            shellRootController.closeOverviewAll();
            return;
        }

        closeOverview();
    }

    function setConnectivityDetailVisible(kind, open) {
        const nextOpen = !!open;

        if (kind === "wifi") {
            if (nextOpen) {
                wifiConnectivityDetailCleanupTimer.stop();
                wifiConnectivityDetailMounted = true;
                wifiConnectivityDetailOpen = true;
            } else {
                if (!wifiConnectivityDetailMounted && !wifiConnectivityDetailOpen)
                    return;
                wifiConnectivityDetailOpen = false;
                wifiConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "power") {
            if (nextOpen) {
                powerConnectivityDetailCleanupTimer.stop();
                powerConnectivityDetailMounted = true;
                powerConnectivityDetailOpen = true;
            } else {
                if (!powerConnectivityDetailMounted && !powerConnectivityDetailOpen)
                    return;
                powerConnectivityDetailOpen = false;
                powerConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "bluetooth") {
            if (nextOpen) {
                bluetoothConnectivityDetailCleanupTimer.stop();
                bluetoothConnectivityDetailMounted = true;
                bluetoothConnectivityDetailOpen = true;
            } else {
                if (!bluetoothConnectivityDetailMounted && !bluetoothConnectivityDetailOpen)
                    return;
                bluetoothConnectivityDetailOpen = false;
                bluetoothConnectivityDetailCleanupTimer.restart();
            }
        }
    }

    function closeAllConnectivityDetails() {
        setConnectivityDetailVisible("wifi", false);
        setConnectivityDetailVisible("bluetooth", false);
        setConnectivityDetailVisible("power", false);
    }

    function openOverviewEverywhere() {
        if (shellRootController && shellRootController.openOverviewAll) {
            shellRootController.openOverviewAll();
            return;
        }

        openOverview();
    }

    function prepareOverviewEverywhere() {
        if (shellRootController && shellRootController.prepareOverviewAll) {
            shellRootController.prepareOverviewAll();
            return;
        }

        prepareOverview();
    }

    function cancelPreparedOverviewEverywhere() {
        if (shellRootController && shellRootController.cancelPreparedOverviewAll) {
            shellRootController.cancelPreparedOverviewAll();
            return;
        }

        cancelPreparedOverview();
    }

    function toggleOverviewEverywhere() {
        if (compositorIsNiri)
            return;

        if (shellRootController && shellRootController.toggleOverviewAll) {
            shellRootController.toggleOverviewAll();
            return;
        }

        if (overviewMounted)
            closeOverviewEverywhere();
        else
            openOverviewEverywhere();
    }

    function prewarmWallpaperCache() {
        overviewWallpaperCache.prewarm();
    }

    function handleWallpaperApplySucceeded(filePath) {
        wallpaperPickerActiveWallpaper = filePath;
        if (shellRootController && shellRootController.refreshOverviewWallpaperCaches)
            shellRootController.refreshOverviewWallpaperCaches(filePath);
        else
            prewarmWallpaperCache();
    }

    function showNotification(appName, summary, body) {
        islandContainer.showNotificationCapsule(appName, summary, body);
    }

    function showClockWindow() {
        islandContainer.showTimeCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showCustomInfoWindow() {
        islandContainer.showCustomCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showLyricsWindow() {
        islandContainer.showLyricsCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeRightWindow() {
        if (islandContainer.restingState === "lyrics")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal") {
            if (islandContainer.hasCustomLeftItems)
                islandContainer.showCustomCapsule();
            else
                islandContainer.showLyricsCapsule();
        }
        else
            islandContainer.showLyricsCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeLeftWindow() {
        if (islandContainer.restingState === "custom")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal")
            islandContainer.showLyricsCapsule();
        else if (islandContainer.hasCustomLeftItems)
            islandContainer.showCustomCapsule();
        else
            islandContainer.showTimeCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function togglePlayerWindow() {
        if (islandContainer.islandState === "expanded")
            islandContainer.smartRestoreState();
        else
            islandContainer.showExpandedPlayer(false);
    }

    function showTimerWindow() {
        islandContainer.showExpandedTimerPage();
    }

    function toggleControlCenterWindow() {
        if (islandContainer.islandState === "control_center")
            islandContainer.smartRestoreState();
        else {
            islandContainer.showControlCenter();
            if (controlCenterLoader.item)
                controlCenterLoader.item.powerViewActive = false;
        }
    }

    function togglePowerMenuWindow() {
        if (islandContainer.islandState === "control_center"
                && controlCenterLoader.item
                && controlCenterLoader.item.powerViewActive) {
            islandContainer.smartRestoreState();
            return;
        }

        islandContainer.showControlCenter();
        if (controlCenterLoader.item)
            controlCenterLoader.item.powerViewActive = true;
    }

    function toggleNotificationCenterWindow() {
        if (islandContainer.islandState === "notification_center")
            islandContainer.smartRestoreState();
        else
            islandContainer.showNotificationCenter();
    }

    function toggleWallpaperPickerWindow() {
        if (islandContainer.islandState === "wallpaper_picker")
            islandContainer.smartRestoreState();
        else
            islandContainer.showWallpaperPicker();
    }

    function toggleApplicationLauncherWindow() {
        if (islandContainer.islandState === "application_launcher")
            islandContainer.smartRestoreState();
        else
            islandContainer.showApplicationLauncher();
    }

    function toggleFileShelfWindow() {
        if (islandContainer.islandState === "file_shelf")
            islandContainer.smartRestoreState();
        else
            islandContainer.showFileShelf(true);
    }

    onOverviewVisibleChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
        if (overviewVisible)
            showAutoHiddenIsland("state");
        else
            scheduleAutoHide();
    }
    onConnectivityPromptActiveChanged: {
        if (connectivityPromptActive && monitorFocused)
            connectivityPromptFocusTimer.restart();
        if (connectivityPromptActive)
            showAutoHiddenIsland("state");
        else
            scheduleAutoHide();
    }
    onAutoHideEnabledChanged: {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }
    onAutoHideCanHideNowChanged: {
        if (autoHideCanHideNow)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("state");
    }
    onOverviewVisualReadyChanged: {
        if (overviewVisualReady) beginOverviewOpening();
    }
    onOverviewContentVisibleChanged: {
        if (overviewContentVisible && monitorFocused)
            overviewFocusTimer.restart();
    }
    onMonitorFocusedChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
        if (connectivityPromptActive && monitorFocused) connectivityPromptFocusTimer.restart();
    }

    Timer {
        id: overviewFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusOverview()
    }

    Timer {
        id: connectivityPromptFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: expandedPlayerFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusExpandedPlayer()
    }

    Timer {
        id: windowShrinkTimer
        interval: 1000
        repeat: false
        onTriggered: root.retainedWindowHeight = root.requestedWindowHeight
    }

    Timer {
        id: autoHideHideTimer
        interval: Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs))
        repeat: false
        onTriggered: root.hideAutoHiddenIsland(false)
    }

    function focusWallpaperPicker() {
        islandContainer.forceActiveFocus();
        if (wallpaperPickerLoader.item && wallpaperPickerLoader.item.grabKeyboardFocus)
            wallpaperPickerLoader.item.grabKeyboardFocus();
    }

    function focusOverview() {
        islandContainer.forceActiveFocus();
        const view = islandContainer.overviewView;
        if (view && view.grabKeyboardFocus)
            view.grabKeyboardFocus();
    }

    function focusExpandedPlayer() {
        if (expandedPlayerLoader.item && expandedPlayerLoader.item.grabKeyboardFocus)
            expandedPlayerLoader.item.grabKeyboardFocus();
    }

    function focusApplicationLauncher() {
        islandContainer.forceActiveFocus();
        if (applicationLauncherLoader.item && applicationLauncherLoader.item.grabKeyboardFocus)
            applicationLauncherLoader.item.grabKeyboardFocus();
    }

    function focusFileShelf() {
        islandContainer.forceActiveFocus();
        if (fileShelfLoader.item && fileShelfLoader.item.grabKeyboardFocus)
            fileShelfLoader.item.grabKeyboardFocus();
    }

    function dragCarriesFiles(dragEvent) {
        if (!dragEvent)
            return false;
        if (dragEvent.hasUrls)
            return true;

        const formats = dragEvent.formats || [];
        return formats.indexOf("text/uri-list") >= 0
            || formats.indexOf("x-special/gnome-copied-files") >= 0;
    }

    function addFilesFromDrop(dropEvent) {
        if (!dropEvent)
            return 0;

        let added = 0;
        if (dropEvent.hasUrls)
            added += FileShelf.addUrls(dropEvent.urls);

        const formats = dropEvent.formats || [];
        if (added === 0 && formats.indexOf("text/uri-list") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("text/uri-list"));
        if (added === 0 && formats.indexOf("x-special/gnome-copied-files") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("x-special/gnome-copied-files"));
        return added;
    }

    Timer {
        id: overviewRevealTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "opening") root.overviewPhase = "open";
        }
    }

    Timer {
        id: overviewPreloadExpireTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "closed")
                root.overviewPreloading = false;
        }
    }

    Timer {
        id: overviewUnloadGraceTimer
        interval: 260
        repeat: false
    }

    Timer {
        id: wifiConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.wifiConnectivityDetailMounted = false
    }

    Timer {
        id: bluetoothConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.bluetoothConnectivityDetailMounted = false
    }

    Timer {
        id: powerConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.powerConnectivityDetailMounted = false
    }

    OverviewWallpaperCacheController {
        id: overviewWallpaperCache

        active: root.overviewLoaderActive
        wallpaperPath: userConfig.wallpaperCustomCommandEnabled === true && root.wallpaperPickerActiveWallpaper !== ""
            ? root.wallpaperPickerActiveWallpaper
            : userConfig.wallpaperPath
        hyprMonitor: root.hyprMonitor
        screenObject: root.screen
    }

    IslandClock {
        id: timeObj
        clockFormat: userConfig.clockFormat
    }

    // --- 灵动岛主容器与全局状态 ---
    FocusScope {
        id: islandContainer
        anchors.fill: parent
        focus: controlCenterLayerVisible
            || wallpaperPickerLayerVisible
            || applicationLauncherLayerVisible
            || fileShelfLayerVisible
            || expandedPlayerKeyboardFocusRequested
            || (root.monitorFocused && (root.overviewVisible || root.connectivityPromptActive))
            || islandState === "widget_library"

        property string islandState: "normal"
        property string splitIcon: root.defaultSplitIcon
        property real osdProgress: -1.0
        property bool osdProgressAnimationEnabled: true
        property string osdCustomText: ""
        property int currentWs: root.currentMonitorWorkspaceId > 0 ? root.currentMonitorWorkspaceId : 1
        readonly property int batteryCapacity: systemState.batteryCapacity
        readonly property bool isCharging: systemState.isCharging
        readonly property real currentVolume: systemState.currentVolume
        readonly property bool isMuted: systemState.isMuted
        readonly property real currentBrightness: systemState.currentBrightness
        readonly property real currentCpuUsage: systemState.currentCpuUsage
        readonly property real currentRamUsage: systemState.currentRamUsage
        property string notificationAppName: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property bool notificationExpanded: false
        property var bluetoothExpandedDevice: null
        property var notificationHistoryModel: ListModel {}
        readonly property var cavaLevels: systemState.cavaLevels
        property real swipeTransitionProgress: 0
        property string workspaceOriginSide: "none"
        property string splitOriginSide: "none"
        property string restingState: "normal"
        property bool expandedByPlayerAutoOpen: false
        property real customCapsuleWidth: 220
        property real lyricsCapsuleWidth: 220
        property bool sideSwipeSettling: false
        property bool sideSwipeDragging: false
        property bool hoverExpandedActive: false
        property bool expandedPlayerKeyboardFocusRequested: false
        property bool openTimerPageWhenExpanded: false
        property int rememberedPlayerPage: 0
        property int timerSelectedHours: 0
        property int timerSelectedMinutes: 5
        property int timerTotalSeconds: 300
        property int timerRemainingSeconds: 0
        property bool timerRunning: false
        property bool timerActive: false
        property bool timerCompletionAnimating: false
        property real timerCompletionPulse: 0
        property real timerCompletionFlash: 0
        property bool fileShelfOpenedManually: false
        property int preFileShelfPage: 0
        readonly property int defaultAutoHideInterval: 1250
        readonly property int notificationAutoHideInterval: 4200
        readonly property int bluetoothExpandedAutoHideInterval: 2500
        readonly property int swipeAnimationDuration: 220
        readonly property real timerProgress: timerActive && timerTotalSeconds > 0
            ? Math.max(0, Math.min(1, timerRemainingSeconds / timerTotalSeconds))
            : 0
        readonly property bool timerBubbleWanted: (timerActive && timerRemainingSeconds > 0 || timerCompletionAnimating)
            && !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfBubbleWanted: FileShelf.count > 0
            && !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfCanAutoOpen: !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool blocksTransientSplit: islandState === "expanded"
            || islandState === "bluetooth_expanded"
            || islandState === "control_center"
            || islandState === "notification"
            || islandState === "wallpaper_picker"
            || islandState === "application_launcher"
            || islandState === "file_shelf"
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: Math.max(userConfig.notchClosedWidth + 95, 280)
        readonly property bool canShowSideSwipe: userConfig.notchMode !== "circle"
            && (islandState === "custom"
                || islandState === "lyrics"
                || (islandState === "long_capsule" && workspaceOriginSide === "none"))
        readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
        readonly property var customLeftItems: systemState.customLeftItems
        readonly property bool hasCustomLeftItems: systemState.hasCustomLeftItems
        readonly property bool customSwipeVisible: !root.overviewVisible
            && hasCustomLeftItems
            && (
                capsuleMouseArea.sideSwipeInteractive
                ? swipeTransitionProgress < 0
                : (
                    islandState === "custom"
                    || (islandState === "split" && splitOriginSide === "left")
                    || (islandState === "long_capsule"
                        && (workspaceOriginSide === "left" || swipeTransitionProgress < 0))
                )
            )
        readonly property bool lyricsSwipeVisible: !root.overviewVisible && (
            capsuleMouseArea.sideSwipeInteractive
            ? swipeTransitionProgress > 0.01
            : (
                islandState === "lyrics"
                || (islandState === "split" && splitOriginSide === "right")
                || (islandState === "long_capsule"
                    && (workspaceOriginSide === "right" || swipeTransitionProgress > 0))
            )
        )
        readonly property bool expandedLayerVisible: !root.overviewVisible && islandState === "expanded"
        readonly property bool bluetoothExpandedLayerVisible: !root.overviewVisible && islandState === "bluetooth_expanded"
        readonly property bool notificationLayerVisible: !root.overviewVisible && islandState === "notification"
        readonly property bool controlCenterLayerVisible: !root.overviewVisible && islandState === "control_center"
        readonly property bool notificationCenterLayerVisible: !root.overviewVisible && islandState === "notification_center"
        readonly property bool wallpaperPickerLayerVisible: !root.overviewVisible && islandState === "wallpaper_picker"
        readonly property bool applicationLauncherLayerVisible: !root.overviewVisible && islandState === "application_launcher"
        readonly property bool fileShelfLayerVisible: !root.overviewVisible && islandState === "file_shelf"
        readonly property var activePlayer: mediaController.activePlayer
        readonly property string lyricsDisplayText: mediaController.displayText
        readonly property string currentTrack: mediaController.currentTrack
        readonly property string currentArtist: mediaController.currentArtist
        readonly property string currentArtUrl: mediaController.currentArtUrl
        readonly property real trackProgress: mediaController.trackProgress
        readonly property string timePlayed: mediaController.timePlayed
        readonly property string timeTotal: mediaController.timeTotal
        readonly property bool screenRecordingActive: root.screenRecordingActive
        readonly property var bluetoothDevices: bluetoothConnectionTracker.devices
        readonly property var overviewView: overviewLoader.item && overviewLoader.item.overviewView
            ? overviewLoader.item.overviewView
            : null

        onExpandedLayerVisibleChanged: {
            if (!expandedLayerVisible)
                expandedPlayerKeyboardFocusRequested = false;
        }

        onControlCenterLayerVisibleChanged: {
            if (!controlCenterLayerVisible) {
                if (controlCenterLoader.item)
                    controlCenterLoader.item.closeConnectivityPanels();
                else
                    root.closeAllConnectivityDetails();
            }
        }

        onFileShelfLayerVisibleChanged: {
            if (!fileShelfLayerVisible)
                fileShelfOpenedManually = false;
        }

        onCustomLeftItemsChanged: {
            if (restingState === "custom" && !hasCustomLeftItems) {
                restingState = "normal";

                if (islandState === "custom"
                        || (islandState === "split" && splitOriginSide === "left")
                        || (islandState === "long_capsule" && workspaceOriginSide === "left")) {
                    restoreRestingCapsule(true);
                } else {
                    applyRestingVisuals();
                }
            } else if (restingState === "custom") {
                syncCustomCapsuleWidth();
            }
        }

        Connections {
            target: userConfig

            function onNotchModeChanged() {
                if (userConfig.notchMode === "circle") {
                    islandContainer.restingState = "normal";
                    if (islandContainer.islandState !== "expanded"
                            && islandContainer.islandState !== "bluetooth_expanded"
                            && islandContainer.islandState !== "control_center"
                            && islandContainer.islandState !== "notification_center"
                            && islandContainer.islandState !== "wallpaper_picker"
                            && islandContainer.islandState !== "application_launcher"
                            && islandContainer.islandState !== "widget_library"
                            && islandContainer.islandState !== "file_shelf"
                            && islandContainer.islandState !== "notification") {
                        islandContainer.islandState = "normal";
                        mainCapsule.displayedWidth = userConfig.notchCircleClosedSize;
                    }
                } else {
                    if (islandContainer.islandState === "normal") {
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    }
                }
            }
        }

        IslandMprisController {
            id: mediaController

            expanded: islandContainer.islandState === "expanded"
            clientId: "island-mpris-" + root.screenOutputName
        }

        BluetoothConnectionTracker {
            id: bluetoothConnectionTracker

            onAdapterChanged: islandContainer.bluetoothExpandedDevice = null

            onNewConnection: function(device) {
                islandContainer.showBluetoothExpanded(device);
            }
        }

        IslandSystemState {
            id: systemState

            configuredLeftSwipeItems: userConfig.dynamicIslandLeftSwipeItems
            timeText: timeObj.currentTime
            dateText: timeObj.currentDateLabel
            currentTrack: islandContainer.currentTrack
            currentArtUrl: islandContainer.currentArtUrl
            currentWorkspace: islandContainer.currentWs
            customSwipeActive: customSwipeLoader.active
            lyricsCavaActive: islandContainer.lyricsSwipeVisible
                && islandContainer.rightSwipeProgress > 0.001

            onTransientRequested: function(icon, progress, text) {
                islandContainer.showTransientCapsule(icon, progress, text);
            }
        }

        CompositorWorkspaceTracker {
            id: workspaceTracker

            compositor: CompositorBackend.compositor
            hyprMonitor: root.hyprMonitor
            hyprMonitorName: root.hyprMonitorName
            outputName: root.compositorOutputName
            monitorFocused: root.monitorFocused

            onWorkspaceSynced: function(workspaceId) {
                islandContainer.currentWs = workspaceId;
            }

            onWorkspaceActivated: function(workspaceId) {
                if(userConfig.islandShowWorkspaceOnAutoHide){
                    root.showAutoHiddenIsland();
                }

                islandContainer.showWorkspaceCapsule(workspaceId);
            }
        }

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled

            SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad }
        }
        Behavior on swipeTransitionProgress {
            enabled: !islandContainer.sideSwipeDragging && !capsuleMouseArea.sideSwipeInteractive

            NumberAnimation {
                duration: islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.overviewVisible) {
                    root.closeOverviewEverywhere();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.expandedLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.controlCenterLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }
            }

            if (!root.overviewVisible) return;

            const view = islandContainer.overviewView;
            if (event.key === Qt.Key_H) {
                if (view)
                    view.focusAdjacentWorkspace(0, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_J) {
                if (view)
                    view.focusAdjacentWorkspace(1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_K) {
                if (view)
                    view.focusAdjacentWorkspace(-1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                if (view)
                    view.focusAdjacentWorkspace(0, 1);
                event.accepted = true;
            } else if ((event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) || event.key === Qt.Key_Backtab) {
                if (root.hyprlandIntegration)
                    root.hyprlandIntegration.focusWorkspace("r-1");
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (root.hyprlandIntegration)
                    root.hyprlandIntegration.focusWorkspace("r+1");
                event.accepted = true;
            }
        }

        function handleConfiguredClickAction(actionName) {
            switch (actionName) {
            case "":
            case "none":
                return;
            case "toggleExpandedPlayer":
                if (islandState === "expanded") {
                    autoHideTimer.stop();
                    smartRestoreState();
                } else {
                    showExpandedPlayer(false);
                }
                return;
            case "openExpandedPlayer":
                showExpandedPlayer(false);
                return;
            case "closeExpandedPlayer":
                if (islandState === "expanded")
                    smartRestoreState();
                return;
            case "toggleNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                else
                    showNotificationCenter();
                return;
            case "openNotificationCenter":
                showNotificationCenter();
                return;
            case "closeNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                return;
            case "toggleControlCenter":
            case "toggleWidgetLibrary":
                if (islandState === "widget_library")
                    smartRestoreState();
                else
                    showWidgetLibrary();
                return;
            case "openControlCenter":
            case "openWidgetLibrary":
                showWidgetLibrary();
                return;
            case "closeControlCenter":
            case "closeWidgetLibrary":
                if (islandState === "widget_library")
                    smartRestoreState();
                return;
            case "toggleOverview":
                root.toggleOverviewEverywhere();
                return;
            case "openOverview":
                root.openOverviewEverywhere();
                return;
            case "closeOverview":
                root.closeOverviewEverywhere();
                return;
            case "toggleLyrics":
                if (restingState === "lyrics")
                    showTimeCapsule();
                else
                    showLyricsCapsule();
                return;
            case "showLyrics":
                showLyricsCapsule();
                return;
            case "showTime":
                showTimeCapsule();
                return;
            case "restoreRestingCapsule":
                smartRestoreState();
                return;
            default:
            }
        }

        function clamp01(value) {
            return Math.max(0, Math.min(1, value));
        }

        function normalizeRestingState(nextState) {
            if (userConfig.notchMode === "circle") return "normal";
            if (nextState === "lyrics") return "lyrics";
            if (nextState === "custom" && hasCustomLeftItems) return "custom";
            return "normal";
        }

        function restingStateProgress(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function restingStateSide(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            default:
                return "none";
            }
        }

        function swipeRestProgressForState() {
            switch (islandState) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function currentTransientOriginSide() {
            switch (islandState) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            case "long_capsule":
                return workspaceOriginSide;
            case "split":
                return splitOriginSide;
            default:
                return "none";
            }
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate) osdProgressAnimationReset.restart();
        }

        function abortSideTransientMode() {
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = "none";
            splitOriginSide = "none";
        }

        function clearTransientCapsule() {
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
            notificationExpanded = false;
            bluetoothExpandedDevice = null;
        }

        function cleanNotificationText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/<[^>]*>/g, " ")
                .replace(/&nbsp;/g, " ")
                .replace(/&amp;/g, "&")
                .replace(/&quot;/g, "\"")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/\s+/g, " ")
                .trim();
        }

        function prepareRestingCapsuleGeometry() {
            if (restingState === "custom")
                syncCustomCapsuleWidth();
            if (restingState === "lyrics")
                syncLyricsCapsuleWidth();
        }

        function applyRestingVisuals() {
            prepareRestingCapsuleGeometry();
            swipeTransitionProgress = restingStateProgress(restingState);
        }

        function sideSwipeRestProgressForProgress(progressValue) {
            if (progressValue <= -0.5) return -1;
            if (progressValue >= 0.5) return 1;
            return 0;
        }

        function sideSwipeNormalRestWidth() {
            return islandContainer.currentTrack !== ""
                ? Math.round(userConfig.notchClosedWidth + 2 * Math.max(0, userConfig.notchClosedHeight - 12) + 20)
                : userConfig.notchClosedWidth;
        }

        function sideSwipeRestWidthForProgress(progressValue) {
            if (progressValue <= -0.5) return customCapsuleWidth;
            if (progressValue >= 0.5) return lyricsCapsuleWidth;
            return sideSwipeNormalRestWidth();
        }

        function customSideSwipeDragDistance() {
            const view = customSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(sideSwipeNormalRestWidth(), customCapsuleWidth + 4);
        }

        function lyricsSideSwipeDragDistance() {
            const view = lyricsSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(sideSwipeNormalRestWidth(), lyricsCapsuleWidth + 2);
        }

        function sideSwipeDragDistanceForDirection(direction) {
            if (direction === "left") return customSideSwipeDragDistance();
            if (direction === "right") return lyricsSideSwipeDragDistance();
            return sideSwipeNormalRestWidth();
        }

        function advanceSideSwipeProgress(currentProgress, deltaX, swipeAnchorProgress) {
            const anchor = swipeAnchorProgress !== undefined ? swipeAnchorProgress : currentProgress;
            let minProgress = hasCustomLeftItems ? -1 : 0;
            let maxProgress = 1;

            if (anchor <= -0.5) {
                // Starting from Custom: can only move right towards Normal (capped at 0, no skipping to Lyrics)
                maxProgress = 0;
            } else if (anchor >= 0.5) {
                // Starting from Lyrics: can only move left towards Normal (floored at 0, no skipping to Custom)
                minProgress = 0;
            }

            let nextProgress = Math.max(minProgress, Math.min(maxProgress, currentProgress));
            let remainingDelta = deltaX;

            if (remainingDelta > 0) {
                if (nextProgress < 0) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    const progressToCenter = Math.min(-nextProgress, remainingDelta / leftDistance);
                    nextProgress += progressToCenter;
                    remainingDelta -= progressToCenter * leftDistance;
                }

                if (remainingDelta > 0 && nextProgress < maxProgress) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    nextProgress = Math.min(maxProgress, nextProgress + remainingDelta / rightDistance);
                }
            } else if (remainingDelta < 0) {
                if (nextProgress > 0) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    const progressToCenter = Math.min(nextProgress, -remainingDelta / rightDistance);
                    nextProgress -= progressToCenter;
                    remainingDelta += progressToCenter * rightDistance;
                }

                if (remainingDelta < 0 && nextProgress > minProgress) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    nextProgress = Math.max(minProgress, nextProgress + remainingDelta / leftDistance);
                }
            }

            return Math.max(minProgress, Math.min(maxProgress, nextProgress));
        }

        function resolveSideSwipeSettle(startProgress, finalProgress, swipeVelocity) {
            let settleAction = "";
            let settleProgress = sideSwipeRestProgressForProgress(startProgress);
            let settleWidth = sideSwipeRestWidthForProgress(startProgress);
            const activationThreshold = 0.28;
            const velocity = swipeVelocity !== undefined ? swipeVelocity : 0;
            const flickRight = velocity > 0.35;
            const flickLeft = velocity < -0.35;

            if (startProgress <= -0.5) {
                // Starting from Custom: can ONLY settle to Normal (time) or stay in Custom!
                if (finalProgress >= -0.72 || flickRight) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = sideSwipeNormalRestWidth();
                } else {
                    settleAction = "custom";
                    settleProgress = -1;
                    settleWidth = customCapsuleWidth;
                }
            } else if (startProgress >= 0.5) {
                // Starting from Lyrics: can ONLY settle to Normal (time) or stay in Lyrics!
                if (finalProgress <= 0.72 || flickLeft) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = sideSwipeNormalRestWidth();
                } else {
                    settleAction = "lyrics";
                    settleProgress = 1;
                    settleWidth = lyricsCapsuleWidth;
                }
            } else {
                // Starting from Normal: can settle to Lyrics (+1), Custom (-1), or stay in Normal (0)!
                if (finalProgress >= activationThreshold || flickRight) {
                    settleAction = "lyrics";
                    settleProgress = 1;
                    settleWidth = lyricsCapsuleWidth;
                } else if (hasCustomLeftItems && (finalProgress <= -activationThreshold || flickLeft)) {
                    settleAction = "custom";
                    settleProgress = -1;
                    settleWidth = customCapsuleWidth;
                } else {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = sideSwipeNormalRestWidth();
                }
            }

            return {
                action: settleAction,
                progress: settleProgress,
                width: settleWidth
            };
        }

        function beginSideSwipeSettle(targetWidth) {
            sideSwipeSettling = true;
            mainCapsule.displayedWidth = targetWidth;
            sideSwipeSettleReset.restart();
        }

        function cancelSideSwipeSettle() {
            sideSwipeSettleReset.stop();
            sideSwipeSettling = false;
        }

        function finishSideSwipeSettle() {
            sideSwipeSettling = false;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        }

        function restartAutoHideTimer(duration) {
            autoHideTimer.interval = duration === undefined ? defaultAutoHideInterval : duration;
            autoHideTimer.restart();
        }

        function stopAutoHideTimer() {
            autoHideTimer.stop();
            autoHideTimer.interval = defaultAutoHideInterval;
        }

        function requestExpandedPlayerKeyboardFocus() {
            const shouldGrabFocus = !expandedPlayerKeyboardFocusRequested;
            expandedPlayerKeyboardFocusRequested = true;
            if (shouldGrabFocus)
                expandedPlayerFocusTimer.restart();
        }

        function releaseExpandedPlayerKeyboardFocus() {
            expandedPlayerKeyboardFocusRequested = false;
        }

        function clampTimerInput(value, minValue, maxValue) {
            const parsed = parseInt(value, 10);
            if (isNaN(parsed)) return minValue;
            return Math.max(minValue, Math.min(maxValue, parsed));
        }

        function syncTimerDuration(hours, minutes) {
            cancelTimerCompletionAnimation();
            timerSelectedHours = clampTimerInput(hours, 0, 23);
            timerSelectedMinutes = clampTimerInput(minutes, 0, 59);
            timerTotalSeconds = timerSelectedHours * 3600 + timerSelectedMinutes * 60;
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function toggleTimer(hours, minutes) {
            if (timerCompletionAnimating)
                cancelTimerCompletionAnimation();

            if (timerRunning) {
                timerRunning = false;
                return;
            }

            if (!timerActive || timerRemainingSeconds <= 0) {
                syncTimerDuration(hours, minutes);
                timerRemainingSeconds = timerTotalSeconds;
                timerActive = timerRemainingSeconds > 0;
            }

            if (timerRemainingSeconds > 0)
                timerRunning = true;
        }

        function resetTimer() {
            cancelTimerCompletionAnimation();
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function startTimerCompletionAnimation() {
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
            timerCompletionAnimating = true;
        }

        function cancelTimerCompletionAnimation() {
            timerCompletionAnimating = false;
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
        }

        function showExpandedTimerPage() {
            openTimerPageWhenExpanded = true;
            showExpandedPlayer(false);
            if (expandedPlayerLoader.item && expandedPlayerLoader.item.openTimerPage) {
                expandedPlayerLoader.item.openTimerPage();
                openTimerPageWhenExpanded = false;
            }
        }

        function showTransientCapsule(icon, progress, customText) {
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            if (root.autoHideSuppressesTransientReveal) return;
            if (blocksTransientSplit) return;

            const nextProgress = progress >= 0 ? progress : -1.0;
            const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
            const animateFromSide = currentTransientOriginSide();

            abortSideTransientMode();
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitOriginSide = animateFromSide;
            islandState = "split";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function showNotificationCapsule(appName, summary, body) {
            if (root.overviewVisible || islandState === "control_center"
                    || islandState === "expanded" || islandState === "file_shelf") return;

            const cleanedAppName = cleanNotificationText(appName);
            const cleanedSummary = cleanNotificationText(summary);
            const cleanedBody = cleanNotificationText(body);
            const resolvedSummary = cleanedSummary !== ""
                ? cleanedSummary
                : (cleanedBody !== "" ? cleanedBody : "New notification");

            abortSideTransientMode();
            clearTransientCapsule();
            notificationAppName = cleanedAppName !== "" ? cleanedAppName : "Notification";
            notificationSummary = resolvedSummary;
            notificationBody = cleanedSummary !== "" ? cleanedBody : "";
            notificationExpanded = false;
            islandState = "notification";
            restartAutoHideTimer(notificationAutoHideInterval);
            // Store in notification history
                if (notificationHistoryModel) {
                    notificationHistoryModel.insert(0, {
                        appName: cleanedAppName !== "" ? cleanedAppName : "Notification",
                        summary: resolvedSummary,
                        body: cleanedSummary !== "" ? cleanedBody : "",
                        timestamp: new Date()
                    });
                    if (notificationHistoryModel.count > 50)
                        notificationHistoryModel.remove(50, notificationHistoryModel.count - 50);
                }

        }

        function toggleNotificationExpansionIfNeeded() {
            if (islandState !== "notification" || !notificationLoader.item || !notificationLoader.item.hasOverflowContent)
                return false;

            if (notificationExpanded) {
                smartRestoreState();
                return true;
            }

            notificationExpanded = true;
            stopAutoHideTimer();
            return true;
        }

        function suppressCapsuleClick(cancelPreparedOverview) {
            if (cancelPreparedOverview === undefined) cancelPreparedOverview = false;
            if (cancelPreparedOverview && capsuleMouseArea.preparedOverviewOnPress) {
                root.cancelPreparedOverviewEverywhere();
                capsuleMouseArea.preparedOverviewOnPress = false;
            }
            capsuleMouseArea.suppressNextClick = true;
            swipeSuppressReset.restart();
        }

        function restoreRestingCapsule(forceImmediate) {
            if (forceImmediate === undefined) forceImmediate = false;
            const normalizedRestingState = normalizeRestingState(restingState);
            const targetSide = restingStateSide(normalizedRestingState);
            const shouldAnimateToSide = targetSide !== "none"
                && ((islandState === "long_capsule" && workspaceOriginSide === targetSide)
                    || (islandState === "split" && splitOriginSide === targetSide));

            if (!forceImmediate && shouldAnimateToSide) {
                expandedByPlayerAutoOpen = false;
                prepareRestingCapsuleGeometry();
                swipeTransitionProgress = restingStateProgress(normalizedRestingState);
                stopAutoHideTimer();
                sideTransientRestoreTimer.restart();
                return;
            }

            abortSideTransientMode();
            prepareRestingCapsuleGeometry();
            islandState = normalizedRestingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = normalizeRestingState(nextState);
        }

        function smartRestoreState() {
            if (widgetStagingActive)
                return;
            restoreRestingCapsule();
        }

        function showRestingCapsule(nextState) {
            setRestingState(nextState);
            restoreRestingCapsule();
            stopAutoHideTimer();
        }

        function showExpandedPlayer(autoOpened) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) restartAutoHideTimer();
            else stopAutoHideTimer();
        }

        function showBluetoothExpanded(device) {
            if (!device || root.overviewVisible || islandState === "control_center"
                    || islandState === "notification" || islandState === "file_shelf")
                return;

            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            bluetoothExpandedDevice = device;
            islandState = "bluetooth_expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = false;
            restartAutoHideTimer(bluetoothExpandedAutoHideInterval);
        }

        function showControlCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "control_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        property string widgetLibraryTargetMode: "expanded"
        property int widgetLibraryTargetPageIndex: 0
        property int widgetLibraryTargetSlotIndex: 0

        // Staging workflow for Widget Placement
        property bool widgetStagingActive: false
        property string stagedWidgetId: ""
        property string stagedSizeType: "full"
        property int stagedSlotSpan: 1
        property string preStagingNotchMode: "notch"
        property string preStagingIslandState: "normal"

        // Staged widget context for live preview loader in floating staging tray
        readonly property var stagingWidgetContext: ({
            activePlayer: islandContainer.activePlayer,
            currentTrack: islandContainer.currentTrack,
            currentArtist: islandContainer.currentArtist,
            currentArtUrl: islandContainer.currentArtUrl,
            lyricsText: islandContainer.lyricsDisplayText,
            timePlayed: islandContainer.timePlayed,
            timeTotal: islandContainer.timeTotal,
            trackProgress: islandContainer.trackProgress,
            isPlaying: islandContainer.activePlayer ? islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing : false,
            batteryCapacity: islandContainer.batteryCapacity,
            isCharging: islandContainer.isCharging,
            currentCpuUsage: islandContainer.currentCpuUsage,
            currentRamUsage: islandContainer.currentRamUsage,
            currentTime: timeObj.currentTime,
            currentDateLabel: timeObj.currentDateLabel,
            iconFontFamily: root.iconFontFamily,
            textFontFamily: root.textFontFamily,
            heroFontFamily: root.heroFontFamily,
            faceScale: 0.85,
            circleDiameter: 48,
            uiScale: 1.0,
            isEditMode: false
        })

        function stageWidgetForPlacement(widgetId, sizeType, slotSpan) {
            preStagingNotchMode = userConfig.notchMode;
            preStagingIslandState = (islandState === "widget_library") ? "normal" : islandState;

            stagedWidgetId = widgetId;
            stagedSizeType = sizeType;
            stagedSlotSpan = slotSpan || 1;
            widgetStagingActive = true;
            isDraggingWidgetFromLibrary = false;
            draggedWidgetData = null;
            hoveredSlotIndex = -1;

            if (sizeType === "full") {
                islandState = "expanded";
                rememberedPlayerPage = 0;
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                if (expandedPlayerLoader.item && expandedPlayerLoader.item.showPage)
                    expandedPlayerLoader.item.showPage(0);
            } else if (sizeType === "minimum") {
                if (userConfig.notchMode === "circle") {
                    userConfig.setNotchMode(preStagingNotchMode === "pill" ? "pill" : "notch");
                }
                islandState = "normal";
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                if (closedWidgetLoader.item)
                    closedWidgetLoader.item.currentPageIndex = 0;
            } else if (sizeType === "circle") {
                userConfig.setNotchMode("circle");
                islandState = "normal";
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                if (circleClosedLoader.item)
                    circleClosedLoader.item.currentPageIndex = 0;
            }
        }

        function cancelWidgetStaging() {
            widgetStagingActive = false;
            stagedWidgetId = "";
            stagedSizeType = "full";
            stagedSlotSpan = 1;
            isDraggingWidgetFromLibrary = false;
            draggedWidgetData = null;
            hoveredSlotIndex = -1;
            if (userConfig && userConfig.notchMode !== preStagingNotchMode) {
                userConfig.setNotchMode(preStagingNotchMode);
            }
            islandState = preStagingIslandState;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            restoreRestingCapsule(true);
        }

        function commitStagedWidgetToSlot(pageIndex, slotIndex) {
            if (!widgetStagingActive || stagedWidgetId === "") return;
            if (stagedSizeType === "full") {
                userConfig.setSlotWidget("expanded", pageIndex, slotIndex, stagedWidgetId, stagedSlotSpan);
            } else if (stagedSizeType === "minimum") {
                userConfig.setSlotWidget("minimum", pageIndex, slotIndex, stagedWidgetId, 1);
            } else if (stagedSizeType === "circle") {
                userConfig.setSlotWidget("circle", pageIndex, 0, stagedWidgetId, 1);
            }
            widgetStagingActive = false;
            stagedWidgetId = "";
            stagedSizeType = "full";
            stagedSlotSpan = 1;
            isDraggingWidgetFromLibrary = false;
            draggedWidgetData = null;
            hoveredSlotIndex = -1;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            restoreRestingCapsule(true);
        }

        // Drag-and-drop from Widget Library into notch
        property bool isDraggingWidgetFromLibrary: false
        property var draggedWidgetData: null
        property point dragPointerPos: Qt.point(0, 0)
        property int hoveredSlotIndex: -1
        property string preDragIslandState: "normal"
        property string preDragNotchMode: "pill"
        property int preDragExpandedPage: 0

        function handleWidgetDragStarted(widgetId, sizeType, slotSpan, winX, winY) {
            preDragIslandState = islandState;
            preDragNotchMode = userConfig.notchMode;
            preDragExpandedPage = rememberedPlayerPage;

            draggedWidgetData = {
                widgetId: widgetId,
                sizeType: sizeType,
                slotSpan: slotSpan || 1
            };
            dragPointerPos = Qt.point(winX, winY);
            isDraggingWidgetFromLibrary = true;

            if (sizeType === "full") {
                // Show expanded notch on the page the user was on when opening library
                islandState = "expanded";
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                if (expandedPlayerLoader.item && expandedPlayerLoader.item.showPage) {
                    expandedPlayerLoader.item.showPage(preDragExpandedPage);
                }
            } else if (sizeType === "minimum") {
                // Show closed/pill notch
                if (userConfig.notchMode === "circle") {
                    userConfig.setNotchMode(preDragNotchMode === "pill" ? "pill" : "notch");
                }
                islandState = "normal";
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            } else if (sizeType === "circle") {
                // Show circle notch
                userConfig.setNotchMode("circle");
                islandState = "normal";
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            }
            updateDragHitTest(winX, winY);
        }

        function handleWidgetDragMoved(winX, winY) {
            dragPointerPos = Qt.point(winX, winY);
            updateDragHitTest(winX, winY);
        }

        function isPointOverCapsule(winX, winY) {
            const capX = mainCapsule.x;
            const capY = mainCapsule.y;
            const capW = mainCapsule.width;
            const capH = mainCapsule.height;
            return winX >= capX - 30 && winX <= capX + capW + 30
                && winY >= capY - 30 && winY <= capY + capH + 30;
        }

        function updateDragHitTest(winX, winY) {
            if (!isPointOverCapsule(winX, winY)) {
                hoveredSlotIndex = -1;
                return;
            }

            if (draggedWidgetData && draggedWidgetData.sizeType === "full") {
                const capX = mainCapsule.x;
                const capW = mainCapsule.width;
                const contentX = capX + 16;
                const contentW = Math.max(100, capW - 32);
                const currentPages = (userConfig.widgetLayouts && userConfig.widgetLayouts.expanded)
                    ? userConfig.widgetLayouts.expanded.pages : [];
                const curPageIdx = Math.max(0, Math.min((currentPages ? currentPages.length - 1 : 0), rememberedPlayerPage));
                const curPage = (currentPages && currentPages.length > 0) ? currentPages[curPageIdx] : null;
                const slots = (curPage && curPage.slots) ? curPage.slots : 3;
                const relX = winX - contentX;
                const slotW = contentW / slots;
                const sIdx = Math.max(0, Math.min(slots - 1, Math.floor(relX / slotW)));
                hoveredSlotIndex = sIdx;
            } else {
                hoveredSlotIndex = 0;
            }
        }

        function handleWidgetDragEnded(winX, winY) {
            if (!isDraggingWidgetFromLibrary || !draggedWidgetData) {
                isDraggingWidgetFromLibrary = false;
                draggedWidgetData = null;
                return;
            }

            const wData = draggedWidgetData;
            const hit = isPointOverCapsule(winX, winY);

            if (hit) {
                if (wData.sizeType === "full") {
                    const targetPage = widgetLibraryTargetMode === "expanded" && widgetLibraryTargetPageIndex >= 0
                        ? widgetLibraryTargetPageIndex : rememberedPlayerPage;
                    const targetSlot = hoveredSlotIndex >= 0 ? hoveredSlotIndex : 0;
                    userConfig.setSlotWidget("expanded", targetPage, targetSlot, wData.widgetId, wData.slotSpan);
                } else if (wData.sizeType === "minimum") {
                    const targetPage = widgetLibraryTargetMode === "minimum" && widgetLibraryTargetPageIndex >= 0
                        ? widgetLibraryTargetPageIndex : (closedWidgetLoader.item ? closedWidgetLoader.item.currentPageIndex : 0);
                    userConfig.setSlotWidget("minimum", targetPage, 0, wData.widgetId, 1);
                    restoreRestingCapsule(true);
                } else if (wData.sizeType === "circle") {
                    const targetPage = widgetLibraryTargetPageIndex >= 0
                        ? widgetLibraryTargetPageIndex : (circleClosedLoader.item ? circleClosedLoader.item.currentPageIndex : 0);
                    userConfig.setSlotWidget("circle", targetPage, 0, wData.widgetId, 1);
                    restoreRestingCapsule(true);
                }
            } else {
                if (userConfig && userConfig.notchMode !== preDragNotchMode) {
                    userConfig.setNotchMode(preDragNotchMode);
                }
                islandState = preDragIslandState;
                mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            }

            isDraggingWidgetFromLibrary = false;
            draggedWidgetData = null;
            hoveredSlotIndex = -1;
        }

        function showWidgetLibrary(mode, pageIndex, slotIndex) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            widgetLibraryTargetMode = mode !== undefined ? mode : (userConfig.notchMode === "circle" ? "circle" : (islandContainer.islandState === "expanded" ? "expanded" : "minimum"));
            if (pageIndex !== undefined) {
                widgetLibraryTargetPageIndex = pageIndex;
            } else if (widgetLibraryTargetMode === "circle" && circleClosedLoader.item) {
                widgetLibraryTargetPageIndex = circleClosedLoader.item.currentPageIndex;
            } else if (widgetLibraryTargetMode === "expanded") {
                widgetLibraryTargetPageIndex = rememberedPlayerPage;
            } else {
                widgetLibraryTargetPageIndex = 0;
            }
            widgetLibraryTargetSlotIndex = slotIndex !== undefined ? slotIndex : 0;
            islandState = "widget_library";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showNotificationCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "notification_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }


        function showWallpaperPicker() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "wallpaper_picker";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showApplicationLauncher() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "application_launcher";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showFileShelf(manuallyOpened) {
            const manual = manuallyOpened === true;
            if (islandState === "file_shelf") {
                if (manual) {
                    showExpandedPlayer();
                    if (expandedPlayerLoader.item && expandedPlayerLoader.item.showPage) {
                        expandedPlayerLoader.item.showPage(preFileShelfPage);
                    }
                }
                return;
            }

            preFileShelfPage = (expandedPlayerLoader.item && expandedPlayerLoader.item.currentPage !== undefined)
                ? expandedPlayerLoader.item.currentPage : rememberedPlayerPage;
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            fileShelfOpenedManually = manual;
            islandState = "file_shelf";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function closeAutoOpenedFileShelf() {
            if (islandState === "file_shelf" && !fileShelfOpenedManually)
                smartRestoreState();
        }

        function showCustomCapsule() {
            if (!hasCustomLeftItems) {
                showTimeCapsule();
                return;
            }

            systemState.refreshMissingValues();
            showRestingCapsule("custom");
        }

        function showLyricsCapsule() {
            showRestingCapsule("lyrics");
        }

        function showTimeCapsule() {
            showRestingCapsule("normal");
        }

        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;
            if (root.autoHideSuppressesTransientReveal) return;
            if (islandState === "control_center" || islandState === "notification") return;
            const animateFromSide = currentTransientOriginSide();
            clearTransientCapsule();
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = animateFromSide;
            splitOriginSide = "none";
            islandState = "long_capsule";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        Timer { id: autoHideTimer; interval: islandContainer.defaultAutoHideInterval; onTriggered: islandContainer.smartRestoreState() }
        Timer {
            id: islandTimerTick
            interval: 1000
            repeat: true
            running: islandContainer.timerRunning
            onTriggered: {
                const nextRemainingSeconds = Math.max(0, islandContainer.timerRemainingSeconds - 1);
                if (nextRemainingSeconds <= 0) {
                    islandContainer.startTimerCompletionAnimation();
                    islandContainer.timerRemainingSeconds = 0;
                    islandContainer.timerRunning = false;
                    islandContainer.timerActive = false;
                } else {
                    islandContainer.timerRemainingSeconds = nextRemainingSeconds;
                }
            }
        }
        Timer {
            id: osdProgressAnimationReset
            interval: 0
            onTriggered: islandContainer.osdProgressAnimationEnabled = true
        }
        Timer {
            id: sideTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.workspaceOriginSide = "none";
                islandContainer.splitOriginSide = "none";
                islandContainer.prepareRestingCapsuleGeometry();
                islandContainer.islandState = islandContainer.normalizeRestingState(islandContainer.restingState);
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }
        Timer {
            id: sideSwipeSettleReset
            interval: islandContainer.swipeAnimationDuration + 10
            onTriggered: islandContainer.finishSideSwipeSettle()
        }
        Timer {
            id: hoverExpandDelayTimer
            interval: userConfig.notchHoverOpenDelayMs
            repeat: false
            onTriggered: {
                if (!root.islandPointerInside) return;
                if (!root.hoverExpandEnabled) return;

                const current = islandContainer.islandState;
                const target = root.configuredHoverExpandAction === 2 ? "control_center" : "expanded";
                if (current === target) return;
                if (current !== "normal" && current !== "custom" && current !== "lyrics")
                    return;

                islandContainer.hoverExpandedActive = true;
                if (root.configuredHoverExpandAction === 2)
                    islandContainer.showControlCenter();
                else
                    islandContainer.showExpandedPlayer(false);
            }
        }
        Timer {
            id: hoverCollapseDelayTimer
            interval: userConfig.notchHoverCloseDelayMs
            repeat: false
            onTriggered: {
                if (root.islandPointerInside) return;
                if (root.anyConnectivityDetailMounted) return;
                if (controlCenterLoader.item && controlCenterLoader.item.activeInteraction) return;
                if (!islandContainer.hoverExpandedActive) return;
                islandContainer.hoverExpandedActive = false;
                islandContainer.smartRestoreState();
            }
        }

        function syncCustomCapsuleWidth() {
            const view = customSwipeLoader.item;
            if (!view) return;
            customCapsuleWidth = Math.max(userConfig.notchClosedWidth, Math.max(220, Math.min(root.width - 48, view.preferredWidth)));
        }

        function syncLyricsCapsuleWidth() {
            const view = lyricsSwipeLoader.item;
            if (!view) return;
            lyricsCapsuleWidth = Math.max(userConfig.notchClosedWidth, Math.max(220, Math.min(root.width - 48, view.preferredWidth)));
        }

        onCurrentTrackChanged: {
            if (userConfig.disableAutoExpandOnTrackChange) return;
            if (currentTrack !== ""
                    && islandState !== "control_center"
                    && islandState !== "notification"
                    && islandState !== "bluetooth_expanded"
                    && islandState !== "file_shelf") {
                if (root.autoHideSuppressesTransientReveal) return;
                if (islandState === "expanded" && !expandedByPlayerAutoOpen) return;
                showExpandedPlayer(true);
            }
        }

        // --- UI 渲染：灵动岛主干 ---
        Rectangle {
            id: mainCapsule
            z: 5
            property int morphDuration: 300
            readonly property bool notificationHistorySurface: islandContainer.islandState === "notification_center"
            property real outlineWidth: root.overviewContentVisible || notificationHistorySurface ? 1 : 0
            property color outlineColor: root.overviewContentVisible
                ? root.overviewCapsuleBorderColor
                : (notificationHistorySurface ? "#1affffff" : StyleTokens.clearBlack)
            property real displayedWidth: baseTargetWidth
            readonly property real baseTargetWidth: {
                if (root.overviewVisible) return root.overviewCapsuleWidth;

                if (userConfig.notchMode === "circle") {
                    switch (islandContainer.islandState) {
                    case "control_center":
                        return 420;
                    case "notification_center":
                        return 410;
                    case "wallpaper_picker":
                    case "application_launcher":
                        return 1100;
                    case "widget_library":
                        return Math.min(root.width - 48, 700);
                    case "file_shelf":
                    case "expanded":
                    case "bluetooth_expanded":
                        return userConfig.notchOpenWidth;
                    case "notification":
                        if (!notificationLoader.item) return 272;
                        return Math.max(
                            notificationLoader.item.minimumWidth,
                            Math.min(root.width - 48, notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth)
                        );
                    case "long_capsule":
                        return Math.max(userConfig.notchCircleClosedSize + 110, 190);
                    case "split":
                        return islandContainer.splitCapsuleWidth;
                    default:
                        return userConfig.notchCircleClosedSize;
                    }
                }

                if (sideTransientRestoreTimer.running) {
                    if (islandContainer.restingState === "lyrics"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "right")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "right"))) {
                        return islandContainer.lyricsCapsuleWidth;
                    }

                    if (islandContainer.restingState === "custom"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "left")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "left"))) {
                        return islandContainer.customCapsuleWidth;
                    }
                }

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "long_capsule":
                    return Math.max(userConfig.notchClosedWidth, 220);
                case "custom":
                    return Math.max(userConfig.notchClosedWidth, islandContainer.customCapsuleWidth);
                case "lyrics":
                    return Math.max(userConfig.notchClosedWidth, islandContainer.lyricsCapsuleWidth);
                case "control_center":
                    return 420;
                case "notification_center":
                    return 410;
                case "wallpaper_picker":
                case "application_launcher":
                    return 1100;
                case "widget_library":
                    return Math.min(root.width - 48, 700);
                case "file_shelf":
                case "expanded":
                case "bluetooth_expanded":
                    return userConfig.notchOpenWidth;
                case "notification":
                    if (!notificationLoader.item) return 272;
                    return Math.max(
                        notificationLoader.item.minimumWidth,
                        Math.min(root.width - 48, notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth)
                    );
                default:
                    return islandContainer.currentTrack !== ""
                        ? Math.round(userConfig.notchClosedWidth + 2 * Math.max(0, userConfig.notchClosedHeight - 12) + 20)
                        : userConfig.notchClosedWidth;
                }
            }
            readonly property real targetHeight: {
                if (root.overviewVisible) return root.overviewCapsuleHeight;

                switch (islandContainer.islandState) {
                case "control_center":
                    return controlCenterLoader.item && controlCenterLoader.item.powerViewActive
                        ? 150
                        : 320 + (controlCenterLoader.item ? controlCenterLoader.item.controlCenterExtraHeight : 32);
                case "notification_center":
                    return notificationCenterLoader.item ? notificationCenterLoader.item.contentHeight : 200;
                case "wallpaper_picker":
                case "application_launcher":
                    return 260;
                case "widget_library":
                    return 520;
                case "file_shelf":
                case "expanded":
                case "bluetooth_expanded":
                    return userConfig.notchOpenHeight;
                case "notification":
                    return notificationLoader.item
                        ? Math.max(56, notificationLoader.item.preferredHeight)
                        : 56;
                default:
                    if (userConfig.notchMode === "circle")
                        return userConfig.notchCircleClosedSize;
                    return userConfig.notchClosedHeight;
                }
            }
            readonly property real targetRadius: {
                if (root.overviewVisible) return root.overviewCapsuleRadius;

                switch (islandContainer.islandState) {
                case "control_center":
                    return 34;
                case "notification_center":
                    return mainCapsule.targetHeight * 36 / 165;
                case "wallpaper_picker":
                case "application_launcher":
                    return 34;
                case "widget_library":
                    return 26;
                case "file_shelf":
                case "expanded":
                case "bluetooth_expanded":
                    return userConfig.notchBottomCornerRadius * 2;
                case "notification":
                    return islandContainer.notificationExpanded ? 28 : mainCapsule.targetHeight / 2;
                default:
                    if (userConfig.notchMode === "circle")
                        return mainCapsule.targetHeight / 2;
                    return (userConfig.notchMode === "notch") ? userConfig.notchBottomCornerRadius : (mainCapsule.targetHeight / 2);
                }
            }
            function sideSwipeWidthForProgress(progressValue) {
                const normalWidth = islandContainer.currentTrack !== ""
                    ? Math.round(userConfig.notchClosedWidth + 2 * Math.max(0, userConfig.notchClosedHeight - 12) + 20)
                    : userConfig.notchClosedWidth;
                if (progressValue < 0)
                    return normalWidth + (islandContainer.customCapsuleWidth - normalWidth)
                        * islandContainer.clamp01(-progressValue);
                if (progressValue > 0)
                    return normalWidth + (islandContainer.lyricsCapsuleWidth - normalWidth)
                        * islandContainer.clamp01(progressValue);
                return normalWidth;
            }
            readonly property real sideSwipePreviewWidth: mainCapsule.sideSwipeWidthForProgress(
                islandContainer.swipeTransitionProgress
            )
            color: root.overviewContentVisible
                ? root.overviewCapsuleColor
                : ((userConfig.notchMode === "notch")
                    ? StyleTokens.transparent
                    : (notificationHistorySurface ? "#080808" : Qt.rgba(0, 0, 0, userConfig.islandBackgroundOpacity / 100.0)))
            y: root.capsuleTopMargin
                - (1 - root.autoHideProgress) * (targetHeight + root.capsuleTopMargin + 8)
            x: parent ? parent.width * userConfig.islandPositionX / 100 - width / 2 : 0
            clip: true
            width: displayedWidth
            height: targetHeight
            radius: targetRadius
            opacity: root.autoHideProgress
            scale: 0.96 + root.autoHideProgress * 0.04
            transformOrigin: Item.Top

            onBaseTargetWidthChanged: {
                if (!capsuleMouseArea.sideSwipeInteractive && !islandContainer.sideSwipeDragging && !islandContainer.sideSwipeSettling)
                    displayedWidth = baseTargetWidth;
            }

            Behavior on displayedWidth {
                enabled: !islandContainer.sideSwipeDragging && !capsuleMouseArea.sideSwipeInteractive

                NumberAnimation {
                    duration: islandContainer.sideSwipeSettling ? islandContainer.swipeAnimationDuration : mainCapsule.morphDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !(controlCenterLoader.item && controlCenterLoader.item.batteryDrawerMoving)

                NumberAnimation {
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on radius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 280; easing.type: Easing.InOutQuad } }
            Behavior on outlineWidth { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            Behavior on outlineColor { ColorAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            border.width: (userConfig.notchMode === "notch") && !root.overviewContentVisible ? 0 : outlineWidth
            border.color: outlineColor

            NotchSurface {
                anchors.fill: parent
                z: -2
                visible: (userConfig.notchMode === "notch") && !root.overviewContentVisible
                color: mainCapsule.notificationHistorySurface ? "#080808" : Qt.rgba(0, 0, 0, userConfig.islandBackgroundOpacity / 100.0)
                borderColor: mainCapsule.outlineColor
                borderWidth: mainCapsule.outlineWidth
                topCornerRadius: userConfig.notchTopCornerRadius
                bottomCornerRadius: islandContainer.islandState === "expanded" || islandContainer.islandState === "control_center"
                    ? userConfig.notchBottomCornerRadius + 6
                    : userConfig.notchBottomCornerRadius
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(parent.radius - 1, 0)
                color: StyleTokens.transparent
                border.width: 1
                border.color: StyleTokens.overviewInnerBorder
                opacity: root.overviewContentVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.overviewContentVisible ? 260 : 140
                        easing.type: Easing.InOutQuad
                    }
                }
            }


            HoverHandler {
                id: capsuleHoverHandler
                enabled: root.hoverExpandEnabled || root.autoHideEnabled

                onHoveredChanged: {
                    if (hovered) {
                        if (root.autoHideEnabled) {
                            root.autoHidePointerInside = true;
                            root.showAutoHiddenIsland();
                        }
                        if (root.hoverExpandEnabled) {
                            hoverCollapseDelayTimer.stop();
                            hoverExpandDelayTimer.restart();
                        }
                    } else {
                        if (root.autoHideEnabled) {
                            root.autoHidePointerInside = false;
                            root.scheduleAutoHide();
                        }
                        if (root.hoverExpandEnabled) {
                            hoverExpandDelayTimer.stop();
                            hoverCollapseDelayTimer.restart();
                        }
                    }
                }
            }

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
                enabled: !root.overviewVisible && twoFingerTouchArea.touchPoints.length < 2
                acceptedButtons: root.dynamicIslandAcceptedButtons
                preventStealing: swipeArmed
                hoverEnabled: false
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property real swipeLastX: 0
                readonly property real sideSwipeVerticalTolerance: 24
                property bool swipeArmed: false
                property bool swipeMoved: false
                property bool sideSwipeInteractive: false
                property bool suppressNextClick: false
                property bool preparedOverviewOnPress: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onPressed: (mouse) => {
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    swipeStartX = mappedPoint.x;
                    swipeStartY = mappedPoint.y;
                    islandContainer.cancelSideSwipeSettle();
                    swipeArmed = mouse.button === Qt.LeftButton
                        && islandContainer.canShowSideSwipe;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeLastX = mappedPoint.x;
                    swipeMoved = false;
                    sideSwipeInteractive = swipeArmed;
                    islandContainer.sideSwipeDragging = swipeArmed;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;

                    let pressedAction = "";
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        pressedAction = userConfig.dynamicIslandPrimaryAction;
                    } else if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        pressedAction = userConfig.dynamicIslandSecondaryAction;
                    }

                    preparedOverviewOnPress = pressedAction === "openOverview"
                        || (pressedAction === "toggleOverview" && root.overviewPhase === "closed");
                    if (preparedOverviewOnPress)
                        root.prepareOverviewEverywhere();
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !swipeArmed || suppressNextClick || twoFingerTouchArea.touchPoints.length >= 2) return;

                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    const deltaX = mappedPoint.x - swipeLastX;
                    const deltaY = Math.abs(mappedPoint.y - swipeStartY);
                    const adjustedDeltaX = deltaY < sideSwipeVerticalTolerance ? deltaX : 0;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        islandContainer.swipeTransitionProgress,
                        adjustedDeltaX,
                        swipeStartProgress
                    );

                    swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || deltaY > 6;
                    swipeLastX = mappedPoint.x;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        if (preparedOverviewOnPress)
                            root.cancelPreparedOverviewEverywhere();
                        preparedOverviewOnPress = false;
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }
                    let settleResult = {
                        action: "",
                        progress: islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress),
                        width: islandContainer.sideSwipeRestWidthForProgress(swipeStartProgress)
                    };

                    if (swipeArmed)
                        settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                    sideSwipeInteractive = false;
                    islandContainer.sideSwipeDragging = false;

                    if (swipeArmed)
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                    else
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;

                    if (swipeArmed) {
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = settleResult.progress;
                    }
                    swipeArmed = false;
                    swipeMoved = false;
                }

                onCanceled: {
                    if (preparedOverviewOnPress)
                        root.cancelPreparedOverviewEverywhere();
                    swipeArmed = false;
                    swipeMoved = false;
                    sideSwipeInteractive = false;
                    islandContainer.sideSwipeDragging = false;
                    suppressNextClick = false;
                    preparedOverviewOnPress = false;
                    swipeSuppressReset.stop();
                    mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                }

                onClicked: (mouse) => {
                    islandContainer.hoverExpandedActive = false;
                    hoverExpandDelayTimer.stop();
                    hoverCollapseDelayTimer.stop();

                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        preparedOverviewOnPress = false;
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        if (islandContainer.toggleNotificationExpansionIfNeeded()) {
                            if (preparedOverviewOnPress)
                                root.cancelPreparedOverviewEverywhere();
                            preparedOverviewOnPress = false;
                            return;
                        }

                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandPrimaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandSecondaryAction);
                    }
                }
            }

            MultiPointTouchArea {
                id: twoFingerTouchArea
                anchors.fill: parent
                z: 0
                enabled: !root.overviewVisible && islandContainer.canShowSideSwipe
                mouseEnabled: false
                minimumTouchPoints: 2
                maximumTouchPoints: 2

                property real swipeStartX: 0
                property real swipeStartProgress: 0
                property bool swipeMoved: false

                onPressed: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea,
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);
                    swipeStartX = centerPoint.x;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeMoved = false;
                    islandContainer.sideSwipeDragging = true;
                    islandContainer.cancelSideSwipeSettle();
                }

                onUpdated: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea,
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);

                    const deltaX = (centerPoint.x - swipeStartX) * 1.4;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        swipeStartProgress,
                        deltaX,
                        swipeStartProgress
                    );

                    if (Math.abs(nextProgress - swipeStartProgress) > 0.03) {
                        swipeMoved = true;
                    }

                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    islandContainer.sideSwipeDragging = false;
                    if (swipeMoved) {
                        const settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                        islandContainer.beginSideSwipeSettle(settleResult.width);

                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress);
                    }
                    swipeMoved = false;
                }

                onCanceled: {
                    islandContainer.sideSwipeDragging = false;
                    islandContainer.swipeTransitionProgress = islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress);
                    swipeMoved = false;
                }
            }



            Loader {
                id: customSwipeLoader
                anchors.fill: parent
                active: islandContainer.customSwipeVisible
                    && userConfig.notchMode !== "circle"
                asynchronous: false
                visible: active

                onLoaded: islandContainer.syncCustomCapsuleWidth()

                sourceComponent: Component {
                    SwipeCustomInfoLayer {
                        items: islandContainer.customLeftItems
                        cavaLevels: islandContainer.cavaLevels
                        timeText: timeObj.currentTime
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.heroFontFamily
                        timeFontFamily: root.heroFontFamily
                        textPixelSize: root.bodyFontSize
                        iconPixelSize: root.iconFontSize
                        minimumWidth: Math.max(userConfig.notchClosedWidth, 220)
                        maximumWidth: Math.max(Math.max(userConfig.notchClosedWidth, 220), root.width - 48)
                        transitionProgress: islandContainer.swipeTransitionProgress
                        recordingActive: islandContainer.screenRecordingActive
                        showSecondaryText: islandContainer.workspaceOriginSide !== "left"
                            && islandContainer.splitOriginSide !== "left"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncCustomCapsuleWidth()
                    }
                }
            }

            Loader {
                id: lyricsSwipeLoader
                anchors.fill: parent
                active: islandContainer.lyricsSwipeVisible
                    && userConfig.notchMode !== "circle"
                    && ((!userConfig.showBoringFace && islandContainer.currentTrack === "") || islandContainer.swipeTransitionProgress > 0.01)
                asynchronous: false
                visible: active

                onLoaded: islandContainer.syncLyricsCapsuleWidth()

                sourceComponent: Component {
                    SwipeLyricsLayer {
                        lyricText: islandContainer.lyricsDisplayText
                        currentArtUrl: islandContainer.currentArtUrl
                        cavaLevels: islandContainer.cavaLevels
                        timeText: timeObj.currentTime
                        textFontFamily: root.textFontFamily
                        timeFontFamily: root.timeFontFamily
                        textPixelSize: root.bodyFontSize
                        minimumWidth: userConfig.notchClosedWidth
                        maximumWidth: Math.max(userConfig.notchClosedWidth, root.width - 48)
                        transitionProgress: islandContainer.rightSwipeProgress
                        recordingActive: islandContainer.screenRecordingActive
                        showSecondaryText: islandContainer.workspaceOriginSide !== "right"
                            && islandContainer.splitOriginSide !== "right"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncLyricsCapsuleWidth()
                    }
                }
            }

            // Legacy closed notch live activity layer (superseded by widget-based ClosedWidgetLayer)
            Loader {
                id: notchLiveActivityLoader
                anchors.fill: parent
                active: false
                asynchronous: false
                visible: false

                sourceComponent: Component {
                    NotchLiveActivityLayer {
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        isPlaying: islandContainer.activePlayer ? islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing : false
                        cavaLevels: islandContainer.cavaLevels
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                    }
                }
            }

            // Legacy closed notch face animation (boring_face is now a Circle widget)
            Loader {
                id: boringFaceLoader
                anchors.centerIn: parent
                active: false
                asynchronous: false
                visible: false

                sourceComponent: Component {
                    BoringFaceAnimation {}
                }
            }

            // Widget-based closed notch layer — renders Minimum widgets from widgetLayouts.minimum.
            Loader {
                id: closedWidgetLoader
                anchors.fill: parent
                active: !root.overviewVisible
                    && userConfig.notchMode !== "circle"
                    && islandContainer.islandState === "normal"
                    && Math.abs(islandContainer.swipeTransitionProgress) < 0.01
                asynchronous: false
                visible: active
                z: 2

                sourceComponent: Component {
                    ClosedWidgetLayer {
                        showCondition: true
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        isPlaying: islandContainer.activePlayer ? islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing : false
                        trackProgress: islandContainer.trackProgress
                        currentTime: timeObj.currentTime
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        isDropTargetActive: islandContainer.isDraggingWidgetFromLibrary
                            && islandContainer.draggedWidgetData !== null
                            && islandContainer.draggedWidgetData.sizeType === "minimum"
                        onExpandRequested: islandContainer.showExpandedPlayer(false)
                        onWidgetLibraryRequested: function(mode, pageIndex, slotIndex) {
                            islandContainer.showWidgetLibrary(mode, pageIndex, slotIndex);
                        }
                    }
                }
            }

            Loader {
                id: circleClosedLoader
                anchors.fill: parent
                active: !root.overviewVisible
                    && userConfig.notchMode === "circle"
                    && islandContainer.islandState !== "expanded"
                    && islandContainer.islandState !== "bluetooth_expanded"
                    && islandContainer.islandState !== "control_center"
                    && islandContainer.islandState !== "notification_center"
                    && islandContainer.islandState !== "wallpaper_picker"
                    && islandContainer.islandState !== "application_launcher"
                    && islandContainer.islandState !== "file_shelf"
                    && islandContainer.islandState !== "notification"
                    && islandContainer.islandState !== "long_capsule"
                    && islandContainer.islandState !== "split"
                    && (islandContainer.islandState !== "widget_library" || islandContainer.isDraggingWidgetFromLibrary)
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    CircleWidgetLayer {
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        isPlaying: islandContainer.activePlayer ? islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing : false
                        trackProgress: islandContainer.trackProgress
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        currentCpuUsage: islandContainer.currentCpuUsage
                        currentRamUsage: islandContainer.currentRamUsage
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        isDropTargetActive: islandContainer.isDraggingWidgetFromLibrary
                            && islandContainer.draggedWidgetData !== null
                            && islandContainer.draggedWidgetData.sizeType === "circle"
                        onExpandRequested: islandContainer.showExpandedPlayer(false)
                        onWidgetLibraryRequested: function(mode, pageIndex, slotIndex) {
                            islandContainer.showWidgetLibrary(mode, pageIndex, slotIndex);
                        }
                    }
                }
            }

            Loader {
                id: splitIconLoader
                anchors.fill: parent
                active: !root.overviewVisible && islandContainer.splitShowsIconOnly
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    SplitIconLayer {
                        iconText: islandContainer.splitIcon
                        iconFontFamily: root.iconFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: osdLayerLoader
                anchors.fill: parent
                active: !root.overviewVisible && islandContainer.splitUsesExtendedLayout
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    OsdLayer {
                        iconText: islandContainer.splitIcon
                        progress: islandContainer.osdProgress
                        customText: islandContainer.osdCustomText
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: workspaceLayerLoader
                anchors.fill: parent
                active: !root.overviewVisible
                    && islandContainer.islandState === "long_capsule"
                    && (islandContainer.workspaceOriginSide !== "none"
                        || Math.abs(islandContainer.swipeTransitionProgress) < 0.001)
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    WorkspaceLayer {
                        workspaceId: islandContainer.currentWs
                        displayText: "Workspace " + islandContainer.currentWs
                        textFontFamily: root.textFontFamily
                        textPixelSize: root.bodyFontSize
                        animateVisibility: islandContainer.restingState === "normal"
                        transitionProgress: islandContainer.swipeTransitionProgress
                        showCondition: true
                        slideDirection: islandContainer.workspaceOriginSide
                    }
                }
            }

            Loader {
                id: expandedPlayerLoader
                anchors.fill: parent
                active: islandContainer.expandedLayerVisible
                asynchronous: false
                visible: active
                onLoaded: {
                    if (islandContainer.openTimerPageWhenExpanded
                            && item && item.openTimerPage) {
                        item.openTimerPage();
                        islandContainer.openTimerPageWhenExpanded = false;
                    } else if (userConfig.playerRememberLastPane && islandContainer.rememberedPlayerPage > 0 && item && item.showPage) {
                        item.showPage(islandContainer.rememberedPlayerPage);
                    }
                    root.focusExpandedPlayer();
                }

                sourceComponent: Component {
                    ExpandedPlayerLayer {
                        initialPage: (userConfig.playerRememberLastPane && !islandContainer.openTimerPageWhenExpanded)
                            ? islandContainer.rememberedPlayerPage : 0
                        onPageChanged: function(page) {
                            islandContainer.rememberedPlayerPage = page;
                        }
                        hoveredSlotIndex: islandContainer.hoveredSlotIndex
                        isDraggingWidget: islandContainer.isDraggingWidgetFromLibrary && islandContainer.draggedWidgetData !== null && islandContainer.draggedWidgetData.sizeType === "full"
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        lyricsText: islandContainer.lyricsDisplayText
                        timePlayed: islandContainer.timePlayed
                        timeTotal: islandContainer.timeTotal
                        trackProgress: islandContainer.trackProgress
                        activePlayer: islandContainer.activePlayer
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        timerSelectedHours: islandContainer.timerSelectedHours
                        timerSelectedMinutes: islandContainer.timerSelectedMinutes
                        timerTotalSeconds: islandContainer.timerTotalSeconds
                        timerRemainingSeconds: islandContainer.timerRemainingSeconds
                        timerRunning: islandContainer.timerRunning
                        timerActive: islandContainer.timerActive
                        showCondition: islandContainer.expandedLayerVisible
                        onControlPressed: islandContainer.suppressCapsuleClick()
                        onBackgroundClicked: islandContainer.smartRestoreState()
                        onCloseRequested: islandContainer.smartRestoreState()
                        onWidgetLibraryRequested: function(mode, pageIndex, slotIndex) {
                            islandContainer.showWidgetLibrary(mode, pageIndex, slotIndex);
                        }
                        onShelfRequested: islandContainer.showFileShelf(true)
                        onKeyboardFocusRequested: islandContainer.requestExpandedPlayerKeyboardFocus()
                        onKeyboardFocusReleased: islandContainer.releaseExpandedPlayerKeyboardFocus()
                        onPreviousRequested: mediaController.previous()
                        onTimerToggleRequested: function(hours, minutes) {
                            islandContainer.toggleTimer(hours, minutes);
                        }
                        onTimerResetRequested: islandContainer.resetTimer()
                        onTimerDurationRequested: function(hours, minutes) {
                            if (!islandContainer.timerActive)
                                islandContainer.syncTimerDuration(hours, minutes);
                        }
                    }
                }
            }

            Loader {
                id: bluetoothExpandedLoader
                anchors.fill: parent
                active: islandContainer.bluetoothExpandedLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    BluetoothExpandedLayer {
                        device: islandContainer.bluetoothExpandedDevice
                        volumeLevel: islandContainer.currentVolume
                        iconText: ""
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.bluetoothExpandedLayerVisible
                    }
                }
            }

            Loader {
                id: notificationLoader
                anchors.fill: parent
                active: islandContainer.notificationLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    NotificationLayer {
                        appName: islandContainer.notificationAppName
                        summary: islandContainer.notificationSummary
                        body: islandContainer.notificationBody
                        expanded: islandContainer.notificationExpanded
                        toggleButton: userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)
                        iconText: root.notificationStatusIcon
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: true
                        onExpansionToggleRequested: {
                            islandContainer.suppressCapsuleClick(true);
                            islandContainer.toggleNotificationExpansionIfNeeded();
                        }
                    }
                }
            }

            Loader {
                id: controlCenterLoader
                anchors.fill: parent
                active: islandContainer.controlCenterLayerVisible || root.anyConnectivityDetailMounted
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    ControlCenterLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        sliderIntroDelay: mainCapsule.morphDuration
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        volumeLevel: islandContainer.currentVolume
                        brightnessLevel: islandContainer.currentBrightness
                        currentWorkspace: islandContainer.currentWs
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        nightLightEnabled: root.shellRootController && root.shellRootController.nightLightEnabled !== undefined
                            ? root.shellRootController.nightLightEnabled
                            : false
                        showCondition: islandContainer.controlCenterLayerVisible
                        onFocusModeChanged: function(enabled) {
                            if (root.shellRootController && root.shellRootController.focusEnabled !== undefined)
                                root.shellRootController.focusEnabled = enabled;
                        }
                        onNightLightModeChanged: function(enabled) {
                            if (root.shellRootController && root.shellRootController.nightLightEnabled !== undefined)
                                root.shellRootController.nightLightEnabled = enabled;
                        }
                        onRequestNotification: function(appName, summary, body) {
                            islandContainer.showNotificationCapsule(appName, summary, body);
                        }
                        onConnectivityPanelRequested: function(kind, open) {
                            root.setConnectivityDetailVisible(kind, open);
                        }
                    }
                }
            }

            Loader {
                id: notificationCenterLoader
                anchors.fill: parent
                active: islandContainer.notificationCenterLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    NotificationCenterLayer {
                        notificationModel: islandContainer.notificationHistoryModel
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily

                        onClearAllRequested: {
                            islandContainer.notificationHistoryModel.clear();
                        }
                    }
                }
            }

            Loader {
                id: widgetLibraryLoader
                anchors.fill: parent
                active: islandContainer.islandState === "widget_library" || islandContainer.isDraggingWidgetFromLibrary
                asynchronous: false
                visible: active
                opacity: islandContainer.isDraggingWidgetFromLibrary ? 0.0 : 1.0
                z: 100

                sourceComponent: Component {
                    WidgetLibraryLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        targetMode: islandContainer.widgetLibraryTargetMode
                        targetPageIndex: islandContainer.widgetLibraryTargetPageIndex
                        targetSlotIndex: islandContainer.widgetLibraryTargetSlotIndex
                        showCondition: islandContainer.islandState === "widget_library"
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        currentCpuUsage: islandContainer.currentCpuUsage
                        currentRamUsage: islandContainer.currentRamUsage
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        onCloseRequested: islandContainer.smartRestoreState()
                        onWidgetStaged: function(widgetId, sizeType, slotSpan) {
                            islandContainer.stageWidgetForPlacement(widgetId, sizeType, slotSpan);
                        }
                        onWidgetDragStarted: function(widgetId, sizeType, slotSpan, winX, winY) {
                            islandContainer.handleWidgetDragStarted(widgetId, sizeType, slotSpan, winX, winY);
                        }
                        onWidgetDragMoved: function(winX, winY) {
                            islandContainer.handleWidgetDragMoved(winX, winY);
                        }
                        onWidgetDragEnded: function(winX, winY) {
                            islandContainer.handleWidgetDragEnded(winX, winY);
                        }
                    }
                }
            }

            Loader {
                id: wallpaperPickerLoader
                anchors.fill: parent
                active: islandContainer.wallpaperPickerLayerVisible
                asynchronous: false
                visible: islandContainer.wallpaperPickerLayerVisible
                onLoaded: root.focusWallpaperPicker()

                sourceComponent: Component {
                    WallpaperPickerLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        activeWallpaper: root.wallpaperPickerActiveWallpaper
                        showCondition: islandContainer.wallpaperPickerLayerVisible
                        onWallpaperApplied: filePath => root.wallpaperPickerActiveWallpaper = filePath
                        onWallpaperApplySucceeded: filePath => root.handleWallpaperApplySucceeded(filePath)
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: applicationLauncherLoader
                anchors.fill: parent
                active: islandContainer.applicationLauncherLayerVisible
                asynchronous: false
                visible: islandContainer.applicationLauncherLayerVisible
                onLoaded: root.focusApplicationLauncher()

                sourceComponent: Component {
                    ApplicationLauncherLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.applicationLauncherLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: fileShelfLoader
                anchors.fill: parent
                active: islandContainer.fileShelfLayerVisible
                asynchronous: false
                visible: islandContainer.fileShelfLayerVisible
                onLoaded: {
                    if (islandContainer.fileShelfOpenedManually)
                        root.focusFileShelf();
                }

                sourceComponent: Component {
                    FileShelfLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.fileShelfLayerVisible
                        dropPreviewOnly: !islandContainer.fileShelfOpenedManually
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        cameraMirrorActive: expandedPlayerLoader.item ? expandedPlayerLoader.item.cameraMirrorActive : false
                        isEditMode: expandedPlayerLoader.item ? expandedPlayerLoader.item.isEditMode : false
                        currentPage: expandedPlayerLoader.item ? expandedPlayerLoader.item.currentPage : 0
                        onCloseRequested: islandContainer.smartRestoreState()
                        onShelfRequested: {
                            islandContainer.showExpandedPlayer();
                            if (expandedPlayerLoader.item && expandedPlayerLoader.item.showPage) {
                                expandedPlayerLoader.item.showPage(islandContainer.preFileShelfPage);
                            }
                        }
                        onPageSelected: (idx) => {
                            if (expandedPlayerLoader.item) {
                                expandedPlayerLoader.item.showPage(idx);
                            }
                            islandContainer.showExpandedPlayer();
                        }
                        onCameraToggleRequested: {
                            if (expandedPlayerLoader.item) {
                                expandedPlayerLoader.item.cameraMirrorActive = !expandedPlayerLoader.item.cameraMirrorActive;
                            }
                        }
                        onEditModeToggleRequested: {
                            if (expandedPlayerLoader.item) {
                                expandedPlayerLoader.item.isEditMode = !expandedPlayerLoader.item.isEditMode;
                            }
                        }
                    }
                }
            }

            DropArea {
                id: islandFileDropArea
                z: 10000
                anchors.fill: parent
                anchors.bottomMargin: !islandContainer.fileShelfLayerVisible ? -32 : 0
                anchors.leftMargin: !islandContainer.fileShelfLayerVisible ? -32 : 0
                anchors.rightMargin: !islandContainer.fileShelfLayerVisible ? -32 : 0
                enabled: islandContainer.fileShelfLayerVisible
                    || islandContainer.fileShelfCanAutoOpen

                onEntered: drag => {
                    if (!root.dragCarriesFiles(drag)) {
                        drag.accepted = false;
                        return;
                    }

                    drag.accept(Qt.CopyAction);
                    if (!islandContainer.fileShelfLayerVisible)
                        islandContainer.showFileShelf(false);
                    root.showAutoHiddenIsland("state");
                }

                onExited: islandContainer.closeAutoOpenedFileShelf()

                onDropped: drop => {
                    if (!root.dragCarriesFiles(drop)) {
                        drop.accepted = false;
                        return;
                    }

                    root.addFilesFromDrop(drop);
                    drop.accept(Qt.CopyAction);
                    islandContainer.closeAutoOpenedFileShelf();
                }
            }

            Rectangle {
                z: 9999
                anchors.fill: parent
                radius: mainCapsule.radius
                color: StyleTokens.clearBlack
                border.width: islandFileDropArea.containsDrag ? 2 : 0
                border.color: StyleTokens.accent
                visible: islandFileDropArea.containsDrag
            }

            Loader {
                id: overviewLoader

                anchors.fill: parent
                active: root.overviewLoaderActive
                asynchronous: false
                visible: root.overviewContentVisible

                onStatusChanged: {
                    if (status === Loader.Ready && root.overviewPreparing) {
                        root.beginOverviewOpening();
                        root.focusOverview();
                    }
                }

                sourceComponent: Component {
                    WorkspaceOverviewScene {
                        screen: root.screen
                        showCondition: root.overviewVisible
                        previewsEnabled: root.overviewContentVisible
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        wallpaperPath: root.overviewWallpaperSource
                        windowCornerRadius: root.overviewWindowCornerRadius
                        onCloseRequested: root.closeOverviewEverywhere()
                    }
                }
            }

        }

        Item {
            id: fileShelfBubble

            readonly property int bubbleSize: 36

            width: bubbleSize
            height: bubbleSize
            x: mainCapsule.x - width - 8
            y: mainCapsule.y + mainCapsule.height / 2 - height / 2
            z: 6
            visible: islandContainer.fileShelfBubbleWanted
            opacity: root.autoHideProgress
            scale: 0.96 + root.autoHideProgress * 0.04
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: StyleTokens.durationFast }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: StyleTokens.black
                border.width: 1
                border.color: StyleTokens.inputBorder

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    text: "\uf08d"
                    color: StyleTokens.textPrimary
                    font.family: root.iconFontFamily
                    font.pixelSize: 13
                    rotation: -18
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -2
                    anchors.bottomMargin: -2
                    width: Math.max(17, countText.implicitWidth + 8)
                    height: 17
                    radius: height / 2
                    color: StyleTokens.accent
                    border.width: 2
                    border.color: StyleTokens.black

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: FileShelf.count > 99 ? "99+" : String(FileShelf.count)
                        color: StyleTokens.white
                        font.family: root.textFontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: fileShelfBubble.visible && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    islandContainer.showFileShelf(true);
                    root.showAutoHiddenIsland("state");
                }
            }
        }

        Item {
            id: timerBubble

            property bool mounted: islandContainer.timerBubbleWanted
            property real reveal: islandContainer.timerBubbleWanted ? 1 : 0
            readonly property int bubbleSize: 34
            readonly property real hiddenX: mainCapsule.x + mainCapsule.width - width * 0.62
            readonly property real shownX: mainCapsule.x + mainCapsule.width + 8
            readonly property real centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2

            width: bubbleSize
            height: bubbleSize
            x: hiddenX + (shownX - hiddenX) * reveal
            y: centerY + (1 - reveal) * 10
            z: 6
            visible: mounted
            opacity: reveal * root.autoHideProgress
            scale: (0.55 + reveal * 0.45) * (0.96 + root.autoHideProgress * 0.04) * (1 + islandContainer.timerCompletionPulse * 0.12)
            transformOrigin: Item.Center

            Connections {
                target: islandContainer

                function onTimerBubbleWantedChanged() {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();

                    if (islandContainer.timerBubbleWanted) {
                        timerBubble.mounted = true;
                        timerBubbleShowAnimation.restart();
                    } else {
                        timerBubbleHideAnimation.restart();
                    }
                }

                function onTimerProgressChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerRemainingSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerTotalSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionAnimatingChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionFlashChanged() {
                    timerBubbleRing.requestPaint();
                }
            }

            NumberAnimation {
                id: timerBubbleShowAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 1
                duration: 360
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: timerBubbleHideAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 0
                duration: 280
                easing.type: Easing.InCubic
                onStopped: {
                    if (!islandContainer.timerBubbleWanted && timerBubble.reveal <= 0.001)
                        timerBubble.mounted = false;
                }
            }

            SequentialAnimation {
                id: timerBubbleCompletionAnimation

                running: islandContainer.timerCompletionAnimating

                onStarted: {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();
                    timerBubble.mounted = true;
                    timerBubble.reveal = 1;
                }

                onStopped: {
                    if (islandContainer.timerCompletionAnimating)
                        islandContainer.timerCompletionAnimating = false;
                    islandContainer.timerCompletionPulse = 0;
                    islandContainer.timerCompletionFlash = 0;
                    timerBubbleRing.requestPaint();
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 1
                        to: 0
                        duration: 380
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 1
                        to: 0
                        duration: 380
                        easing.type: Easing.InOutQuad
                    }
                }

                PauseAnimation {
                    duration: 380
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: StyleTokens.black
            }

            Canvas {
                id: timerBubbleRing

                anchors.fill: parent
                anchors.margins: 1

                Component.onCompleted: requestPaint()
                onVisibleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const completionActive = islandContainer.timerCompletionAnimating;
                    const flash = Math.max(0, Math.min(1, islandContainer.timerCompletionFlash));
                    const lineWidth = completionActive ? 3 + flash : 3;
                    const radius = Math.min(width, height) / 2 - lineWidth / 2;
                    const progress = Math.max(0, Math.min(1, islandContainer.timerProgress));
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle - Math.PI * 2 * progress;

                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineWidth = lineWidth;

                    ctx.beginPath();
                    ctx.strokeStyle = "#303036";
                    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (completionActive) {
                        if (flash > 0) {
                            ctx.beginPath();
                            ctx.lineWidth = lineWidth + 1.5;
                            ctx.strokeStyle = "rgba(255, 204, 0, " + (0.18 * flash) + ")";
                            ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                            ctx.stroke();
                        }

                        ctx.beginPath();
                        ctx.lineWidth = lineWidth;
                        ctx.strokeStyle = "rgba(255, 204, 0, " + (0.72 + 0.28 * flash) + ")";
                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                        ctx.stroke();
                    } else if (progress > 0) {
                        ctx.beginPath();
                        ctx.strokeStyle = "#ffcc00";
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle, true);
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                text: "󰔛"
                color: "white"
                font.pixelSize: root.iconFontSize - 1
                font.family: root.iconFontFamily
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                enabled: timerBubble.mounted && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = true;
                        root.showAutoHiddenIsland();
                    }
                }
                onExited: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = false;
                        root.scheduleAutoHide();
                    }
                }
                onClicked: islandContainer.showExpandedTimerPage()
            }
        }

        ConnectivityDetailShell {
            id: wifiConnectivityDetailShell

            open: root.wifiConnectivityDetailOpen
            mounted: root.wifiConnectivityDetailMounted
            rightSide: false
            panelKind: "wifi"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: bluetoothConnectivityDetailShell

            open: root.bluetoothConnectivityDetailOpen
            mounted: root.bluetoothConnectivityDetailMounted
            rightSide: true
            panelKind: "bluetooth"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: powerConnectivityDetailShell

            open: root.powerConnectivityDetailOpen
            mounted: root.powerConnectivityDetailMounted
            rightSide: true
            panelKind: "power"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: 260
            detailHeight: 88
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        // Drag proxy / ghost following pointer during widget library drag
        Item {
            id: dragGhostBadge
            z: 99999
            visible: islandContainer.isDraggingWidgetFromLibrary && islandContainer.draggedWidgetData !== null
            x: Math.round(islandContainer.dragPointerPos.x - width / 2)
            y: Math.round(islandContainer.dragPointerPos.y - height - 14)
            width: ghostRow.implicitWidth + 24
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 17
                color: "#161618"
                border.width: 1
                border.color: "#26ffffff"
                opacity: 0.96

                Row {
                    id: ghostRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!islandContainer.draggedWidgetData) return "";
                            const w = WidgetRegistry.getWidget(islandContainer.draggedWidgetData.widgetId);
                            return w ? w.name : islandContainer.draggedWidgetData.widgetId;
                        }
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "white"
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: sizeBadgeText.implicitWidth + 10
                        height: 18
                        radius: 9
                        color: "#1fffffff"
                        border.width: 1
                        border.color: "#26ffffff"

                        Text {
                            id: sizeBadgeText
                            anchors.centerIn: parent
                            text: {
                                if (!islandContainer.draggedWidgetData) return "";
                                const st = islandContainer.draggedWidgetData.sizeType;
                                return st === "full" ? "Full" : (st === "minimum" ? "Min" : "Circle");
                            }
                            font.family: root.textFontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: "white"
                        }
                    }
                }
            }
        }

        // Floating Staging Tray: Holds staged widget beneath the notch while user navigates pages
        Item {
            id: stagingTrayItem
            z: 95
            visible: islandContainer.widgetStagingActive && islandContainer.stagedWidgetId !== ""
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.94
            width: trayContentRow.implicitWidth + 24
            height: trayContentRow.implicitHeight + 16
            x: Math.round(mainCapsule.x + mainCapsule.width / 2 - width / 2)
            y: Math.round(mainCapsule.y + mainCapsule.height + 12)

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(22, height / 2)
                color: "#161618"
                border.width: 1
                border.color: "#1fffffff"
                clip: true

                Row {
                    id: trayContentRow
                    anchors.centerIn: parent
                    spacing: 12

                    // 1. Only the widget example
                    Rectangle {
                        id: widgetPreviewBox
                        anchors.verticalCenter: parent.verticalCenter
                        width: {
                            if (islandContainer.stagedSizeType === "circle") return 48;
                            if (islandContainer.stagedSizeType === "minimum") return 200;
                            return islandContainer.stagedSlotSpan >= 2 ? 260 : 190;
                        }
                        height: {
                            if (islandContainer.stagedSizeType === "circle") return 48;
                            if (islandContainer.stagedSizeType === "minimum") return 36;
                            return 60;
                        }
                        radius: islandContainer.stagedSizeType === "circle" ? 24 : (islandContainer.stagedSizeType === "minimum" ? 18 : 12)
                        color: "#000000"
                        border.width: 1
                        border.color: "#14ffffff"
                        clip: true

                        Loader {
                            anchors.fill: parent
                            anchors.margins: islandContainer.stagedSizeType === "full" ? 3 : 0
                            source: (islandContainer.stagedWidgetId !== "")
                                ? WidgetRegistry.getComponentUrl(islandContainer.stagedWidgetId, islandContainer.stagedSizeType)
                                : ""

                            onLoaded: {
                                if (item) {
                                    item.widgetContext = islandContainer.stagingWidgetContext;
                                    item.slotSpan = islandContainer.stagedSlotSpan;
                                    item.isEditMode = false;
                                }
                            }
                            onStatusChanged: {
                                if (status === Loader.Ready && item) {
                                    item.widgetContext = islandContainer.stagingWidgetContext;
                                    item.slotSpan = islandContainer.stagedSlotSpan;
                                    item.isEditMode = false;
                                }
                            }
                        }
                    }

                    // 2. Up to 3 subtle buttons to add to the 3 possible slots
                    Row {
                        id: slotButtonsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        readonly property int slotCount: {
                            if (islandContainer.stagedSizeType === "circle") return 1;
                            if (!userConfig || !userConfig.widgetLayouts) return 3;
                            const mode = islandContainer.stagedSizeType === "full" ? "expanded" : "minimum";
                            const layout = userConfig.widgetLayouts[mode];
                            if (!layout || !layout.pages || layout.pages.length === 0) return 3;
                            const pageIdx = (mode === "expanded") ? islandContainer.rememberedPlayerPage
                                : (closedWidgetLoader.item ? closedWidgetLoader.item.currentPageIndex : 0);
                            const page = layout.pages[Math.max(0, Math.min(layout.pages.length - 1, pageIdx))];
                            return Math.min(3, Math.max(1, page && page.slots !== undefined ? page.slots : 3));
                        }

                        Repeater {
                            model: slotButtonsRow.slotCount

                            Rectangle {
                                readonly property int slotIndex: index
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(54, slotBtnText.implicitWidth + 16)
                                height: 30
                                radius: 8
                                color: slotBtnMouse.pressed
                                    ? "#38ffffff"
                                    : (slotBtnMouse.containsMouse ? "#24ffffff" : "#14ffffff")
                                border.width: 1
                                border.color: slotBtnMouse.containsMouse ? "#33ffffff" : "#14ffffff"

                                Text {
                                    id: slotBtnText
                                    anchors.centerIn: parent
                                    text: "Slot " + (parent.slotIndex + 1)
                                    font.family: root.textFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: slotBtnMouse.containsMouse ? "#ffffff" : "#c4c4c8"
                                }

                                MouseArea {
                                    id: slotBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let targetPage = 0;
                                        if (islandContainer.stagedSizeType === "full") {
                                            targetPage = islandContainer.rememberedPlayerPage;
                                        } else if (islandContainer.stagedSizeType === "minimum") {
                                            targetPage = closedWidgetLoader.item ? closedWidgetLoader.item.currentPageIndex : 0;
                                        } else if (islandContainer.stagedSizeType === "circle") {
                                            targetPage = circleClosedLoader.item ? circleClosedLoader.item.currentPageIndex : 0;
                                        }
                                        islandContainer.commitStagedWidgetToSlot(targetPage, parent.slotIndex);
                                    }
                                }
                            }
                        }
                    }

                    // 3. Subtle close/cancel button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: cancelStageMouse.pressed
                            ? "#33ffffff"
                            : (cancelStageMouse.containsMouse ? "#1fffffff" : "#0fffffff")
                        border.width: 1
                        border.color: cancelStageMouse.containsMouse ? "#2effffff" : "#0fffffff"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: root.iconFontFamily
                            font.pixelSize: 11
                            color: cancelStageMouse.containsMouse ? "#ffffff" : "#88888e"
                        }

                        MouseArea {
                            id: cancelStageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: islandContainer.cancelWidgetStaging()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: autoHideRevealArea

        x: root.autoHideRevealX
        y: 0
        z: 20
        width: root.autoHideRevealWidth
        height: root.autoHideRevealHeight
        enabled: root.autoHideEnabled
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.autoHidePointerInside = true;
            root.showAutoHiddenIsland("edge");
        }

        onExited: {
            root.autoHidePointerInside = false;
            root.scheduleAutoHide();
        }
    }

    IslandRootGestureArea {
        anchors.fill: parent
        enabled: root.topGestureInputActive
        islandController: islandContainer
        capsule: mainCapsule
    }

    // Floating drag proxy item following mouse when dragging widget from library
    Item {
        id: widgetDragProxy
        visible: islandContainer.isDraggingWidgetFromLibrary && islandContainer.draggedWidgetData !== null
        z: 999999
        width: 140
        height: 38
        x: islandContainer.dragPointerPos.x - width / 2
        y: islandContainer.dragPointerPos.y - height / 2

        Rectangle {
            anchors.fill: parent
            radius: 19
            color: "#161618"
            border.width: 1
            border.color: "#2effffff"
            opacity: 0.96

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: root.iconFontFamily
                    font.pixelSize: 14
                    color: "white"
                    text: {
                        if (!islandContainer.draggedWidgetData) return "";
                        const info = WidgetRegistry.getWidget(islandContainer.draggedWidgetData.widgetId);
                        return info ? info.icon : "󰐕";
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: {
                            if (!islandContainer.draggedWidgetData) return "";
                            const info = WidgetRegistry.getWidget(islandContainer.draggedWidgetData.widgetId);
                            return info ? info.name : islandContainer.draggedWidgetData.widgetId;
                        }
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "white"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        text: {
                            if (!islandContainer.draggedWidgetData) return "";
                            const st = islandContainer.draggedWidgetData.sizeType;
                            return st === "full" ? "Full size" : (st === "minimum" ? "Minimum" : "Circle dial");
                        }
                        font.family: root.textFontFamily
                        font.pixelSize: 9
                        color: "#a1a1aa"
                    }
                }
            }
        }
    }
}
