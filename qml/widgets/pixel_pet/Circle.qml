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

    readonly property real diameter: widgetContext ? widgetContext.circleDiameter : Math.min(width, height)
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

    // Radial Progress Arc representing Pet Happiness
    WidgetProgressRing {
        anchors.fill: parent
        value: root.petService.happiness / 100.0
        fillColor: StyleTokens.accent
        trackColor: StyleTokens.track
        strokeWidth: 3.0
    }

    // Centered Pet Animation & Level Tag
    Column {
        anchors.centerIn: parent
        spacing: 1

        PixelSpriteView {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(26, Math.min(36, Math.floor(root.diameter * 0.52)))
            height: width
            petId: root.petService.activePetId
            accessoryId: root.petService.activeAccessoryId
            stateName: root.petService.currentState
            frameIndex: root.petService.frameIndex
            flipX: root.petService.flipX
            activeParticle: root.petService.activeParticle
            particleProgress: root.petService.particleProgress
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            text: "Lv." + root.petService.level
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}
