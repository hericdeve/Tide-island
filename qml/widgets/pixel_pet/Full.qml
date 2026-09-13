import QtQuick
import IslandBackend
import "."
import "../components"
import "PetCatalog.js" as PetCatalog

Item {
    id: root

    // ── Standard Widget Contract ─────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    // ── Usable Space & Dimensions ─────────────────────────────────────────────
    readonly property var userConfig: UserConfig
    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20

    readonly property bool compactMode: width < 260
    readonly property real buttonSpacing: compactMode ? 4 : 6
    readonly property real buttonSize: Math.max(22, Math.min(28, Math.floor((width - 48) / 5.0)))

    // Drawer state: "none", "pets", "wardrobe", "food"
    property string drawerMode: "none"

    // ── Dynamic Resizing Protocol ─────────────────────────────────────────────
    readonly property real baseSlotHeight: Math.max(136, (userConfig ? userConfig.notchOpenHeight : 190) - 52)
    readonly property real requestedContentHeight: {
        var extra = 0;
        if (drawerMode !== "none") {
            extra += 52;
        }
        if (speechText.measuredHeight > 22) {
            extra += Math.min(40, speechText.measuredHeight - 22);
        }
        return extra > 0 ? (baseSlotHeight + extra) : 0;
    }
    readonly property real requestedContentWidth: 0

    // Reference to pet singleton
    readonly property var petService: PixelPetService

    // Synchronize system reactivity from widget context
    Connections {
        target: root
        function onWidgetContextChanged() {
            if (!root.widgetContext) return;
            if (root.widgetContext.isPlaying !== undefined)
                petService.isMusicPlaying = Boolean(root.widgetContext.isPlaying);
            if (root.widgetContext.currentTrack !== undefined)
                petService.currentTrack = root.widgetContext.currentTrack || "";
            if (root.widgetContext.currentCpuUsage !== undefined)
                petService.currentCpuUsage = root.widgetContext.currentCpuUsage;
            if (root.widgetContext.batteryCapacity !== undefined)
                petService.batteryCapacity = root.widgetContext.batteryCapacity;
            if (root.widgetContext.isCharging !== undefined)
                petService.isCharging = Boolean(root.widgetContext.isCharging);
        }
    }

    anchors.fill: parent
    clip: true

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.margins: 6

        Column {
            anchors.fill: parent
            spacing: 5

            // 1. Header Bar: Name, Level, Mood, and Drawer Toggles
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    WidgetIconGlyph {
                        glyph: root.petService.isSleeping ? "󰒲" : (root.petService.currentState === "jamming" ? "󰎆" : "󰄛")
                        size: 14
                        color: StyleTokens.accent
                        widgetContext: root.widgetContext
                    }

                    WidgetTextView {
                        text: root.petService.petName + " · Lv." + root.petService.level
                        role: "title"
                        colorOverride: StyleTokens.textPrimary
                        widgetContext: root.widgetContext
                    }

                    WidgetTextView {
                        text: "(" + root.petService.petSpecies + ")"
                        role: "caption"
                        colorOverride: StyleTokens.textSecondary
                        visible: !root.compactMode
                        widgetContext: root.widgetContext
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    WidgetActionButton {
                        width: 22
                        height: 22
                        variant: "icon"
                        icon: "󰄛"
                        buttonStyle: root.drawerMode === "pets" ? "primary" : "secondary"
                        widgetContext: root.widgetContext
                        onClicked: root.drawerMode = (root.drawerMode === "pets" ? "none" : "pets")
                    }

                    WidgetActionButton {
                        width: 22
                        height: 22
                        variant: "icon"
                        icon: "󰄚"
                        buttonStyle: root.drawerMode === "wardrobe" ? "primary" : "secondary"
                        widgetContext: root.widgetContext
                        onClicked: root.drawerMode = (root.drawerMode === "wardrobe" ? "none" : "wardrobe")
                    }
                }
            }

            // 2. Interactive Habitat Terrarium & Roaming Stage
            Rectangle {
                id: habitatStage
                width: parent.width
                height: Math.max(56, Math.min(72, parent.height - 76 - (root.drawerMode !== "none" ? 52 : 0)))
                radius: 12
                color: StyleTokens.module
                border.width: 1
                border.color: StyleTokens.track
                clip: true

                // Subtle ground baseline
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 1
                    color: StyleTokens.track
                    opacity: 0.6
                }

                // Interactive click/toss area
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: function(mouse) {
                        var petX = petAvatar.x;
                        var petW = petAvatar.width;
                        // Clicking on or near the pet triggers petting/cuddling!
                        if (mouse.x >= petX - 10 && mouse.x <= petX + petW + 10) {
                            root.petService.pet();
                        } else {
                            // Clicking elsewhere tosses the toy ball
                            root.petService.play();
                        }
                    }
                }

                // Speech / Thought Bubble
                Item {
                    id: bubbleArea
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 16, speechText.measuredWidth + 16)
                    height: Math.max(16, speechText.measuredHeight + 4)

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: StyleTokens.panel
                        border.width: 1
                        border.color: StyleTokens.track
                        opacity: 0.88
                    }

                    WidgetTextView {
                        id: speechText
                        anchors.centerIn: parent
                        width: parent.width - 10
                        text: root.petService.speechBubbleText
                        role: "caption"
                        colorOverride: StyleTokens.textPrimary
                        overflowMode: "wrap"
                        widgetContext: root.widgetContext
                    }
                }

                // The Pixel Pet Avatar
                PixelSpriteView {
                    id: petAvatar
                    width: 48
                    height: 48
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    x: Math.round(root.petService.roamPosition * Math.max(0, habitatStage.width - width - 8)) + 4

                    petId: root.petService.activePetId
                    accessoryId: root.petService.activeAccessoryId
                    stateName: root.petService.currentState
                    frameIndex: root.petService.frameIndex
                    flipX: root.petService.flipX
                    activeParticle: root.petService.activeParticle
                    particleProgress: root.petService.particleProgress

                    Behavior on x {
                        NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                    }
                }
            }

            // 3. Vitals HUD: Hunger, Happiness, Energy Bars
            Row {
                width: parent.width
                height: 14
                spacing: 8

                // Hunger
                Row {
                    width: Math.floor((parent.width - 16) / 3.0)
                    height: parent.height
                    spacing: 4

                    WidgetIconGlyph {
                        glyph: "󰈺"
                        size: 10
                        color: StyleTokens.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }

                    WidgetProgressBar {
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        barHeight: 5
                        value: root.petService.hunger / 100.0
                        fillColor: root.petService.hunger < 30 ? StyleTokens.danger : StyleTokens.accent
                        trackColor: StyleTokens.track
                    }
                }

                // Happiness
                Row {
                    width: Math.floor((parent.width - 16) / 3.0)
                    height: parent.height
                    spacing: 4

                    WidgetIconGlyph {
                        glyph: "󰣐"
                        size: 10
                        color: StyleTokens.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }

                    WidgetProgressBar {
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        barHeight: 5
                        value: root.petService.happiness / 100.0
                        fillColor: "#fb7185"
                        trackColor: StyleTokens.track
                    }
                }

                // Energy
                Row {
                    width: Math.floor((parent.width - 16) / 3.0)
                    height: parent.height
                    spacing: 4

                    WidgetIconGlyph {
                        glyph: "󰄉"
                        size: 10
                        color: StyleTokens.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        widgetContext: root.widgetContext
                    }

                    WidgetProgressBar {
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        barHeight: 5
                        value: root.petService.energy / 100.0
                        fillColor: "#38bdf8"
                        trackColor: StyleTokens.track
                    }
                }
            }

            // 4. Action Dock: Feed, Play, Sleep, Groom, Food Drawer
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.buttonSpacing
                height: root.buttonSize

                WidgetActionButton {
                    width: root.buttonSize
                    height: root.buttonSize
                    variant: "icon"
                    icon: "󰈺"
                    buttonStyle: root.drawerMode === "food" ? "primary" : "secondary"
                    widgetContext: root.widgetContext
                    onClicked: root.drawerMode = (root.drawerMode === "food" ? "none" : "food")
                }

                WidgetActionButton {
                    width: root.buttonSize
                    height: root.buttonSize
                    variant: "icon"
                    icon: "󰣐"
                    buttonStyle: "secondary"
                    widgetContext: root.widgetContext
                    onClicked: root.petService.pet()
                }

                WidgetActionButton {
                    width: root.buttonSize
                    height: root.buttonSize
                    variant: "icon"
                    icon: "󰔛"
                    buttonStyle: "secondary"
                    widgetContext: root.widgetContext
                    onClicked: root.petService.play()
                }

                WidgetActionButton {
                    width: root.buttonSize
                    height: root.buttonSize
                    variant: "icon"
                    icon: root.petService.isSleeping ? "󰒲" : "󰥔"
                    buttonStyle: root.petService.isSleeping ? "primary" : "secondary"
                    widgetContext: root.widgetContext
                    onClicked: root.petService.toggleSleep()
                }

                WidgetActionButton {
                    width: root.buttonSize
                    height: root.buttonSize
                    variant: "icon"
                    icon: "󰒓"
                    buttonStyle: root.drawerMode === "settings" ? "primary" : "secondary"
                    widgetContext: root.widgetContext
                    onClicked: root.drawerMode = (root.drawerMode === "settings" ? "none" : "settings")
                }
            }

            // 5. Expandable Selection Drawers (Pets / Wardrobe / Food)
            Item {
                width: parent.width
                height: root.drawerMode !== "none" ? 46 : 0
                visible: root.drawerMode !== "none"
                clip: true

                // Pet Switcher Carousel
                Flickable {
                    anchors.fill: parent
                    contentWidth: petRow.width
                    contentHeight: parent.height
                    visible: root.drawerMode === "pets"
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: petRow
                        spacing: 6
                        height: parent.height

                        Repeater {
                            model: PetCatalog.getPetList()

                            delegate: Rectangle {
                                width: 44
                                height: 42
                                radius: 8
                                color: (root.petService.activePetId === modelData.id) ? StyleTokens.accent : StyleTokens.module
                                border.width: 1
                                border.color: StyleTokens.track

                                PixelSpriteView {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    petId: modelData.id
                                    stateName: "idle"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.petService.selectPet(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Wardrobe Accessory Selector
                Flickable {
                    anchors.fill: parent
                    contentWidth: accRow.width
                    contentHeight: parent.height
                    visible: root.drawerMode === "wardrobe"
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: accRow
                        spacing: 6
                        height: parent.height

                        Repeater {
                            model: PetCatalog.getAccessoryList()

                            delegate: Rectangle {
                                width: 44
                                height: 42
                                radius: 8
                                color: (root.petService.activeAccessoryId === modelData.id) ? StyleTokens.accent : StyleTokens.module
                                border.width: 1
                                border.color: StyleTokens.track

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    WidgetIconGlyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        glyph: modelData.icon
                                        size: 16
                                        color: (root.petService.activeAccessoryId === modelData.id) ? StyleTokens.textPrimary : StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }

                                    WidgetTextView {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name.split(" ")[0]
                                        role: "caption"
                                        colorOverride: (root.petService.activeAccessoryId === modelData.id) ? StyleTokens.textPrimary : StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.petService.equipAccessory(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Food Treat Picker
                Flickable {
                    anchors.fill: parent
                    contentWidth: foodRow.width
                    contentHeight: parent.height
                    visible: root.drawerMode === "food"
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: foodRow
                        spacing: 6
                        height: parent.height

                        Repeater {
                            model: PetCatalog.getFoodList()

                            delegate: Rectangle {
                                width: 44
                                height: 42
                                radius: 8
                                color: StyleTokens.module
                                border.width: 1
                                border.color: (root.petService.petData && root.petService.petData.favoriteFood === modelData.id) ? StyleTokens.accent : StyleTokens.track

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    WidgetIconGlyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        glyph: modelData.icon
                                        size: 16
                                        color: StyleTokens.accent
                                        widgetContext: root.widgetContext
                                    }

                                    WidgetTextView {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name.split(" ")[0]
                                        role: "caption"
                                        colorOverride: StyleTokens.textPrimary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.petService.feed(modelData.id);
                                        root.drawerMode = "none";
                                    }
                                }
                            }
                        }
                    }
                }

                // Pet Settings & Preferences Drawer
                Flickable {
                    anchors.fill: parent
                    contentWidth: settingsRow.width
                    contentHeight: parent.height
                    visible: root.drawerMode === "settings"
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: settingsRow
                        spacing: 6
                        height: parent.height

                        // 1. Care Mode Pill
                        Rectangle {
                            width: 104
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: root.petService.careMode === "frozen" ? StyleTokens.track : StyleTokens.accent

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰄉"
                                        size: 13
                                        color: StyleTokens.accent
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "Care Pace"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.petService.careMode === "frozen" ? "Frozen" : (root.petService.careMode === "relaxed" ? "Relaxed" : "Normal")
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.petService.cycleCareMode()
                            }
                        }

                        // 2. Music Jamming Toggle
                        Rectangle {
                            width: 96
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: root.petService.reactToMusic ? StyleTokens.accent : StyleTokens.track

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰎆"
                                        size: 13
                                        color: root.petService.reactToMusic ? "#38bdf8" : StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "Music Jam"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.petService.reactToMusic ? "Active" : "Muted"
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.petService.toggleMusicReact()
                            }
                        }

                        // 3. CPU Load React Toggle
                        Rectangle {
                            width: 96
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: root.petService.reactToCpu ? StyleTokens.accent : StyleTokens.track

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰻠"
                                        size: 13
                                        color: root.petService.reactToCpu ? StyleTokens.danger : StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "CPU Sweat"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.petService.reactToCpu ? "Active" : "Off"
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.petService.toggleCpuReact()
                            }
                        }

                        // 4. Groom / Clean Action
                        Rectangle {
                            width: 86
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: StyleTokens.track

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰮔"
                                        size: 13
                                        color: "#38bdf8"
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "Bath"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Clean (100%)"
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.petService.groom();
                                    root.drawerMode = "none";
                                }
                            }
                        }

                        // 5. Open Tide Island App
                        Rectangle {
                            width: 104
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: StyleTokens.track

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰒓"
                                        size: 13
                                        color: StyleTokens.accent
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "Tide Settings"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Launch App"
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemServices.openConfigApp()
                            }
                        }

                        // 6. Reset Pet Stats
                        Rectangle {
                            width: 80
                            height: 42
                            radius: 8
                            color: StyleTokens.module
                            border.width: 1
                            border.color: StyleTokens.track

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    WidgetIconGlyph {
                                        glyph: "󰑣"
                                        size: 13
                                        color: StyleTokens.danger
                                        widgetContext: root.widgetContext
                                    }
                                    WidgetTextView {
                                        text: "Reset"
                                        role: "caption"
                                        colorOverride: StyleTokens.textSecondary
                                        widgetContext: root.widgetContext
                                    }
                                }

                                WidgetTextView {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Defaults"
                                    role: "caption"
                                    colorOverride: StyleTokens.textPrimary
                                    widgetContext: root.widgetContext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.petService.resetStats();
                                    root.drawerMode = "none";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
