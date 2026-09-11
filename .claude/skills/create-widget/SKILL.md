---
name: create-widget
description: Scaffold and register a standardized, themed widget for the Tide Island notch ecosystem
---

# Tide Island — Create Widget Skill

You are creating a new widget for the **Tide Island** Dynamic Island for Linux/Wayland (`/home/rodia/Projects/Tide-island`).

## Golden Rules for Widget Creation

1. **Mandatory StyleTokens Theme Binding**:
   - Never use hardcoded hex colors (`"#ffffff"`, `"#000000"`, `"#1c1c1e"`, `"#8e8e93"`) for core UI roles.
   - Bind all surfaces, borders, and text to `IslandBackend.StyleTokens` (e.g. `StyleTokens.panel`, `StyleTokens.module`, `StyleTokens.track`, `StyleTokens.textPrimary`, `StyleTokens.textSecondary`, `StyleTokens.accent`, `StyleTokens.radiusButton`). This guarantees seamless support for **Black**, **White** (light theme), and **Noctalia** theme palettes.
2. **Strict View Mode Interactivity Boundaries**:
   - `Full.qml` (Expanded Notch): **Interactive**. MouseArea, buttons, text inputs, sliders, and drop targets are welcome.
   - `Minimum.qml` (Closed Pill) & `Circle.qml` (Smartwatch Face): **STRICTLY NON-INTERACTIVE**. You must **never** add `MouseArea`, `TapHandler`, `Button`, or clickable elements to `Minimum.qml` or `Circle.qml`. Clicking the closed notch is strictly reserved by the compositor to expand the notch or cycle pages.
3. **Use Standardized Components & Strict Zero-Tolerance for Bare `Text {}`**:
   - Do not reinvent search bars, progress bars, buttons, timers, or list rows. Import and compose them from `../components` (`WidgetSearchInput`, `WidgetProgressBar`, `WidgetTimerClock`, etc.).
   - **No Bare `Text {}` Elements**: Bare Qt Quick `Text {}` elements are strictly forbidden in all widget files. All typography must use `WidgetTextView` (ensuring correct typography roles, consistent font family bindings, contrast tokens, tabular figures, and overflow handling), and all standalone icon glyphs must use `WidgetIconGlyph`. This is strictly checked by `scripts/audit_widgets.py --verify-all` and has zero backwards compatibility.
4. **Scale Typography Proportional to User Config**:
   - `font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)`
   - `font.pixelSize: Math.round(18 * root.titleFontSize / 20.0)`
   - `font.pixelSize: Math.round(16 * root.iconFontSize / 18.0)`
5. **Context Safety**:
   - Always guard `widgetContext` property accesses with `root.widgetContext ? root.widgetContext.prop : fallback`.
6. **Auditable Metadata**:
   - Always declare used elements in `manifest.json` under `"elements": [...]` to support repository discovery.

---

## What a Widget Is

A widget is a self-contained QML module located in `qml/widgets/<widget_id>/` consisting of:

| File | Size Variant | Interactive? | Description |
|---|---|---|---|
| `Full.qml` | Full | **Yes** | Rendered in expanded notch slot (~138px height, 1-6 columns) |
| `Minimum.qml` | Minimum | **No** | Rendered in closed notch pill (32-34px height, 50-185px width) |
| `Circle.qml` | Circle | **No** | Rendered in smartwatch dial face (44-64px diameter) |
| `manifest.json` | — | — | Metadata, supported sizes, slot span, element tags, and capabilities |

> A widget can implement any subset of sizes (e.g. `boring_face` is circle-only), but must implement at least one.

---

## Standardized Component Library (`qml/widgets/components/`)

Import components into any widget QML file using:
```qml
import "../components"
```

| Component | Manifest Tag | Purpose |
|---|---|---|
| `WidgetSearchInput` | `"search_bar"` | Search/text input with clear button, active focus outline, and submit handler |
| `WidgetTextView` | `"text_view"` | Typography field with roles (`"hero"`, `"title"`, `"body"`, `"caption"`, `"metric"`, `"code"`), alignments, tabular figures, and auto-marquee |
| `WidgetTimerClock` | `"timer_clock"` | High-precision timer, clock, stopwatch, and pomodoro with tabular numbers (`tnum: 1`) |
| `WidgetProgressBar` | `"progress_bar"` | Linear progress bar with smooth cubic animation and indeterminate sweep |
| `WidgetProgressRing` | `"progress_bar"` | Canvas 2D radial arc and concentric multi-ring progress meter (Activity rings) |
| `WidgetIconGlyph` | `"icon_glyph"` | Scalable Nerd Font glyph with badge pill / status dot overlay and animations |
| `WidgetActionButton` | `"action_control"` | Action button (`"capsule"`, `"icon"`, `"pill"`) with scale feedback (0.94) |
| `WidgetToggleSwitch` | `"action_control"` | 38x22px toggle capsule with animated sliding circular knob |
| `WidgetScrubberSlider` | `"action_control"` | Continuous slider/scrubber with drag & wheel stepping (`preventStealing: true`) |
| `WidgetListRow` | `"list_card"` | Compact list row (icon + title + subtitle + accessory metric) with hover state |
| `WidgetStatusCard` | `"list_card"` | Grouped card container (`StyleTokens.module`, radius 24px) with status indicator |
| `WidgetDropTarget` | `"list_card"` | File drop target integrating with Qt `DropArea` and `FileShelf` |
| `WidgetCanvasSlot` | `"freeform_slot"`| Escape hatch for custom 2D canvas drawing (tablet handwriting, custom shaders) |
| `WidgetNoctaliaBridge` | `"noctalia_ipc"` | Subprocess runner for `noctalia msg <subcmd>` commands and status polling |

