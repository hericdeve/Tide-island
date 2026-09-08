---
name: create-widget
description: Scaffold and register a new widget for the Tide Island notch ecosystem
---

# Tide Island — Create Widget Skill

You are creating a new widget for the **Tide Island** Dynamic Island for Linux/Wayland (`/home/rodia/Projects/Tide-island`).

## What a widget is

A widget is a self-contained QML component placed inside a notch slot. It receives a `widgetContext` object with shared system state and must expose three standard QML properties. Each widget lives in `qml/widgets/<widget_id>/` and consists of:

| File | Size variant | Shown in |
|------|-------------|---------|
| `Full.qml` | Full | Expanded notch (pill/notch mode) |
| `Minimum.qml` | Minimum | Closed notch (pill idle state) |
| `Circle.qml` | Circle | Circle-mode smartwatch dial |
| `manifest.json` | — | Metadata; lists which sizes the widget implements |

A widget can implement **any subset** of sizes (e.g. `boring_face` is Circle-only). You **must** implement at least one.

---

## Step-by-step

### 1. Choose a widget ID

Pick a `snake_case` identifier, e.g. `weather`, `world_clock`, `stopwatch`.

### 2. Create the directory

```
qml/widgets/<widget_id>/
```

### 3. Write `manifest.json`

```json
{
  "id": "<widget_id>",
  "name": "Human Readable Name",
  "description": "One sentence: what this widget does.",
  "icon": "󰀀",
  "supportedSizes": ["full", "minimum", "circle"],
  "defaultSlotSpan": 1
}
```

- `supportedSizes`: Include only the sizes you actually implement. Valid values: `"full"`, `"minimum"`, `"circle"`.
- `defaultSlotSpan`: How many slots this widget occupies by default (1–6). Media player uses 2.
- `icon`: A Nerd Font / Material Design glyph (UTF-8 string).

### 4. Write each size QML file

#### Required property interface — ALL three files must declare:

```qml
// All three size files share the same property contract.
property var widgetContext: null   // injected by the slot loader
property int slotSpan: 1           // how many slots this instance spans
property bool isEditMode: false    // true when user is in layout edit mode
```

#### `widgetContext` fields available at runtime

| Field | Type | Description |
|-------|------|-------------|
| `activePlayer` | object\|null | MPRIS player proxy (`playbackState`, `trackTitle`, `artist`, `artUrl`, `position`, `length`) |
| `currentTrack` | string | Track title (empty when nothing plays) |
| `currentArtist` | string | Artist name |
| `currentArtUrl` | string | Album art URL |
| `isPlaying` | bool | True when MPRIS is playing |
| `trackProgress` | real | 0.0–1.0 play position |
| `timePlayed` | string | `"M:SS"` elapsed |
| `timeTotal` | string | `"M:SS"` total duration |
| `batteryCapacity` | int | 0–100 or -1 if unavailable |
| `isCharging` | bool | |
| `currentCpuUsage` | real | 0–100 % |
| `currentRamUsage` | real | 0–100 % |
| `currentTime` | string | `"HH:MM"` live clock |
| `currentDateLabel` | string | Short date string e.g. `"Mon 7"` |
| `iconFontFamily` | string | Nerd Font family name |
| `textFontFamily` | string | Body text font family |
| `heroFontFamily` | string | Hero / heading font family |
| `faceScale` | real | Circle-mode scale factor (0.5–1.0) |
| `circleDiameter` | real | Pixel diameter of the circle widget area |
| `uiScale` | real | Global UI scale (0.85–1.35) |
| `isEditMode` | bool | Mirrors the `isEditMode` property |

> **Safety:** Always guard with `root.widgetContext ?` — the context object arrives after the loader sets it; the component may render one frame before it is populated.

---

### Full.qml template

```qml
import QtQuick
import IslandBackend

Item {
    id: root

    // ── Widget contract ─────────────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    // ── Convenience aliases ─────────────────────────────────────────────────
    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property real scale: widgetContext ? widgetContext.uiScale : 1.0

    // ── Layout ──────────────────────────────────────────────────────────────
    anchors.fill: parent
    clip: true

    // YOUR CONTENT HERE
    Text {
        anchors.centerIn: parent
        text: "My Widget"
        color: "white"
        font.family: root.textFont
        font.pixelSize: Math.round(16 * root.scale)
        font.weight: Font.Bold
    }
}
```

---

### Minimum.qml template

> **STRICT RULE — Non-Interactive:** `Minimum.qml` widgets **must not** contain `MouseArea`, `TapHandler`, or clickable controls. Clicking the closed notch is strictly reserved by the system to expand the notch (or swipe pages / enter edit mode). All interactive controls (buttons, play/pause, launches) belong exclusively in `Full.qml`.

