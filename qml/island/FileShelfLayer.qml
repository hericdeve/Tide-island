pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import IslandBackend
import "../widgets/components"

FocusScope {
    id: root

    signal closeRequested
    signal shelfRequested
    signal pageSelected(int pageIndex)
    signal addPageRequested()
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal cameraToggleRequested()
    signal editModeToggleRequested()

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property bool showStatusBar: true
    property bool dropPreviewOnly: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property int selectedIndex: FileShelf.count > 0 ? 0 : -1
    property int currentPage: 0
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property int batteryCapacity: -1
    property bool isCharging: false

    property bool reorderActive: false
    property bool reorderCommitting: false
    property int reorderSourceIndex: -1
    property int reorderTargetIndex: -1
    property real reorderStartContentX: 0
    property real reorderTranslationX: 0
    property real reorderPointerX: 0
    property string suppressedOpenUri: ""
    property string externalDropZone: ""

    ListModel {
        id: sendQueueModel
    }

    readonly property int visibleCapacity: 5
    readonly property real horizontalPadding: 18
    readonly property real cardWidth: shelfContentArea.height < 200 ? Math.max(80, Math.round(shelfContentArea.height - 16)) : 176
    readonly property real cardHeight: cardWidth
    readonly property real overflowCellWidth: cardWidth + 20
    readonly property bool isCurrentPage: !showStatusBar ? (currentPage === 0) : true

    focus: showCondition && !dropPreviewOnly && isCurrentPage
    activeFocusOnTab: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? StyleTokens.durationStandard : StyleTokens.durationFast
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (!showCondition)
            return;

        FileShelf.refresh();
        normalizeSelection();
        if (!dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
        if (!dropPreviewOnly)
            LocalSend.discover();
    }

    onCurrentPageChanged: {
        if (showCondition && !dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
    }

    onDropPreviewOnlyChanged: {
        if (showCondition && !dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
    }

    Connections {
        target: FileShelf

        function onCountChanged() {
            root.normalizeSelection();
        }
    }

    Connections {
        target: LocalSend

        function onStatusChanged() {
            if (LocalSend.status === "Sent") {
                sendQueueModel.clear();
            }
        }
    }

    function normalizeSelection() {
        if (FileShelf.count <= 0) {
            selectedIndex = -1;
            return;
        }
        selectedIndex = Math.max(0, Math.min(FileShelf.count - 1, selectedIndex));
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
    }

    function openCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;

        const entry = FileShelf.get(selectedIndex);
        if (entry && entry.filePath)
            Quickshell.execDetached(["xdg-open", String(entry.filePath)]);
    }

    function removeCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;
        removeAt(selectedIndex);
    }

    function removeAt(index) {
        if (index < 0 || index >= FileShelf.count || reorderActive)
            return;

        FileShelf.removeAt(index);
        selectedIndex = Math.min(index, FileShelf.count - 1);
        grabKeyboardFocus();
    }

    function moveSelection(offset) {
        if (FileShelf.count <= 0)
            return;
        selectedIndex = (selectedIndex + offset + FileShelf.count) % FileShelf.count;
        ensureSelectedVisible();
    }

    function ensureSelectedVisible() {
        if (selectedIndex < 0 || FileShelf.count <= visibleCapacity)
            return;
        const center = slotCenter(selectedIndex);
        trayViewport.contentX = Math.max(0, Math.min(
            trayViewport.contentWidth - trayViewport.width,
            center - trayViewport.width / 2));
    }

    function dragMimeData(fileUrl, filePath, snippetText) {
        const url = String(fileUrl);
        const textPayload = (snippetText !== undefined && snippetText !== null && String(snippetText).length > 0)
            ? String(snippetText)
            : String(filePath);
        return {
            "text/uri-list": url + "\r\n",
            "text/plain": textPayload,
            "x-special/gnome-copied-files": "copy\n" + url + "\n"
        };
    }

    function routeExternalDrop(dropEvent, point) {
        if (!dropEvent || !localSendPanel.visible)
            return false;

        const panelPoint = localSendPanel.mapFromItem(root, point.x, point.y);
        if (panelPoint.x < 0 || panelPoint.y < 0
                || panelPoint.x > localSendPanel.width
                || panelPoint.y > localSendPanel.height)
            return false;

        const paths = localPathsFromDrop(dropEvent);
        if (paths.length === 0)
            return true;

        const targetDevice = localSendPanel.deviceAtPoint(panelPoint.x, panelPoint.y);
        const firstPath = paths[0];
        if (targetDevice && firstPath) {
            LocalSend.sendFile(firstPath, targetDevice.deviceNumber);
            return true;
        }

        for (let i = 0; i < paths.length; ++i) {
            const path = paths[i];
            sendQueueModel.append({ filePath: path, fileName: path.split("/").pop() });
        }
        if (sendQueueModel.count > 0)
            LocalSend.discover(sendQueueModel.get(0).filePath);
        return true;
    }

    function localPathsFromDrop(dropEvent) {
        const paths = [];
        if (dropEvent.urls) {
            for (let i = 0; i < dropEvent.urls.length; ++i) {
                const candidate = dropEvent.urls[i];
                const path = candidate && candidate.toLocalFile
                    ? candidate.toLocalFile()
                    : String(candidate || "").startsWith("file://")
                        ? decodeURIComponent(String(candidate).slice(7))
                        : String(candidate || "");
                if (path)
                    paths.push(path);
            }
        }

        if (paths.length > 0)
            return paths;

        const formats = dropEvent.formats || [];
        const uriFormat = formats.indexOf("text/uri-list") >= 0
            ? "text/uri-list"
            : (formats.indexOf("x-special/gnome-copied-files") >= 0
                ? "x-special/gnome-copied-files" : "");
        const payload = uriFormat && dropEvent.getDataAsString
            ? dropEvent.getDataAsString(uriFormat)
            : (dropEvent.text || "");
        const lines = payload.split(/\r?\n/);
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim();
            if (!line || line.startsWith("#") || line === "copy" || line === "cut")
                continue;
            try {
                const path = line.startsWith("file://")
                    ? decodeURIComponent(line.slice(7))
                    : (line.startsWith("/") ? line : "");
                if (path)
                    paths.push(path);
            } catch (error) {
                console.warn("[FileShelfLayer] Could not decode dropped file URI:", line);
            }
        }
        return paths;
    }

    function updateExternalDropPoint(point) {
        if (!point || !showCondition || dropPreviewOnly) {
            externalDropZone = "";
            return;
        }

        const inContent = point.x >= shelfContentArea.x
            && point.x <= shelfContentArea.x + shelfContentArea.width
            && point.y >= shelfContentArea.y
            && point.y <= shelfContentArea.y + shelfContentArea.height;
        const inLocalSend = point.x >= localSendPanel.x
            && point.x <= localSendPanel.x + localSendPanel.width
            && point.y >= localSendPanel.y
            && point.y <= localSendPanel.y + localSendPanel.height;
        externalDropZone = inLocalSend ? "localsend" : (inContent ? "shelf" : "");

        if ((inContent || inLocalSend) && !LocalSend.busy && LocalSend.count === 0) {
            LocalSend.discover();
        }
    }

    function slotStep() {
        if (FileShelf.count <= visibleCapacity)
            return trayViewport.width / Math.max(1, FileShelf.count + 1);
        return overflowCellWidth;
    }

    function slotCenter(index) {
        if (FileShelf.count <= visibleCapacity)
            return trayViewport.width * (index + 1) / Math.max(1, FileShelf.count + 1);
        return overflowCellWidth * index + overflowCellWidth / 2;
    }

    function beginReorder(index) {
        if (index < 0 || index >= FileShelf.count)
            return;
        reorderActive = true;
        reorderSourceIndex = index;
        reorderTargetIndex = index;
        reorderStartContentX = trayViewport.contentX;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        selectedIndex = index;
    }

    function updateReorder(translationX, pointerX) {
        if (!reorderActive)
            return;

        reorderTranslationX = translationX;
        reorderPointerX = pointerX;
        refreshReorderTarget();
    }

    function refreshReorderTarget() {
        if (!reorderActive)
            return;

        const contentDelta = trayViewport.contentX - reorderStartContentX;
        const columnDelta = Math.round((reorderTranslationX + contentDelta) / slotStep());
        reorderTargetIndex = Math.max(0, Math.min(
            FileShelf.count - 1, reorderSourceIndex + columnDelta));
    }

    function reorderShiftForIndex(index) {
        if (!reorderActive || index === reorderSourceIndex)
            return 0;
        if (reorderSourceIndex < reorderTargetIndex
                && index > reorderSourceIndex && index <= reorderTargetIndex)
            return -slotStep();
        if (reorderSourceIndex > reorderTargetIndex
                && index >= reorderTargetIndex && index < reorderSourceIndex)
            return slotStep();
        return 0;
    }

    function reorderVisualOffset() {
        if (!reorderActive)
            return 0;
        return reorderTranslationX + trayViewport.contentX - reorderStartContentX;
    }

    function finishReorder() {
        if (!reorderActive)
            return;

        const sourceIndex = reorderSourceIndex;
        const targetIndex = reorderTargetIndex;
        const positionChanged = sourceIndex !== targetIndex;
        // The displaced delegates are already visually in their final slots.
        // Disable their shift Behavior while the model indices are committed,
        // otherwise the new base position and old animated offset are applied
        // together for one frame and the delegate flies in from an outer edge.
        reorderCommitting = positionChanged;
        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;

        if (positionChanged)
            FileShelf.move(sourceIndex, targetIndex);
        selectedIndex = targetIndex;
        ensureSelectedVisible();
        if (positionChanged)
            reorderCommitReset.restart();
        suppressOpenReset.restart();
    }

    function cancelReorder() {
        if (!reorderActive)
            return;

        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        suppressOpenReset.restart();
    }

    Timer {
        id: reorderCommitReset
        interval: 0
        repeat: false
        onTriggered: root.reorderCommitting = false
    }

    Timer {
        id: suppressOpenReset
        interval: 0
        repeat: false
        onTriggered: root.suppressedOpenUri = ""
    }

    Timer {
        interval: 16
        repeat: true
        running: root.reorderActive && FileShelf.count > root.visibleCapacity

        onTriggered: {
            const edgeSize = 54;
            const maximumContentX = Math.max(0, trayViewport.contentWidth - trayViewport.width);
            let nextContentX = trayViewport.contentX;
            if (root.reorderPointerX < edgeSize)
                nextContentX = Math.max(0, nextContentX - 10);
            else if (root.reorderPointerX > trayViewport.width - edgeSize)
                nextContentX = Math.min(maximumContentX, nextContentX + 10);

            if (nextContentX !== trayViewport.contentX) {
                trayViewport.contentX = nextContentX;
                root.refreshReorderTarget();
            }
        }
    }

    Keys.onPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            const pasted = FileShelf.pasteFromClipboard();
            if (pasted > 0) {
                root.selectedIndex = FileShelf.count - 1;
                root.ensureSelectedVisible();
            }
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
        case Qt.Key_Tab:
            root.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
        case Qt.Key_Backtab:
            root.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.removeCurrent();
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.openCurrent();
            event.accepted = true;
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.closeRequested()
    }

    // Persistent Top Status Bar
    NotchStatusBar {
        id: statusBar
        z: 10
        visible: root.showStatusBar
        height: root.showStatusBar ? 24 : 0
        anchors.top: parent.top
        anchors.topMargin: root.showStatusBar ? 10 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        pages: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.expanded) ? userConfig.widgetLayouts.expanded.pages : []
        currentPage: root.currentPage
        isEditMode: root.isEditMode
        cameraMirrorActive: root.cameraMirrorActive
        batteryCapacity: root.batteryCapacity
        isCharging: root.isCharging
        iconFontFamily: root.iconFontFamily
        textFontFamily: root.textFontFamily

        onPageSelected: (idx) => root.pageSelected(idx)
        onAddPageRequested: {
            if (userConfig)
                userConfig.addPage("expanded", "", 3);
            root.addPageRequested();
        }
        onSetSlotsRequested: (pIdx, sCount) => {
            if (userConfig)
                userConfig.setPageSlots("expanded", pIdx, sCount);
            root.setSlotsRequested(pIdx, sCount);
        }
        onShelfRequested: root.shelfRequested()
        onCameraToggleRequested: root.cameraToggleRequested()
        onEditModeToggleRequested: root.editModeToggleRequested()
        onSettingsRequested: SystemServices.openConfigApp()
        onCloseRequested: root.closeRequested()
    }

    Item {
        id: shelfContentArea
        anchors.top: root.showStatusBar ? statusBar.bottom : parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: localSendPanel.left
        anchors.topMargin: root.showStatusBar ? 6 : 0
        anchors.rightMargin: 12
        anchors.bottomMargin: 8

        Column {
            z: 2
            anchors.centerIn: parent
            spacing: 8
            visible: root.dropPreviewOnly || FileShelf.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\udb80\ude4b"
                color: StyleTokens.textTertiary
                font.family: root.iconFontFamily
                font.pixelSize: 28
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.dropPreviewOnly
                text: "Drag files or folders onto Tide Island"
                color: StyleTokens.textSecondary
                font.family: root.textFontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.dropPreviewOnly
                text: "Drag a file to reorder it or drop it into another application"
                color: StyleTokens.textTertiary
                font.family: root.textFontFamily
                font.pixelSize: 10
            }
        }

        Flickable {
            id: trayViewport
            z: 2
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            visible: !root.dropPreviewOnly && FileShelf.count > 0
            clip: true
            contentWidth: FileShelf.count <= root.visibleCapacity
                ? width : FileShelf.count * root.overflowCellWidth
            contentHeight: height
            interactive: !root.reorderActive && FileShelf.count > root.visibleCapacity
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800

        Repeater {
            model: FileShelf

            delegate: Item {
                id: fileDelegate

                required property int index
                required property string uri
                required property string filePath
                required property string fileName
                required property string displayName
                required property string iconName
                required property string fallbackIconName
                required property string iconSource
                required property bool directory

                readonly property bool selected: index === root.selectedIndex
                readonly property bool reorderSource: root.reorderActive
                    && index === root.reorderSourceIndex

                x: root.slotCenter(index) - width / 2
                y: Math.max(0, (trayViewport.height - height) / 2)
                width: root.cardWidth
                height: root.cardHeight
                z: reorderSource ? 12 : selected ? 4 : 2

                Item {
                    id: fileItem

                    anchors.centerIn: parent
                    width: parent.width
                    height: 166
                    scale: fileDrag.active ? 1.07
                        : fileArea.pressed ? 0.95
                        : (fileDelegate.selected || fileArea.containsMouse ? 1.035 : 1)

                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.hotSpot: Qt.point(width / 2, height / 2)
                    Drag.imageSource: systemIcon.source
                    Drag.mimeData: root.dragMimeData(fileDelegate.uri, fileDelegate.filePath, fileDelegate.isSnippet ? fileDelegate.snippetText : "")

                    transform: [
                        Translate {
                            x: fileDelegate.reorderSource ? root.reorderVisualOffset() : 0
                        },
                        Translate {
                            x: root.reorderShiftForIndex(fileDelegate.index)

                            Behavior on x {
                                enabled: !root.reorderCommitting
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    ]

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: iconBox
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 122
                        height: 122

                        Image {
                            id: systemIcon
                            anchors.centerIn: parent
                            width: 108
                            height: 108
                            sourceSize.width: 256
                            sourceSize.height: 256
                            source: fileDelegate.iconSource !== ""
                                ? fileDelegate.iconSource
                                : Quickshell.iconPath(fileDelegate.fallbackIconName, true)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        Text {
                            anchors.centerIn: parent
                            z: 2
                            visible: systemIcon.status === Image.Error || systemIcon.source.toString() === ""
                            text: fileDelegate.directory ? "\uf07b" : "\uf15b"
                            color: StyleTokens.textSecondary
                            font.family: root.iconFontFamily
                            font.pixelSize: 68
                        }
                    }

                    Text {
                        anchors.top: iconBox.bottom
                        anchors.topMargin: 7
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        text: fileDelegate.displayName
                        color: fileDelegate.selected ? StyleTokens.textPrimary : StyleTokens.textDim
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: fileDelegate.selected ? Font.Medium : Font.Normal
                    }
                }

                MouseArea {
                    id: fileArea
                    z: 1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: fileDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onClicked: root.selectedIndex = fileDelegate.index
                    onDoubleClicked: {
                        if (root.suppressedOpenUri !== fileDelegate.uri)
                            Quickshell.execDetached(["xdg-open", fileDelegate.filePath]);
                    }
                }

                Rectangle {
                    id: deleteButton

                    z: 20
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 16
                    width: 26
                    height: 26
                    radius: width / 2
                    color: "white"
                    opacity: (fileArea.containsMouse || deleteArea.containsMouse)
                        && !fileDrag.active && !root.reorderActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        rotation: 45

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 2
                            radius: 1
                            color: "#242424"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: parent.height
                            radius: 1
                            color: "#242424"
                        }
                    }

                    MouseArea {
                        id: deleteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            mouse.accepted = true;
                            root.removeAt(fileDelegate.index);
                        }
                    }
                }

                DragHandler {
                    id: fileDrag

                    property bool exporting: false

                    target: null
                    acceptedButtons: Qt.LeftButton
                    xAxis.enabled: true
                    yAxis.enabled: true

                    function updateGesture() {
                        if (!active || exporting)
                            return;

                        const point = fileDelegate.mapToItem(
                            trayViewport, centroid.position.x, centroid.position.y);
                        const verticalExport = Math.abs(activeTranslation.y) >= 22
                            && Math.abs(activeTranslation.y) > Math.abs(activeTranslation.x);
                        const leftShelf = point.x < -12 || point.x > trayViewport.width + 12
                            || point.y < -12 || point.y > trayViewport.height + 12;
                        if (verticalExport || leftShelf) {
                            exporting = true;
                            root.cancelReorder();
                            // Start the native drag only after the gesture has
                            // been classified as an export. Starting it on
                            // press would steal horizontal motion from sorting.
                            fileItem.Drag.active = true;
                            return;
                        }
                        root.updateReorder(activeTranslation.x, point.x);
                    }

                    onActiveChanged: {
                        if (active) {
                            exporting = false;
                            root.suppressedOpenUri = fileDelegate.uri;
                            root.beginReorder(fileDelegate.index);
                            updateGesture();
                        } else if (fileDelegate.reorderSource) {
                            root.finishReorder();
                        } else {
                            fileItem.Drag.active = false;
                            exporting = false;
                        }
                    }

                    onActiveTranslationChanged: updateGesture()
                    onCentroidChanged: updateGesture()
                }
            }
        }
    }
    }

    Item {
        id: localSendPanel
        visible: !root.dropPreviewOnly
        z: 3
        anchors.top: shelfContentArea.top
        anchors.right: parent.right
        anchors.bottom: shelfContentArea.bottom
        width: Math.max(250, parent.width * 0.42)
        anchors.rightMargin: 14

        function deviceAtPoint(x, y) {
            if (!deviceListView) return null;
            for (let i = 0; i < deviceListView.count; ++i) {
                const deviceItem = deviceListView.itemAtIndex(i);
                if (!deviceItem)
                    continue;
                const topLeft = deviceItem.mapToItem(localSendPanel, 0, 0);
                if (x >= topLeft.x && x <= topLeft.x + deviceItem.width
                        && y >= topLeft.y && y <= topLeft.y + deviceItem.height)
                    return deviceItem;
            }
            return null;
        }

        Rectangle {
            anchors.fill: parent
            radius: StyleTokens.radiusModule
            color: StyleTokens.module
            border.width: 1
            border.color: StyleTokens.track
            opacity: 0.94
        }

        Column {
            z: 2
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "󰀄"
                    color: StyleTokens.accent
                    font.family: root.iconFontFamily
                    font.pixelSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 28 - 28)

                    Text {
                        text: "LocalSend"
                        color: StyleTokens.textPrimary
                        font.family: root.textFontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: LocalSend.waitingForAcceptance
                            ? "Waiting for phone acceptance..."
                            : (LocalSend.error ? LocalSend.error : (LocalSend.status || (sendQueueModel.count > 0 ? "Choose a device" : "Ready")))
                        color: LocalSend.waitingForAcceptance
                            ? StyleTokens.accent
                            : (LocalSend.error ? StyleTokens.danger : StyleTokens.textSecondary)
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Text {
                    text: "󰑐"
                    font.family: root.iconFontFamily
                    font.pixelSize: 14
                    color: refreshMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textSecondary
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sendQueueModel.count > 0)
                                LocalSend.discover(sendQueueModel.get(0).filePath);
                            else
                                LocalSend.discover();
                        }
                    }
                }
            }

            // Acceptance / Verification Notice Banner
            Rectangle {
                id: promptNotice
                width: parent.width
                height: 30
                radius: StyleTokens.radiusPrompt
                color: StyleTokens.accentSoft
                border.width: 1
                border.color: StyleTokens.accent
                visible: LocalSend.waitingForAcceptance

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        text: "󰄜"
                        color: StyleTokens.accent
                        font.family: root.iconFontFamily
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Accept prompt on your phone"
                        color: StyleTokens.textPrimary
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Transfer Progress Bar (shown during upload)
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: StyleTokens.track
                visible: LocalSend.transferProgress >= 0

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: StyleTokens.accent
                    width: Math.max(0, parent.width * Math.min(1.0, LocalSend.transferProgress / 100.0))
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(82, parent.height - (sendQueueModel.count > 0 ? 165 : 120) - (LocalSend.waitingForAcceptance ? 36 : 0))
                radius: StyleTokens.radiusPrompt
                color: StyleTokens.transparent
                border.width: 1
                border.color: sendDropArea.containsDrag ? StyleTokens.accent : StyleTokens.track

                Behavior on border.color {
                    ColorAnimation { duration: StyleTokens.durationFast }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Text {
                        text: "Nearby devices (" + LocalSend.count + ")"
                        color: StyleTokens.textSecondary
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        visible: LocalSend.count === 0
                        text: LocalSend.status === "Offline"
                            ? "No Wi-Fi or LAN interface found"
                            : (LocalSend.status === "Unavailable"
                                ? "LocalSend unavailable"
                                : (LocalSend.busy ? "Searching for devices..." : "No devices found. Tap 󰑐 to scan"))
                        color: StyleTokens.textTertiary
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    ListView {
                        id: deviceListView
                        visible: LocalSend.count > 0
                        width: parent.width
                        height: Math.max(0, parent.height - 22)
                        model: LocalSend.devices
                        clip: true
                        spacing: 4

                        delegate: Rectangle {
                            id: devDelegate
                            required property var modelData

                            readonly property int deviceNumber: modelData.deviceNumber
                            readonly property string deviceName: modelData.deviceName
                            readonly property string deviceAddress: modelData.deviceAddress
                            readonly property string deviceType: modelData.deviceType || "desktop"

                            width: ListView.view.width
                            height: 38
                            radius: StyleTokens.radiusButton
                            color: devDrop.containsDrag ? StyleTokens.accentSoft : (devMouse.containsMouse ? StyleTokens.moduleHover : StyleTokens.buttonFill)
                            border.width: devDrop.containsDrag ? 1 : 0
                            border.color: StyleTokens.accent

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 8

                                Text {
                                    text: devDelegate.deviceType === "phone" ? "󰄜" : (devDelegate.deviceType === "tablet" ? "󰓹" : "󰌢")
                                    color: StyleTokens.accent
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: devDelegate.deviceName
                                        color: StyleTokens.textPrimary
                                        font.family: root.textFontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: devDelegate.width - 70
                                    }

                                    Text {
                                        text: devDelegate.deviceAddress
                                        color: StyleTokens.textTertiary
                                        font.family: root.textFontFamily
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (sendQueueModel.count > 0) {
                                        LocalSend.sendFile(sendQueueModel.get(0).filePath, devDelegate.deviceNumber);
                                    } else {
                                        const idx = root.selectedIndex >= 0 ? root.selectedIndex : 0;
                                        const entry = FileShelf.get(idx);
                                        if (entry && entry.filePath) {
                                            LocalSend.sendFile(entry.filePath, devDelegate.deviceNumber);
                                        } else {
                                            LocalSend.sendFile("", devDelegate.deviceNumber);
                                        }
                                    }
                                }
                            }

                            DropArea {
                                id: devDrop
                                anchors.fill: parent
                                keys: ["text/uri-list", "application/x-tide-file"]
                                onDropped: drop => {
                                    if (drop.hasUrls && drop.urls.length > 0) {
                                        const path = drop.urls[0].toLocalFile();
                                        if (path) {
                                            LocalSend.sendFile(path, devDelegate.deviceNumber);
                                            drop.acceptProposedAction();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: sendQueueModel.count > 0

                    Row {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "Files to send"
                            color: StyleTokens.textSecondary
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            height: 1
                            width: Math.max(0, parent.width - 70 - clearText.implicitWidth)
                        }

                        Text {
                            id: clearText
                            text: "Clear"
                            color: clearQueueMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textTertiary
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                id: clearQueueMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sendQueueModel.clear()
                            }
                        }
                    }

                ListView {
                    width: parent.width
                    height: Math.min(72, sendQueueModel.count * 24)
                    model: sendQueueModel
                    clip: true

                    delegate: Item {
                        required property string filePath
                        required property string fileName
                        width: ListView.view.width
                        height: 24

                        Drag.active: queueDrag.active
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.proposedAction: Qt.CopyAction
                        Drag.mimeData: ({
                            "text/uri-list": "file://" + filePath
                        })

                        Row {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: "󰈔"
                                color: StyleTokens.textSecondary
                                font.family: root.iconFontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                text: fileName
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                                width: parent.width - 24
                            }
                        }

                        DragHandler {
                            id: queueDrag
                            target: null
                            acceptedButtons: Qt.LeftButton
                        }
                    }
                }
            }
        }

        DropArea {
            id: sendDropArea
            anchors.fill: parent
            keys: ["text/uri-list", "application/x-tide-file"]
            z: 100

            onDropped: drop => {
                if (!drop.hasUrls || drop.urls.length === 0)
                    return;

                const targetDevice = localSendPanel.deviceAtPoint(drop.x, drop.y);
                if (targetDevice) {
                    LocalSend.sendFile(drop.urls[0].toLocalFile(), targetDevice.deviceNumber);
                } else {
                    for (let i = 0; i < drop.urls.length; ++i) {
                        const path = drop.urls[i].toLocalFile();
                        if (path)
                            sendQueueModel.append({ filePath: path, fileName: path.split("/").pop() });
                    }
                    if (sendQueueModel.count > 0)
                        LocalSend.discover(sendQueueModel.get(0).filePath);
                }
                drop.acceptProposedAction();
            }
        }
    }

    Rectangle {
        z: 20
        x: shelfContentArea.x + 1
        y: shelfContentArea.y + 1
        width: Math.max(0, shelfContentArea.width - 2)
        height: Math.max(0, shelfContentArea.height - 2)
        radius: StyleTokens.radiusModule
        color: StyleTokens.transparent
        border.width: root.externalDropZone === "shelf" ? 3 : 0
        border.color: StyleTokens.accent
        visible: root.externalDropZone === "shelf"
    }

    Rectangle {
        z: 20
        x: localSendPanel.x + 1
        y: localSendPanel.y + 1
        width: Math.max(0, localSendPanel.width - 2)
        height: Math.max(0, localSendPanel.height - 2)
        radius: StyleTokens.radiusModule
        color: StyleTokens.transparent
        border.width: root.externalDropZone === "localsend" ? 3 : 0
        border.color: StyleTokens.accent
        visible: root.externalDropZone === "localsend"
    }
}
