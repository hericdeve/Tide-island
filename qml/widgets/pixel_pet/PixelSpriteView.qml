import QtQuick
import IslandBackend
import "PetCatalog.js" as PetCatalog

Item {
    id: root

    // ── Input Properties ─────────────────────────────────────────────────────
    property string petId: "cat"
    property var petData: PetCatalog.getPet(petId)
    property string stateName: "idle"
    property int frameIndex: 0
    property bool flipX: false
    property string accessoryId: "none"
    property real pixelScale: Math.max(1, Math.floor(Math.min(width, height) / 24.0))

    // Particle effect
    property string activeParticle: "" // "heart", "note", "zzz", "sweat", "sparkle", "crumb"
    property real particleProgress: 0.0 // 0.0 to 1.0 (floats up and fades)

    width: 64
    height: 64

    onPetIdChanged: {
        petData = PetCatalog.getPet(petId);
        canvas.requestPaint();
    }
    onPetDataChanged: canvas.requestPaint()
    onStateNameChanged: canvas.requestPaint()
    onFrameIndexChanged: canvas.requestPaint()
    onFlipXChanged: canvas.requestPaint()
    onAccessoryIdChanged: canvas.requestPaint()
    onParticleProgressChanged: {
        if (activeParticle !== "")
            canvas.requestPaint();
    }
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.imageSmoothingEnabled = false;
            ctx.clearRect(0, 0, width, height);

            var pet = root.petData;
            if (!pet || !pet.frames) return;

            var framesList = pet.frames[root.stateName] || pet.frames["idle"];
            if (!framesList || framesList.length === 0)
                framesList = pet.frames["idle"];
            if (!framesList || framesList.length === 0) return;

            var frame = framesList[root.frameIndex % framesList.length];
            if (!frame || frame.length === 0) return;

            var gridH = frame.length;
            var gridW = (frame[0] && frame[0].length > 0) ? frame[0].length : 24;
            var p = Math.max(1, Math.floor(Math.min(width / gridW, height / gridH)));
            var spriteW = gridW * p;
            var spriteH = gridH * p;
            var ox = Math.floor((width - spriteW) / 2.0);
            var oy = Math.floor((height - spriteH) / 2.0);

            // 1. Draw Pet Sprite (with optional horizontal flip)
            ctx.save();
            if (root.flipX) {
                ctx.translate(width, 0);
                ctx.scale(-1, 1);
            }

            var palette = pet.palette || {};
            for (var y = 0; y < gridH; ++y) {
                var row = frame[y];
                for (var x = 0; x < gridW && x < row.length; ++x) {
                    var ch = row.charAt(x);
                    if (ch === ".") continue;
                    var col = palette[ch];
                    if (!col || col === "transparent") continue;
                    ctx.fillStyle = col;
                    ctx.fillRect(ox + x * p, oy + y * p, p, p);
                }
            }

            // 2. Draw Accessory Layer (if equipped)
            if (root.accessoryId && root.accessoryId !== "none") {
                var acc = PetCatalog.getAccessory(root.accessoryId);
                if (acc && acc.frames && acc.frames.length > 0) {
                    var accFrame = acc.frames[0];
                    var accPalette = acc.palette || {};
                    var accH = accFrame.length;
                    for (var ay = 0; ay < accH; ++ay) {
                        var arow = accFrame[ay];
                        for (var ax = 0; ax < arow.length; ++ax) {
                            var ach = arow.charAt(ax);
                            if (ach === ".") continue;
                            var acol = accPalette[ach];
                            if (!acol || acol === "transparent") continue;
                            ctx.fillStyle = acol;
                            // Offset accessories slightly based on head movement during animations
                            var headBob = (root.stateName === "jamming" && (root.frameIndex % 2 === 1)) ? 1 : 0;
                            ctx.fillRect(ox + ax * p, oy + (ay + headBob) * p, p, p);
                        }
                    }
                }
            }

            ctx.restore();

            // 3. Draw Micro-Particles (Floating over pet)
            if (root.activeParticle && root.particleProgress > 0.0 && root.particleProgress < 1.0) {
                var prog = root.particleProgress;
                var alpha = 1.0 - prog;
                var floatDist = Math.round(prog * 18.0 * (p / 2.0));
                var partP = Math.max(1, Math.round(p * 0.75));

                ctx.save();
                ctx.globalAlpha = Math.max(0, Math.min(1.0, alpha));

                var partX = Math.floor(width / 2.0);
                var partY = Math.max(0, oy - floatDist);

                var particleMap = {
                    "heart": {
                        color: "#f43f5e",
                        shape: [
                            ".X.X.",
                            "XXXXX",
                            "XXXXX",
                            ".XXX.",
                            "..X.."
                        ]
                    },
                    "note": {
                        color: "#38bdf8",
                        shape: [
                            "..XX.",
                            "..XX.",
                            "..X..",
                            ".XX..",
                            ".XX.."
                        ]
                    },
                    "zzz": {
                        color: "#a78bfa",
                        shape: [
                            "XXXX.",
                            "...X.",
                            "..X..",
                            ".X...",
                            "XXXX."
                        ]
                    },
                    "sweat": {
                        color: "#38bdf8",
                        shape: [
                            "..X.",
                            ".XX.",
                            "XXXX",
                            ".XX."
                        ]
                    },
                    "sparkle": {
                        color: "#facc15",
                        shape: [
                            "..X..",
                            ".XXX.",
                            "XXXXX",
                            ".XXX.",
                            "..X.."
                        ]
                    },
                    "crumb": {
                        color: "#d97706",
                        shape: [
                            "XX.",
                            "XX."
                        ]
                    }
                };

                var pInfo = particleMap[root.activeParticle];
                if (pInfo) {
                    ctx.fillStyle = pInfo.color;
                    var s = pInfo.shape;
                    var pW = s[0].length * partP;
                    var startX = partX - Math.floor(pW / 2.0);
                    for (var py = 0; py < s.length; ++py) {
                        for (var px = 0; px < s[py].length; ++px) {
                            if (s[py].charAt(px) === "X") {
                                ctx.fillRect(startX + px * partP, partY + py * partP, partP, partP);
                            }
                        }
                    }
                }

                ctx.restore();
            }
        }
    }
}
