import QtQuick
import Quickshell.Widgets
import IslandBackend

Item {
    id: root

    signal expandRequested()

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
    property bool showBoringFace: true
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    // Smartwatch Face Index:
    // 0: Now Playing (Media Dial with outer progress ring)
    // 1: Watch Face (Digital clock + date)
    // 2: Activity Rings (Concentric Battery, CPU, RAM arcs)
    // 3: Boring Face (Blinking eyes & smile)
    property int currentFaceIndex: (currentTrack !== "") ? 0 : (showBoringFace ? 3 : 1)
    readonly property int faceCount: 4

    readonly property bool hasMusic: currentTrack !== ""
    readonly property real circleDiameter: Math.min(width, height)
    readonly property real circleRadius: circleDiameter / 2
    // Damped scaling so increasing circle diameter increases breathing room rather than inflating content
    readonly property real faceScale: Math.max(0.5, Math.min(1.0, 0.62 + (circleDiameter - 44.0) * 0.008) )

    function nextFace() {
        currentFaceIndex = (currentFaceIndex + 1) % faceCount;
    }

    function prevFace() {
        currentFaceIndex = (currentFaceIndex - 1 + faceCount) % faceCount;
    }

    // Auto-switch to Now Playing dial when music starts playing
    onCurrentTrackChanged: {
        if (currentTrack !== "") {
            currentFaceIndex = 0;
        } else if (currentFaceIndex === 0) {
            currentFaceIndex = showBoringFace ? 3 : 1;
        }
    }

    // Canvas color extractor for album art
    Canvas {
        id: colorExtractor
        width: 1
        height: 1
        visible: false
        property color extractedColor: "#b56cff"

        onPaint: {
            const ctx = getContext("2d");
            try {
                ctx.drawImage(albumArtImage, 0, 0, 1, 1);
                const pixel = ctx.getImageData(0, 0, 1, 1).data;
                if (pixel && pixel.length >= 3) {
                    let r = pixel[0], g = pixel[1], b = pixel[2];
                    const max = Math.max(r, g, b);
                    if (max < 140 && max > 0) {
                        const factor = 170 / max;
                        r = Math.min(255, Math.round(r * factor));
                        g = Math.min(255, Math.round(g * factor));
                        b = Math.min(255, Math.round(b * factor));
                    }
                    extractedColor = Qt.rgba(r / 255, g / 255, b / 255, 1.0);
                }
            } catch (e) {}
        }
    }

    // --- Face 0: Now Playing Dial (Center Art + Outer Circular Progress Ring) ---
    Item {
        id: mediaFace
        anchors.fill: parent
        visible: root.currentFaceIndex === 0
        opacity: visible ? 1 : 0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Outer circular progress ring
        Canvas {
            id: mediaProgressRing
            anchors.fill: parent
            antialiasing: true

            readonly property real progressVal: Math.max(0, Math.min(1, root.trackProgress))
            readonly property color ringColor: colorExtractor.extractedColor

            onProgressValChanged: requestPaint()
            onRingColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const center = width / 2;
                const radius = center - 1.5;
                if (radius <= 0) return;

                // Background track
                ctx.beginPath();
                ctx.arc(center, center, radius, 0, 2 * Math.PI);
                ctx.lineWidth = 2.0;
                ctx.strokeStyle = "#2c2c2e";
                ctx.stroke();

                // Progress arc (clockwise from 12 o'clock)
                if (progressVal > 0.005) {
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle + (2 * Math.PI * progressVal);

                    ctx.beginPath();
                    ctx.arc(center, center, radius, startAngle, endAngle);
                    ctx.lineWidth = 2.2;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = ringColor;
                    ctx.stroke();
                }
            }
        }

        // Center circular album art with comfortable breathing room from progress ring
        ClippingRectangle {
            id: artClip
            anchors.centerIn: parent
            property real artMargin: Math.max(5, Math.round(5 + (root.circleDiameter - 44) * 0.08))
            width: Math.max(16, parent.width - artMargin * 2)
            height: width
            radius: width / 2
            color: "#1c1c1e"
            antialiasing: true

            Image {
                id: albumArtImage
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: source.toString() !== ""
                sourceSize: Qt.size(Math.round(parent.width * 2), Math.round(parent.height * 2))
                smooth: true
                onStatusChanged: {
                    if (status === Image.Ready)
                        colorExtractor.requestPaint();
                }
            }

            // Fallback icon when no art is available
            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: Math.max(11, Math.min(18, Math.round(11 + (root.circleDiameter - 44) * 0.12)))
                visible: !root.currentArtUrl || root.currentArtUrl === ""
            }

            // Paused tint overlay with subtle pause badge
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.45)
                visible: !root.isPlaying && root.hasMusic

                Text {
                    anchors.centerIn: parent
                    text: "󰐊"
                    color: "white"
                    font.family: root.iconFontFamily
                    font.pixelSize: Math.max(9, Math.min(15, Math.round(9 + (root.circleDiameter - 44) * 0.1)))
                }
            }
        }
    }

    // --- Face 1: Digital Clock & Date Watch Face ---
    Item {
        id: clockFace
        anchors.fill: parent
        visible: root.currentFaceIndex === 1
        opacity: visible ? 1 : 0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Subtle outer boundary circle
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: "#2c2c2e"
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentTime
                color: "white"
                font.family: root.textFontFamily
                font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (root.circleDiameter - 44) * 0.08)))
                font.weight: Font.Bold
                font.letterSpacing: -0.2
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentDateLabel !== "" ? root.currentDateLabel : "Today"
                color: "#8e8e93"
                font.family: root.textFontFamily
                font.pixelSize: Math.max(7, Math.min(10, Math.round(7.5 + (root.circleDiameter - 44) * 0.05)))
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    // --- Face 2: Smartwatch Activity Rings (Battery, CPU, RAM) ---
    Item {
        id: activityFace
        anchors.fill: parent
        visible: root.currentFaceIndex === 2
        opacity: visible ? 1 : 0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Canvas {
            id: activityCanvas
            anchors.fill: parent
            antialiasing: true

            readonly property real batPct: Math.max(0, Math.min(1, root.batteryCapacity >= 0 ? root.batteryCapacity / 100.0 : 0.8))
            readonly property real cpuPct: Math.max(0, Math.min(1, root.currentCpuUsage / 100.0))
            readonly property real ramPct: Math.max(0, Math.min(1, root.currentRamUsage / 100.0))

            onBatPctChanged: requestPaint()
            onCpuPctChanged: requestPaint()
            onRamPctChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function drawRing(ctx, center, radius, lineWidth, progress, trackColor, strokeColor) {
                if (radius <= 0) return;

                // Background track
                ctx.beginPath();
                ctx.arc(center, center, radius, 0, 2 * Math.PI);
                ctx.lineWidth = lineWidth;
                ctx.strokeStyle = trackColor;
                ctx.stroke();

                // Active arc
                if (progress > 0.01) {
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle + (2 * Math.PI * progress);
                    ctx.beginPath();
                    ctx.arc(center, center, radius, startAngle, endAngle);
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = strokeColor;
                    ctx.stroke();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const center = width / 2;
                const ringWidth = Math.max(1.6, Math.min(2.4, 1.8 + (width - 44) * 0.015));

                // Outer ring: Battery (Green #30d158)
                const r1 = center - 2.4;
                drawRing(ctx, center, r1, ringWidth, batPct, "#14281a", "#30d158");

                // Middle ring: CPU (Pink/Red #ff2d55)
                const gap = Math.max(2.8, Math.min(4.0, 3.0 + (width - 44) * 0.025));
                const r2 = r1 - gap;
                drawRing(ctx, center, r2, ringWidth, cpuPct, "#2b1016", "#ff2d55");

                // Inner ring: RAM (Cyan/Blue #007aff)
                const r3 = r2 - gap;
                drawRing(ctx, center, r3, ringWidth, ramPct, "#0e1e36", "#007aff");
            }
        }

        // Center: Clean single status (Battery % or charging bolt, no crowded double stack!)
        Item {
            anchors.centerIn: parent
            width: Math.round(root.circleDiameter * 0.44)
            height: width

            Text {
                anchors.centerIn: parent
                visible: root.isCharging
                text: "󰂄"
                color: "#30d158"
                font.family: root.iconFontFamily
                font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (root.circleDiameter - 44) * 0.08)))
            }

            Text {
                anchors.centerIn: parent
                visible: !root.isCharging
                text: root.batteryCapacity >= 0 ? root.batteryCapacity + "%" : "--"
                color: "white"
                font.family: root.textFontFamily
                font.pixelSize: Math.max(7.5, Math.min(11, Math.round(8.5 + (root.circleDiameter - 44) * 0.05)))
                font.weight: Font.Bold
            }
        }
    }

    // --- Face 3: Boring Face (Blinking eyes & smile) ---
    Item {
        id: faceComplication
        anchors.fill: parent
        visible: root.currentFaceIndex === 3
        opacity: visible ? 1 : 0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Subtle outer boundary circle
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: "#2c2c2e"
        }

        BoringFaceAnimation {
            anchors.centerIn: parent
            customScale: root.faceScale
        }
    }

    Timer {
        id: wheelResetTimer
        interval: 320
        repeat: false
        onTriggered: {
            circleWheelHandler.accumulatedX = 0;
            circleWheelHandler.accumulatedY = 0;
            circleWheelHandler.gestureLocked = false;
        }
    }

    // --- Wheel Navigation (Rotary dial complication cycling & gestures) ---
    WheelHandler {
        id: circleWheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulatedX: 0
        property real accumulatedY: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            // Ignore kinetic momentum
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }

            // Fingers lifted from touchpad: keep lockout active for a short quiet period so residual events do not chain
            if (event.phase === Qt.ScrollEnd) {
                wheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            // If a face change already occurred in this swipe stroke, stay locked until stroke completely finishes
            if (circleWheelHandler.gestureLocked) {
                wheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            wheelResetTimer.restart();

            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : (event.angleDelta.x / 5);
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.y / 5);

            circleWheelHandler.accumulatedX += dx;
            circleWheelHandler.accumulatedY += dy;

            // Horizontal swipe: change EXACTLY ONE face per stroke, then lock out until the stroke finishes
            if (Math.abs(circleWheelHandler.accumulatedX) > 16 && Math.abs(circleWheelHandler.accumulatedX) > Math.abs(circleWheelHandler.accumulatedY) * 1.1) {
                circleWheelHandler.gestureLocked = true;
                if (circleWheelHandler.accumulatedX < 0) {
                    root.nextFace();
                } else {
                    root.prevFace();
                }
                circleWheelHandler.accumulatedX = 0;
                circleWheelHandler.accumulatedY = 0;
                event.accepted = true;
                return;
            }

            // Two-finger vertical pull down on touchpad: expand player (once per stroke)
            if (circleWheelHandler.accumulatedY < -24 && Math.abs(circleWheelHandler.accumulatedY) > Math.abs(circleWheelHandler.accumulatedX) * 1.1) {
                circleWheelHandler.gestureLocked = true;
                circleWheelHandler.accumulatedX = 0;
                circleWheelHandler.accumulatedY = 0;
                root.expandRequested();
                event.accepted = true;
                return;
            }

            // Discrete mouse wheel click fallback
            const discreteDelta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (Math.abs(discreteDelta) >= 60) {
                circleWheelHandler.gestureLocked = true;
                if (discreteDelta < 0) {
                    root.nextFace();
                } else if (discreteDelta > 0) {
                    root.prevFace();
                }
                event.accepted = true;
                return;
            }

            event.accepted = true;
        }
    }

    // --- Interactive Swipe & Tap Area ---
    MouseArea {
        id: dialTouchArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        property real startX: 0
        property real startY: 0
        property bool moved: false

        onPressed: (mouse) => {
            startX = mouse.x;
            startY = mouse.y;
            moved = false;
        }

        onPositionChanged: (mouse) => {
            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (Math.abs(dx) > 8 || Math.abs(dy) > 8) {
                moved = true;
            }
        }

        onReleased: (mouse) => {
            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (moved) {
                if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 12) {
                    if (dx < 0) {
                        root.nextFace();
                    } else {
                        root.prevFace();
                    }
                } else if (dy > 14) {
                    root.expandRequested();
                }
            } else {
                root.expandRequested();
            }
            moved = false;
        }
    }
}
