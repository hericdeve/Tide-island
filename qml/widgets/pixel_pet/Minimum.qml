import QtQuick
import IslandBackend
import "."
import "../components"

Item {
    id: root

    // ── Standard Widget Contract ─────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    // ── Dynamic Width Morphing Protocol ──────────────────────────────────────
    readonly property real requestedContentWidth: Math.min(230, Math.max(76, contentRow.implicitWidth + 16))
    readonly property real requestedContentHeight: 0

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

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        PixelSpriteView {
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            petId: root.petService.activePetId
            accessoryId: root.petService.activeAccessoryId
            stateName: root.petService.currentState
            frameIndex: root.petService.frameIndex
            flipX: root.petService.flipX
            activeParticle: root.petService.activeParticle
            particleProgress: root.petService.particleProgress
        }

        WidgetIconGlyph {
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.petService.isSleeping ? "󰒲" : (root.petService.currentState === "jamming" ? "󰎆" : (root.petService.hunger < 30 ? "󰈺" : "󰣐"))
            size: 13
            color: root.petService.isSleeping ? "#a78bfa" : (root.petService.currentState === "jamming" ? "#38bdf8" : StyleTokens.accent)
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            text: root.petService.petName + " (Lv." + root.petService.level + ")"
            colorOverride: StyleTokens.textPrimary
            overflowMode: "elide"
            maximumLineCount: 1
            widgetContext: root.widgetContext
        }
    }
}
