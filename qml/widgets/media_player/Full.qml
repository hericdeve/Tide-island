import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import IslandBackend

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

    function seekOffset(seconds) {
        if (!activePlayer || !activePlayer.canControl) return;
        if (activePlayer.position !== undefined) {
            const nextPos = Math.max(0, activePlayer.position + seconds);
            if (activePlayer.canSeek && typeof activePlayer.seek === "function") {
                activePlayer.seek(seconds * 1000000);
            } else {
                activePlayer.position = nextPos;
            }
        }
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
                color: "#2c2c2e"

                Image {
                    id: albumArtImage
                    anchors.fill: parent
                    source: root.currentArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: root.currentArtUrl !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: "#8e8e93"
                    font.family: root.iconFontFamily
                    font.pixelSize: compactMode ? 24 : 40
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

                Text {
                    text: root.currentTrack !== "" ? root.currentTrack : "No Media Playing"
                    color: StyleTokens.textPrimary
                    font.pixelSize: Math.round((compactMode ? 12 : 13) * root.uiScale)
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: root.currentArtist
                    color: StyleTokens.textSecondary
                    font.pixelSize: Math.round((compactMode ? 10 : 11) * root.uiScale)
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.currentArtist !== ""
                }

                Text {
                    text: root.lyricsText
                    color: StyleTokens.textPrimary
                    opacity: root.isPlaying ? 0.9 : 0.6
                    font.pixelSize: Math.round(10 * root.uiScale)
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: !compactMode && root.lyricsText !== "" && root.lyricsText !== "No music playing"
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

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: StyleTokens.track

                    Rectangle {
                        height: parent.height
                        radius: 1.5
                        color: StyleTokens.accent
                        width: parent.width * Math.max(0, Math.min(1, root.trackProgress))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: (mouse) => seekFromMouse(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) seekFromMouse(mouse.x); }

                    function seekFromMouse(mouseX) {
                        if (!root.activePlayer || !root.activePlayer.canSeek) return;
                        const ratio = Math.max(0, Math.min(1, mouseX / width));
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
                spacing: compactMode ? 6 : 12

                // Previous
                Item {
                    width: 22
                    height: parent.height
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: prevMouse.pressed ? "#888" : "#8e8e93"
                        font.family: root.iconFontFamily
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoPrevious)
                                root.activePlayer.previous();
                        }
                    }
                }

                // Play / Pause
                Item {
                    width: 26
                    height: parent.height
                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        color: playMouse.pressed ? StyleTokens.textSecondary : StyleTokens.textPrimary
                        font.family: root.iconFontFamily
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayback()
                    }
                }

                // Next
                Item {
                    width: 22
                    height: parent.height
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: nextMouse.pressed ? StyleTokens.textDim : StyleTokens.textSecondary
                        font.family: root.iconFontFamily
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoNext)
                                root.activePlayer.next();
                        }
                    }
                }

                // Shuffle (non-compact)
                Item {
                    width: 22
                    height: parent.height
                    visible: !compactMode
                    Text {
                        anchors.centerIn: parent
                        text: "󰒝"
                        color: (activePlayer && activePlayer.shuffle) ? StyleTokens.accent : StyleTokens.textSecondary
                        font.family: root.iconFontFamily
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activePlayer && activePlayer.shuffle !== undefined)
                                activePlayer.shuffle = !activePlayer.shuffle;
                        }
                    }
                }

                // Loop / Repeat (non-compact)
                Item {
                    width: 22
                    height: parent.height
                    visible: !compactMode
                    Text {
                        anchors.centerIn: parent
                        text: (activePlayer && String(activePlayer.loopStatus).toLowerCase().indexOf("track") !== -1) ? "󰑘" : "󰑖"
                        color: (activePlayer && String(activePlayer.loopStatus).toLowerCase() !== "none") ? "#ffffff" : "#8e8e93"
                        font.family: root.iconFontFamily
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
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
}