---

## Step-by-Step Creation Workflow

### Step 1: Scaffold Directory & `manifest.json`

Create `qml/widgets/<widget_id>/manifest.json`:
```json
{
  "id": "<widget_id>",
  "name": "Human Readable Name",
  "description": "One sentence: what this widget does.",
  "icon": "󰀀",
  "supportedSizes": ["full", "minimum", "circle"],
  "defaultSlotSpan": 1,
  "elements": [
    "text_view",
    "progress_bar",
    "action_control"
  ],
  "capabilities": [
    "dynamic_resize"
  ]
}
```

---

### Step 2: Implement `Full.qml` (Expanded Interactive View)

```qml
import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    // ── Standard Widget Contract ─────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    // ── Convenience Typography & Metrics ─────────────────────────────────────
    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    anchors.fill: parent
    clip: true

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        WidgetTextView {
            width: parent.width
            role: "title"
            text: "My Widget Title"
            widgetContext: root.widgetContext
        }

        WidgetProgressBar {
            width: parent.width
            value: 0.65
            fillColor: StyleTokens.accent
        }

        Row {
            spacing: 8

            WidgetActionButton {
                variant: "capsule"
                icon: "󰐕"
                label: "Action"
                buttonStyle: "primary"
                widgetContext: root.widgetContext
                onClicked: console.log("Primary action triggered")
            }

            WidgetActionButton {
                variant: "icon"
                icon: "󰒓"
                buttonStyle: "secondary"
                widgetContext: root.widgetContext
                onClicked: console.log("Settings action triggered")
            }
        }
    }
}
```

---

### Step 3: Implement `Minimum.qml` (Closed Ambient Pill)

> **STRICT RULE**: Strictly non-interactive! No `MouseArea`, buttons, or inputs.

```qml
import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    // ── Standard Widget Contract ─────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    // ── Dynamic Width Morphing Protocol ──────────────────────────────────────
    readonly property real requestedContentWidth: Math.min(220, contentRow.implicitWidth + 20)
    readonly property real requestedContentHeight: 0

    anchors.fill: parent
    clip: true

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        WidgetIconGlyph {
            glyph: "󰀀"
            size: 14
            color: StyleTokens.accent
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            role: "body"
            text: "Active Status"
            colorOverride: StyleTokens.textPrimary
            overflowMode: "elide"
            maximumLineCount: 1
            widgetContext: root.widgetContext
        }
    }
}
```

---

### Step 4: Implement `Circle.qml` (Smartwatch Complication)

> **STRICT RULE**: Strictly non-interactive! Displays radial progress arc and centered complication.

```qml
import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    // ── Standard Widget Contract ─────────────────────────────────────────────
    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property real diameter: widgetContext ? widgetContext.circleDiameter : Math.min(width, height)

    anchors.fill: parent
    clip: true

    // Radial Progress Border
    WidgetProgressRing {
        anchors.fill: parent
        value: 0.75
        fillColor: StyleTokens.accent
        trackColor: StyleTokens.track
        strokeWidth: 3.0
    }

    // Centered Complication Glyph & Label
    Column {
        anchors.centerIn: parent
        spacing: 1

        WidgetIconGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "󰀀"
            size: 14
            color: StyleTokens.accent
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "metric"
            text: "75%"
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}
```

---

### Step 5: Register in `WidgetRegistry.qml`

Add the entry to the `catalog` array in `qml/widgets/WidgetRegistry.qml`:
```qml
{
    id: "<widget_id>",
    name: "Human Readable Name",
    description: "One sentence description.",
    icon: "󰀀",
    supportedSizes: ["full", "minimum", "circle"],
    defaultSlotSpan: 1,
    fullComponent: Qt.resolvedUrl("<widget_id>/Full.qml"),
    minimumComponent: Qt.resolvedUrl("<widget_id>/Minimum.qml"),
    circleComponent: Qt.resolvedUrl("<widget_id>/Circle.qml")
}
```

---

### Step 6: Verify and Audit

```bash
# 1. Audit element compliance and interactivity rules
python3 scripts/audit_widgets.py --verify <widget_id>

# 2. Compile and test for QML syntax/import errors
cmake --build build
timeout 4s quickshell -p shell.qml 2>&1 | grep -E "Error|Warning|Configuration"
```
Expected output confirms `Configuration Loaded` without QML errors.
