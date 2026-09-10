import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 2
    property bool isEditMode: false

    readonly property var userConfig: UserConfig
    readonly property var activePlayer: widgetContext ? widgetContext.activePlayer : null
    readonly property string currentTrack: widgetContext ? widgetContext.currentTrack : ""
    readonly property string currentArtist: widgetContext ? widgetContext.currentArtist : ""
    readonly property string currentArtUrl: widgetContext ? widgetContext.currentArtUrl : ""
    readonly property string lyricsText: widgetContext ? widgetContext.lyricsText : ""
    readonly property real trackProgress: widgetContext ? widgetContext.trackProgress : 0
    readonly property string timePlayed: widgetContext ? widgetContext.timePlayed : "0:00"
    readonly property string timeTotal: widgetContext ? widgetContext.timeTotal : "0:00"
    readonly property bool isPlaying: widgetContext ? widgetContext.isPlaying : (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing)
    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : userConfig.iconFontFamily
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : userConfig.textFontFamily
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18
    readonly property real uiScale: widgetContext ? widgetContext.uiScale : 1.0

    readonly property bool compactMode: width < 260 || (slotSpan === 1 && width < 340)

    function togglePlayback() {
        if (!activePlayer || !activePlayer.canControl) return;
        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }
        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) activePlayer.pause();
            return;
        }
        if (activePlayer.canPlay) activePlayer.play();
    }

    anchors.fill: parent

    Row {
        anchors.fill: parent
        anchors.margins: 2
        spacing: compactMode ? 6 : 10

        // Left: Album Art
        Item {
            id: albumArtWrapper
            width: Math.max(48, Math.min(parent.height - 4, compactMode ? 56 : parent.height - 4))
            height: width
            anchors.verticalCenter: parent.verticalCenter

            MultiEffect {
                anchors.centerIn: parent
                width: parent.width * 1.35
                height: parent.height * 1.35
                source: albumArtImage
                blurEnabled: true
                blur: 0.8
                blurMax: 24
                opacity: userConfig.mediaLightingEffectEnabled && root.isPlaying && currentArtUrl !== "" ? 0.65 : 0.0
                visible: opacity > 0.001

                Behavior on opacity {
                    NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: Math.min(width / 2, Math.max(0, userConfig ? userConfig.notchBottomCornerRadius * 2 : 28))
                color: StyleTokens.track

                Image {
                    id: albumArtImage
                    anchors.fill: parent
                    source: root.currentArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: root.currentArtUrl !== ""
                }

                WidgetIconGlyph {
                    anchors.centerIn: parent
                    glyph: "󰎆"
                    color: StyleTokens.textMuted
                    size: compactMode ? 24 : 36
                    widgetContext: root.widgetContext
                    visible: !root.currentArtUrl || root.currentArtUrl === ""
                }
            }
        }

        // Right: Track info, scrubber, and playback toolbar
        Item {
            id: controlsArea
            width: Math.max(0, parent.width - albumArtWrapper.width - parent.spacing)
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 2

                WidgetTextView {
                    width: parent.width
                    text: root.currentTrack !== "" ? root.currentTrack : "No Media Playing"
                    role: "title"
                    overflowMode: "marquee"
                    marqueeSpeed: 28
                    widgetContext: root.widgetContext
                }

                WidgetTextView {
                    width: parent.width
                    text: root.currentArtist
                    role: "body"
                    overflowMode: "elide"
                    colorOverride: StyleTokens.textSecondary
                    visible: root.currentArtist !== ""
                    widgetContext: root.widgetContext
                }

                WidgetTextView {
                    width: parent.width
                    text: root.lyricsText
                    role: "caption"
                    overflowMode: "elide"
                    colorOverride: StyleTokens.textPrimary
                    opacity: root.isPlaying ? 0.9 : 0.6
                    visible: !compactMode && root.lyricsText !== "" && root.lyricsText !== "No music playing"
                    widgetContext: root.widgetContext
                }
            }

            // Scrubber Bar
            Item {
                id: scrubberArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: playbackToolbar.top
                anchors.bottomMargin: compactMode ? 2 : 4
                height: 16

                WidgetScrubberSlider {
                    anchors.fill: parent
                    baseTrackHeight: 3
                    value: root.trackProgress
                    fillColor: StyleTokens.accent
                    trackColor: StyleTokens.track

                    onSliderMoved: ratio => {
                        if (!root.activePlayer || !root.activePlayer.canSeek) return;
                        let total = Number(root.activePlayer.length) || 0;
                        if (total <= 0 && root.activePlayer.metadata && root.activePlayer.metadata["mpris:length"])
                            total = Number(root.activePlayer.metadata["mpris:length"]);
                        if (total > 0 && root.activePlayer.positionSupported) {
                            root.activePlayer.position = ratio * total;
                        }
                    }
                }
            }

            // Playback controls row
            Row {
                id: playbackToolbar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                height: 24
                spacing: compactMode ? 4 : 8

                WidgetActionButton {
                    variant: "icon"
                    buttonStyle: "ghost"
                    icon: "󰒮"
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (root.activePlayer && root.activePlayer.canGoPrevious)
                            root.activePlayer.previous();
                    }
                }

                WidgetActionButton {
                    variant: "icon"
                    buttonStyle: "primary"
                    icon: root.isPlaying ? "󰏤" : "󰐊"
                    widgetContext: root.widgetContext
                    onClicked: root.togglePlayback()
                }

                WidgetActionButton {
                    variant: "icon"
                    buttonStyle: "ghost"
                    icon: "󰒭"
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (root.activePlayer && root.activePlayer.canGoNext)
                            root.activePlayer.next();
                    }
                }

                WidgetActionButton {
                    variant: "icon"
                    buttonStyle: (activePlayer && activePlayer.shuffle) ? "primary" : "ghost"
                    icon: "󰒝"
                    visible: !compactMode
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (activePlayer && activePlayer.shuffle !== undefined)
                            activePlayer.shuffle = !activePlayer.shuffle;
                    }
                }

                WidgetActionButton {
                    variant: "icon"
                    buttonStyle: (activePlayer && String(activePlayer.loopStatus).toLowerCase() !== "none") ? "primary" : "ghost"
                    icon: (activePlayer && String(activePlayer.loopStatus).toLowerCase().indexOf("track") !== -1) ? "󰑘" : "󰑖"
                    visible: !compactMode
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (activePlayer && activePlayer.loopStatus !== undefined) {
                            const s = String(activePlayer.loopStatus).toLowerCase();
                            if (s === "none") activePlayer.loopStatus = "Playlist";
                            else if (s === "playlist") activePlayer.loopStatus = "Track";
                            else activePlayer.loopStatus = "None";
                        }
                    }
                }
            }
        }
    }
}