```qml
import QtQuick

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"

    anchors.fill: parent
    clip: true

    // Keep it tight — the closed notch is very narrow.
    // A typical pattern: icon glyph + single line of text.
    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰀀"
            font.family: root.iconFont
            font.pixelSize: 14
            color: "white"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Value"
            font.family: root.textFont
            font.pixelSize: 13
            font.weight: Font.SemiBold
            color: "white"
        }
    }
}
```

---

### Circle.qml template

> **STRICT RULE — Non-Interactive:** `Circle.qml` widgets **must not** contain `MouseArea`, `TapHandler`, or clickable controls. Clicking the circle notch is strictly reserved by the system to expand the notch (or swipe pages / enter edit mode). All interactive controls belong exclusively in `Full.qml`.

```qml
import QtQuick

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property real diameter: widgetContext ? widgetContext.circleDiameter : Math.min(width, height)
    readonly property real fs: widgetContext ? widgetContext.faceScale : 1.0

    anchors.fill: parent
    clip: true

    // A subtle boundary ring is conventional for circle widgets
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 2
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: "#2c2c2e"
    }

    // Canvas-based progress ring example:
    Canvas {
        id: progressRing
        anchors.fill: parent
        antialiasing: true

        property real progress: 0.75   // replace with real data

        onProgressChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const center = width / 2;
            const radius = center - 2;
            if (radius <= 0) return;

            // Track
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, 2 * Math.PI);
            ctx.lineWidth = 2.2;
            ctx.strokeStyle = "#2c2c2e";
            ctx.stroke();

            // Arc
            if (progress > 0.005) {
                const start = -Math.PI / 2;
                ctx.beginPath();
                ctx.arc(center, center, radius, start, start + 2 * Math.PI * progress);
                ctx.lineWidth = 2.2;
                ctx.lineCap = "round";
                ctx.strokeStyle = "#0a84ff";
                ctx.stroke();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "75%"
            color: "white"
            font.family: root.textFont
            font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (root.diameter - 44) * 0.08)))
            font.weight: Font.Bold
        }
    }
}
```

---

### 5. Register in `WidgetRegistry.qml`

Open `qml/widgets/WidgetRegistry.qml` and add an entry to the `catalog` array:

```qml
{
    id: "<widget_id>",
    name: "Human Readable Name",
    description: "One sentence description.",
    icon: "󰀀",
    supportedSizes: ["full", "minimum", "circle"],  // only what you implemented
    defaultSlotSpan: 1,
    fullComponent: Qt.resolvedUrl("<widget_id>/Full.qml"),
    minimumComponent: Qt.resolvedUrl("<widget_id>/Minimum.qml"),
    circleComponent: Qt.resolvedUrl("<widget_id>/Circle.qml")
}
```

Leave out any `*Component` key whose corresponding file you did not create.

> **Do not** change `getComponentUrl()` — it already handles missing components gracefully by returning `""`.

---

### 6. Verify

```bash
# From the project root
cmake --build build
timeout 4s quickshell -p shell.qml 2>&1 | grep -E "Error|Warning|Configuration"
```

Expected output contains `Configuration Loaded` with no errors on your widget files.

---

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Accessing `widgetContext.foo` directly | Always guard: `widgetContext ? widgetContext.foo : fallback` |
| Not declaring `property var widgetContext: null` | The loader will warn about unknown property |
| Omitting a size from `supportedSizes` in manifest but creating the file | Update `supportedSizes` to match reality |
| Forgetting `anchors.fill: parent` at root | Widget won't fill its slot |
| Using `slots` as a C++ parameter name | Qt macro conflict — use `slotCount` |
| Using a pixel size that ignores `uiScale` | Multiply by `root.scale` for responsive sizing |
| Adding `MouseArea` or click handlers in `Minimum.qml` or `Circle.qml` | **Never** make pill or circle widgets interactive. Clicks on closed/circle notch must only expand the notch. Place all interactivity in `Full.qml`. |

---

## Design conventions

- **Interactivity policy:** Only `Full.qml` (expanded view) is interactive. `Minimum.qml` (closed pill) and `Circle.qml` (circle mode) are read-only, glanceable displays. Clicks on the closed or circle notch are reserved to expand the notch.
- **Background:** Widgets render on a dark surface (`#1c1c1e`). No need to add your own background rectangle.
- **Text color:** Primary text = `"white"`, secondary = `"#8e8e93"`, accent = `"#b56cff"`.
- **Accent colors per ring/chart:** Battery green `#30d158`, CPU pink `#ff2d55`, RAM blue `#007aff`, generic blue `#0a84ff`.
- **Circle widgets:** Keep your innermost content within `≈ 65 %` of the circle diameter to leave room for the progress ring border.
- **Minimum widgets:** Width is shared equally among slots; keep content width-agnostic or use `elide: Text.ElideRight`.
- **Timer-based updates:** Use a `Timer { interval: 1000; running: true; repeat: true }` inside the widget itself — do not rely on `widgetContext` for live clock ticks unless `currentTime` satisfies your needs.
- **No side effects:** Widgets should not write to `UserConfig` or call system services unless the user explicitly triggers an action (button press).
