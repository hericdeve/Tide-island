# Tide Island — Standardized Widget System Specifications

This document defines the formal architecture, element taxonomy, component contracts, theme bindings, and cross-view mode behavior for the Tide Island widget ecosystem (`/home/rodia/Projects/Tide-island/qml/widgets`).

---

## 1. System Architecture & Design Principles

Tide Island widgets are modular QML components rendered within notch slots of the dynamic island window. To ensure that AI agents and human developers can reliably create, maintain, and audit widgets without visual regressions, all widgets must conform to the following core tenets:

1. **Theme Compliance via `StyleTokens`**:
   Hardcoded hex colors (such as `"#ffffff"` or `"#000000"`) are strictly prohibited for core UI roles. Widgets must bind to `IslandBackend.StyleTokens` (`StyleTokens.textPrimary`, `StyleTokens.panel`, `StyleTokens.module`, `StyleTokens.track`, etc.) to guarantee seamless, real-time reactive support for **Black**, **White** (light mode), and **Noctalia** theme palettes.

2. **Component Composition over Custom Logic**:
   Widgets should not build custom search inputs, buttons, sliders, progress bars, or timers from scratch. Instead, widgets import and compose standardized primitives from `../components` (`WidgetSearchInput`, `WidgetProgressBar`, `WidgetTimerClock`, etc.).

3. **Strict Interaction Boundaries per View Mode**:
   - **`Full.qml` (Expanded Notch)**: Fully interactive. Buttons, sliders, text inputs, drag-and-drop targets, and mouse clicks are encouraged.
   - **`Minimum.qml` (Closed Pill)**: Strictly non-interactive. Displays ambient, glanceable status. Must not include `MouseArea`, `TapHandler`, or clickable elements.
   - **`Circle.qml` (Smartwatch Face)**: Strictly non-interactive. Displays circular dial complications. Must not include mouse or click handlers.

4. **Respect for User Paddings & Grid Margins**:
   The Dynamic Island host reserves configurable outer margins (`userConfig.notchExpandedPaddingHorizontal`, `userConfig.notchExpandedPaddingVertical`, `userConfig.notchClosedPaddingHorizontal`) and 8px slot separation (`WidgetSlotGrid.spacing`). A widget is strictly confined to its assigned slot area (`width` and `height`) and must respect internal margins (typically `4px` to `8px`) without bleeding outside its container bounds.

5. **The Invariant of Usable Space**:
   *Usable Space* is defined as the net bounding box (`width` and `height`) allocated to a widget inside its slot, minus internal container margins and spacing.
   - **Strict Invariant**: All visual elements of all widgets (including buttons, text rows, cards, icons, sliders, headers, and footers) must fit strictly within this usable space across all slot counts (`slotSpan: 1..6`), screen heights, and font scaling configurations.
   - **Zero-Clipping / Zero-Overlap**: No element may poke past the bottom margin, overflow the horizontal edges, or collide with adjacent controls.
   - **Adaptive Sizing & Multi-Tier Compacting**: Action controls (`WidgetActionButton`, etc.), toolbars, and spacing must dynamically adapt (e.g. `buttonSize`, `compactMode`, `ultraCompactMode`, `Math.min`) to guarantee they never overflow narrow slot spans (e.g. 1-slot in a 3- to 6-slot grid) or reduced notch heights.

6. **Dynamic Resizing Protocol (Notch Expansion for Content)**:
   - Adhering strictly to usable space **must never break dynamic resizing**.
   - When content naturally requires more space—specifically multi-line text boxes, consent prompts, transcript views, or dynamic lists that need to show all their lines—widgets must NOT force-clip or awkwardly truncate the content.
   - Instead, widgets declare `"capabilities": ["dynamic_resize"]` in `manifest.json` and expose `requestedContentHeight` (and/or `requestedContentWidth`).
   - By measuring wrapped text (e.g. via `WidgetTextView.measuredHeight` or hidden probe) and requesting `baseSlotHeight + extraHeight`, the widget triggers the host Dynamic Island window to smoothly expand its height (`notchOpenHeight + activeExtraHeight`), dynamically enlarging the slot container and expanding the widget's usable space so that all text lines are displayed completely without scrollbars or clipping.
   - Within this newly expanded space, all elements still strictly remain within the updated usable space bounds.

7. **Auditable Metadata**:
   Every widget declares its element tags in `manifest.json` under `"elements": [...]` to enable repository-wide indexing via `scripts/audit_widgets.py`.

---

## 2. Standardized Element Taxonomy & Component Catalog

All standardized components reside in `qml/widgets/components/` and are imported via:
```qml
import "../components"
```

### Element 1: Search Bar & Text Input (`WidgetSearchInput.qml`)
- **Component**: `WidgetSearchInput`
- **Manifest Tag**: `"search_bar"`
- **Role**: Single-line text entry with leading search glyph, clear button, active focus outline, and submit signals.
- **Properties**:
  | Property | Type | Default | Description |
  |---|---|---|---|
  | `text` | `string` | `""` | Input text (read/write) |
  | `placeholder` | `string` | `"Search..."` | Placeholder text when empty |
  | `icon` | `string` | `"󰍉"` | Leading search glyph |
  | `showClearButton` | `bool` | `true` | Shows trailing clear icon when text is entered |
  | `inputHeight` | `real` | `32` | Standard height (28px compact, 32px standard) |
  | `radiusOverride` | `real` | `StyleTokens.radiusPrompt` | Corner radius (16px) |
  | `autoFocus` | `bool` | `false` | Focuses input immediately on component load |
  | `widgetContext` | `var` | `null` | Context object for font family and scaling |
- **Signals**:
  - `accepted(string query)`: Emitted on Enter / Return keypress.
  - `cleared()`: Emitted when clear button is clicked.
  - `textEdited(string newText)`: Emitted on every user keystroke.
- **Theme Bindings**:
  - Surface: `StyleTokens.input`
  - Outline: `StyleTokens.accent` when focused, `StyleTokens.inputBorder` when idle
  - Text: `StyleTokens.textPrimary` (placeholder: `StyleTokens.textTertiary`)
- **View Mode Degradation**:
  - `Full`: Full interactive input field.
  - `Minimum`: Read-only search icon pill with truncated active query.
  - `Circle`: Centered search complication glyph (`"󰍉"`).

---

### Element 2: Text View Field (`WidgetTextView.qml`)
- **Component**: `WidgetTextView`
- **Manifest Tag**: `"text_view"`
- **Role**: Typography component with predefined hierarchy roles, line limits, and automatic marquee scrolling on overflow.
- **Properties**:
  | Property | Type | Default | Description |
  |---|---|---|---|
  | `text` | `string` | `""` | Rendered string |
  | `role` | `string` | `"body"` | `"hero"`, `"title"`, `"body"`, `"caption"`, `"metric"`, `"code"` |
  | `overflowMode` | `string` | `"elide"` | `"elide"`, `"marquee"`, `"wrap"`, `"clip"` |
  | `maximumLineCount`| `int` | `1` | Max visible lines when wrap or elide is active |
  | `marqueeSpeed` | `real` | `30` | Scrolling speed in pixels/second |
  | `colorOverride` | `color` | `transparent` | Custom color override |
  | `measureOnly` | `bool` | `false` | Used for calculating off-screen geometry |
  | `widgetContext` | `var` | `null` | Context object for font family and scaling |
- **Typography Roles**:
  - `"hero"`: 26px bold figures, uses `heroFontFamily`.
  - `"title"`: 20px demi-bold headings, uses `StyleTokens.textPrimary`.
  - `"body"`: 13px medium body text, uses `StyleTokens.textSecondary`.
  - `"caption"`: 11px regular captions, uses `StyleTokens.textTertiary`.
  - `"metric"`: 15px bold tabular figures (`tnum: 1`), uses `StyleTokens.textPrimaryBright`.
  - `"code"`: 11px monospace code, uses `iconFontFamily` and `StyleTokens.textSoft`.
- **Measurement Helpers & Multi-Line Expansion**:
  - `measuredWidth`: Exposes natural unclipped text width.
  - `measuredHeight`: Exposes wrapped text height for dynamic notch expansion.
  - **Showing All Text Lines Dynamically**: When a text field (such as a consent message, transcript, note body, or multi-line status) needs to display all its lines without truncation, set `overflowMode: "wrap"` and bind `width` to the container width. The internal probe automatically computes the exact wrapped height (`measuredHeight`). The widget then reports `requestedContentHeight: baseSlotHeight + Math.max(0, textView.measuredHeight - restingTextHeight)`, prompting the Dynamic Island to smoothly expand its vertical dimension so every line is visible without scrollbars, clipping, or breaking padding bounds.

---

### Element 3: Timers & Clocks (`WidgetTimerClock.qml`)
- **Component**: `WidgetTimerClock`
- **Manifest Tag**: `"timer_clock"`
- **Role**: Unified timing and clock engine with digital, circular, and compact representations. Uses OpenType tabular figures (`tnum: 1`) to eliminate character jitter.
- **Properties**:
  | Property | Type | Default | Description |
  |---|---|---|---|
  | `mode` | `string` | `"clock"` | `"clock"`, `"countdown"`, `"stopwatch"`, `"pomodoro"` |
  | `representation`| `string` | `"digital"` | `"digital"`, `"circular"`, `"compact"` |
  | `running` | `bool` | `true` | Runs or pauses ticking |
  | `totalSeconds` | `int` | `300` | Target time in seconds |
  | `elapsedSeconds`| `int` | `0` | Elapsed time in seconds |
  | `showMilliseconds`| `bool` | `false` | Displays `.cs` centiseconds in stopwatch mode |
  | `clockFormat` | `string` | `"hh:mm"` | Format string for clock mode |
  | `roundPhase` | `string` | `"work"` | Pomodoro phase: `"work"`, `"short-break"`, `"long-break"` |
  | `widgetContext` | `var` | `null` | Context object |
- **Signals**:
  - `tick(int elapsed, int remaining)`: Emitted on every tick.
  - `finished()`: Emitted when countdown or pomodoro round completes.

---

### Element 4: Progress Bars & Rings (`WidgetProgressBar.qml`, `WidgetProgressRing.qml`)
- **Components**: `WidgetProgressBar`, `WidgetProgressRing`
- **Manifest Tag**: `"progress_bar"`
- **Linear Progress Bar (`WidgetProgressBar`)**:
  - `value`: 0.0 to 1.0 (smooth cubic animated width transition).
  - `indeterminate`: animates continuous sweeping highlight across the track.
  - `barHeight`: 4px (thin), 6px (standard), 10px (prominent).
  - `fillColor`: `StyleTokens.accent`, `trackColor`: `StyleTokens.track`.
- **Radial Progress Ring (`WidgetProgressRing`)**:
  - Single arc: `value` (0.0 to 1.0), `strokeWidth` (default 3px), anti-aliased round caps.
  - Concentric multi-ring mode: `rings: [{ value: 0.8, fillColor: "...", trackColor: "..." }, ...]` for multi-resource meters (CPU, RAM, Battery).
  - High-DPI compensated 2D canvas pipeline with `requestPaint()` hook.

---

### Element 5: Icons & Glyphs (`WidgetIconGlyph.qml`)
- **Component**: `WidgetIconGlyph`
- **Manifest Tag**: `"icon_glyph"`
- **Role**: Scalable Nerd Font symbol with optional badge overlay (count pill or status dot) and animations.
- **Properties**:
  | Property | Type | Default | Description |
  |---|---|---|---|
  | `glyph` | `string` | `"󰀀"` | Unicode Nerd Font string |
  | `size` | `real` | `18` | Base size (scaled by `widgetContext.iconFontSize`) |
  | `color` | `color` | `StyleTokens.textPrimary` | Glyph color |
  | `badgeText` | `string` | `""` | Text inside notification badge |
  | `badgeActive` | `bool` | `false` | Displays status dot when `badgeText` is empty |
  | `badgeColor` | `color` | `StyleTokens.danger` | Badge background color |
  | `animation` | `string` | `"none"` | `"none"`, `"pulse"`, `"spin"` |

---

### Element 6: Action Controls (`WidgetActionButton.qml`, `WidgetToggleSwitch.qml`, `WidgetScrubberSlider.qml`)
- **Components**: `WidgetActionButton`, `WidgetToggleSwitch`, `WidgetScrubberSlider`
- **Manifest Tag**: `"action_control"`
- **Rules**: Restricted strictly to `Full.qml`. Must never be used in `Minimum.qml` or `Circle.qml`.
- **Button (`WidgetActionButton`)**:
  - Variants: `"capsule"` (pill with icon + label), `"icon"` (28x28px square), `"pill"` (compact text).
  - Styles: `"primary"` (`StyleTokens.accent`), `"secondary"` (`StyleTokens.buttonFill`), `"ghost"`, `"danger"`.
  - Press feedback: Micro-interaction scale shrink to 0.94 with `StyleTokens.durationFast` (120ms).
  - **Usable Space & Geometry Rules**:
    - When placed in `Full.qml` toolbars or rows, buttons must declare explicit `width: buttonSize` and `height: buttonSize` matching the toolbar's height.
    - Corner radius automatically clamps to `Math.min(height / 2, radiusOverride)` to prevent distortion when scaled down.
    - Icon font size automatically scales to button height (`Math.min(Math.round(root.height * 0.52), ...)`).
    - Rows of action buttons must center or space within the usable space, using responsive tiered modes (`compactMode`, `ultraCompactMode`) and dynamic spacing to ensure they never overflow available width or clip against container edges.
- **Toggle (`WidgetToggleSwitch`)**:
  - 38x22px capsule, 18px sliding circular white knob, `StyleTokens.success` when checked.
  - Signal: `toggled(bool checked)`.
- **Scrubber / Slider (`WidgetScrubberSlider`)**:
  - `value` (0.0 to 1.0), drag gesture with `preventStealing: true`, vertical mouse wheel adjustment with `WheelHandler`.

---

### Element 7: Lists & Status Cards (`WidgetListRow.qml`, `WidgetStatusCard.qml`, `WidgetDropTarget.qml`)
- **Components**: `WidgetListRow`, `WidgetStatusCard`, `WidgetDropTarget`
- **Manifest Tag**: `"list_card"`
- **List Row (`WidgetListRow`)**:
  - Left icon + Center Column (Title + Subtitle) + Right accessory (metric or chevron).
  - Hover background feedback: `StyleTokens.moduleHover`, `StyleTokens.radiusButton`.
- **Status Card (`WidgetStatusCard`)**:
  - `StyleTokens.module` container with 1px `StyleTokens.track` outline and `StyleTokens.radiusModule` (24px).
  - Header with icon, title, status dot, and optional action button.
- **Drop Target (`WidgetDropTarget`)**:
  - `DropArea` accepting `text/uri-list`, `text/plain`, `application/x-tide-file`.
  - Active hover drag pulses border with `StyleTokens.accent`.
  - Optional `autoAddToShelf: true` automatically integrates with `FileShelf.addUrls()`.

---

### Element 8: Free-Form / Custom Element (`WidgetCanvasSlot.qml`)
- **Component**: `WidgetCanvasSlot`
- **Manifest Tag**: `"freeform_slot"`
- **Role**: Safe escape hatch for widgets requiring arbitrary custom 2D canvas drawing (drawing tablet companion, waveform visualizer, game board) while guaranteeing token integration and viewport isolation.
- **Guardrails**:
  - Strict slot boundary clipping (`clip: true`).
  - Gesture isolation: `preventStealing: true` prevents parent island page drag handlers from interrupting drawing.
  - Automatically hooks into `StyleTokens.themeChanged` to call `requestPaint()`.
  - Exposes `requestedContentWidth` and `requestedContentHeight`.

---

## 3. Usable Space & Dynamic Notch Expansion Architecture

### 3.1 The Usable Space Hierarchy
Tide Island enforces a strict box model from the Wayland surface down to individual widget components:

```
┌────────────────────────────────────────────────────────────────────────┐
│ Dynamic Island Window (Hyprland/Niri Layer Surface)                    │
│   Height = notchOpenHeight + dynamicResizeEngine.activeExtraHeight     │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Notch Padding: top/bottom (default 6-10px), left/right (8px)     │  │
│  │  ┌────────────────────────────────────────────────────────────┐  │  │
│  │  │ NotchStatusBar (Persistent top bar, 24px)                  │  │  │
│  │  ├────────────────────────────────────────────────────────────┤  │  │
│  │  │ WidgetSlotGrid: 1 to 6 slots, 8px spacing between columns  │  │  │
│  │  │  ┌─────────────────────────┐  ┌─────────────────────────┐  │  │  │
│  │  │  │ WidgetSlot (Slot 0)     │  │ WidgetSlot (Slot 1)     │  │  │  │
│  │  │  │  ┌───────────────────┐  │  │                         │  │  │  │
│  │  │  │  │ Widget Full.qml   │  │  │                         │  │  │  │
│  │  │  │  │ anchors.margins:  │  │  │                         │  │  │  │
│  │  │  │  │ (e.g. 4-8px)      │  │  │                         │  │  │  │
│  │  │  │  │  ┌─────────────┐  │  │  │                         │  │  │  │
│  │  │  │  │  │ USABLE      │  │  │  │                         │  │  │  │
│  │  │  │  │  │ SPACE       │  │  │  │                         │  │  │  │
│  │  │  │  │  │ (All UI fits│  │  │  │                         │  │  │  │
│  │  │  │  │  │  strictly)  │  │  │  │                         │  │  │  │
│  │  │  │  │  └─────────────┘  │  │  │                         │  │  │  │
│  │  │  │  └───────────────────┘  │  │                         │  │  │  │
│  │  │  └─────────────────────────┘  └─────────────────────────┘  │  │  │
│  │  └────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Window Padding**: Configured in `userconfig.json` (`notchExpandedPaddingHorizontal`, `notchExpandedPaddingVertical`). Must never be bypassed.
2. **Grid Spacing**: Fixed 8px gap (`WidgetSlotGrid.spacing`) between slot columns.
3. **Slot Container**: Bounded by `width: span * slotBaseWidth + (span - 1) * spacing` and `height: gridContainer.height`.
4. **Widget Usable Space**: The net area inside the widget after deducting outer margins.
   - **Strict Invariant**: Every child item (labels, buttons, progress bars, drop targets, canvas) must be strictly positioned and sized within this rectangle.
   - Never use negative margins to poke outside the slot bounds.
   - Buttons must match toolbar height (`height: buttonSize`, `anchors.bottomMargin: 2` to `4`) so their rounded corners and hover backgrounds are never sliced off by container clipping.
   - Rows of buttons must dynamically reduce sizes and collapse secondary actions (`ultraCompactMode`, `compactMode`) when slot width is narrow.

---

### 3.2 Dynamic Notch Expansion for Multi-Line Text Boxes
The strict adherence to usable space **does not mean content must be cramped or artificially truncated**. When a widget contains content that needs more vertical space—such as multi-line text boxes, consent prompts, streaming transcripts, or note bodies—the widget expands the notch dynamically so that all lines can be legibly displayed.

#### How It Works:
1. **Declare Capability**:
   Add `"dynamic_resize"` to `"capabilities"` in `manifest.json`:
   ```json
   "capabilities": [
     "dynamic_resize"
   ]
   ```
2. **Measure Natural Content Height**:
   Use `WidgetTextView.measuredHeight` (with `overflowMode: "wrap"`) or a hidden text probe bound to the current usable width:
   ```qml
   WidgetTextView {
       id: bodyText
       width: parent.width
       overflowMode: "wrap"
       maximumLineCount: 0 // Allow all lines
       role: "body"
       text: root.fullTextContent
       widgetContext: root.widgetContext
   }
   ```
3. **Compute `requestedContentHeight`**:
   Compare the measured height against the baseline slot height and request the exact expansion needed:
   ```qml
   readonly property real baseSlotHeight: Math.max(120, (UserConfig.notchOpenHeight || 190) - 52)
   readonly property real requestedContentHeight: {
       const textH = bodyText.measuredHeight;
       const restingTextH = 40; // Height allocated in standard resting state
       if (textH > restingTextH) {
           const extraH = Math.min(180, textH - restingTextH);
           return baseSlotHeight + extraH;
       }
       return 0; // 0 reverts to standard slot height
   }
   ```
4. **Host Expansion Pipeline**:
   - `WidgetSlot` reads `widgetLoader.item.requestedContentHeight` and signals `WidgetSlotGrid`.
   - `WidgetSlotGrid` computes `maxReqH = Math.max(...)` across all visible slots on the active page.
   - `ExpandedPlayerLayer` adds user vertical padding and status bar height.
   - `DynamicIslandWindow` animates `targetHeight` smoothly to the expanded height.
   - The slot container expands downward, enlarging the widget's usable space.
   - All text lines render cleanly within the newly enlarged usable space without scrollbars, clipping, or text overlapping adjacent controls.

---

## 4. Noctalia IPC Integration (`WidgetNoctaliaBridge.qml`)

Widgets communicate with the host desktop environment via `noctalia msg`.

```qml
import "../components"

WidgetNoctaliaBridge {
    id: noctalia
    autoPollStatus: true
    pollInterval: 5000

    onStatusUpdated: function(status) {
        console.log("Noctalia status:", status.volume, status.wifi);
    }

    onFallbackRequested: function(feature) {
        // Fallback to standard CLI tools if daemon is offline
    }
}

// Triggering commands:
WidgetActionButton {
    icon: "󰤨"
    label: "Toggle WiFi"
    onClicked: noctalia.send("wifi-toggle")
}
```

### Common `noctalia msg` Subcommands
- Audio: `volume-set <0-100>`, `volume-up`, `volume-down`, `volume-mute`, `mic-mute`.
- Connectivity: `wifi-status`, `wifi-toggle`, `wifi-enable`, `wifi-disable`, `bluetooth-status`, `bluetooth-toggle`.
- Display & Power: `brightness-set <0-100>`, `nightlight-toggle`, `caffeine-toggle`, `power-set <profile>`.
- Desktop & Shell: `wallpaper-set <path>`, `wallpaper-random`, `notification-dnd-toggle`, `status` (emits full system state as JSON).

---

## 5. Cross-View Mode Matrix

| Element | Full View (`Full.qml`) | Minimum View (`Minimum.qml`) | Circle View (`Circle.qml`) |
|---|---|---|---|
| **Search Input** | Full TextInput + Clear button | Read-only query pill or icon | Search complication glyph (`"󰍉"`) |
| **Text View** | Multi-line wrap or auto-marquee | 1-line right-elided text | Center metric / value |
| **Timer / Clock** | Full digital timer + buttons | Compact `"MM:SS"` pill | Radial progress arc + time |
| **Progress Bar/Ring** | Full linear bar with fill | 3px mini track or badge | Single or 3-ring concentric arc |
| **Icon Glyph** | Icon + unread badge pill | 14px status glyph | Central complication glyph |
| **Action Controls** | Interactive buttons / sliders | Read-only status indicator | Read-only progress ring |
| **Lists & Cards** | Interactive list / status card | Item count pill | Progress dial (Done/Total) |
| **Free-Form Slot** | Interactive drawing canvas | Static preview thumbnail | Radial mini complication |

---

## 6. Declarative Manifest Schema (`manifest.json`)

Each widget's `manifest.json` defines its identity, view modes, and element composition:

```json
{
  "id": "obsidian_companion",
  "name": "Obsidian Companion",
  "description": "Quick daily capture, task completion counter, and vault search",
  "icon": "󰎚",
  "supportedSizes": ["full", "minimum", "circle"],
  "defaultSlotSpan": 2,
  "elements": [
    "search_bar",
    "text_view",
    "action_control",
    "list_card",
    "icon_glyph"
  ],
  "capabilities": [
    "file_shelf",
    "dynamic_resize"
  ]
}
```

### Supported Element Tags for Manifest
- `"search_bar"`
- `"text_view"`
- `"timer_clock"`
- `"progress_bar"`
- `"progress_ring"`
- `"icon_glyph"`
- `"action_control"`
- `"toggle_switch"`
- `"scrubber_slider"`
- `"list_row"`
- `"status_card"`
- `"drop_target"`
- `"freeform_slot"`
- `"noctalia_ipc"`

---

## 7. Blueprints for Future Planned Widgets

1. **Obsidian Companion**:
   - `Full.qml`: `WidgetSearchInput` for note search + `WidgetTextView` (daily prompt) + `WidgetActionButton` ("Quick Capture") + `WidgetDropTarget` (attach images/links to daily note).
   - `Minimum.qml`: `WidgetIconGlyph` ("󰎚") + `WidgetTextView` (uncompleted tasks count).
   - `Circle.qml`: `WidgetProgressRing` (tasks completed %) + `WidgetIconGlyph` ("󰎚").

2. **Xournal++ Drawing Tablet Companion**:
   - `Full.qml`: Row of `WidgetActionButton` (pen, highlighter, eraser, color swatches) + `WidgetCanvasSlot` (scratchpad / stroke preview).
   - `Minimum.qml`: Active tool icon + color indicator dot.
   - `Circle.qml`: Active tool glyph in center + stroke width indicator ring.

3. **Sports Live Monitor**:
   - `Full.qml`: `WidgetTextView` (team names, scores, possession) + `WidgetTimerClock` (game clock) + `WidgetProgressBar` (quarter/period progress).
   - `Minimum.qml`: `WidgetTextView` dynamic pill ("LAL 102 - 98 GSW") with `requestedContentWidth`.
   - `Circle.qml`: Team glyph complication + period progress ring.

4. **Calendar Agenda**:
   - `Full.qml`: `WidgetTimerClock` (countdown to next event) + `WidgetListRow` (upcoming 3 meetings) + `WidgetActionButton` ("Join Call").
   - `Minimum.qml`: Next event summary pill ("Design Sync in 12m").
   - `Circle.qml`: `WidgetProgressRing` (time remaining before next event) + calendar icon.

5. **Timer & Stopwatch**:
   - `Full.qml`: `WidgetTimerClock` (digital readout) + `WidgetProgressBar` + `WidgetActionButton` (Start/Pause, Reset, +1m, Lap).
   - `Minimum.qml`: Compact `"MM:SS"` or `"01:23.4"` label.
   - `Circle.qml`: `WidgetProgressRing` (elapsed %) + centered time digits.

6. **System Monitor**:
   - `Full.qml`: 3 rows of `WidgetTextView` + `WidgetProgressBar` for CPU, RAM, and Disk storage.
   - `Minimum.qml`: Compact `"C 18% | R 45%"` metric pill.
   - `Circle.qml`: `WidgetProgressRing` concentric 3-ring Activity dial (Battery outer, CPU middle, RAM inner).

7. **WiFi & Bluetooth Manager**:
   - `Full.qml`: `WidgetNoctaliaBridge` + `WidgetToggleSwitch` (WiFi on/off, BT on/off) + `WidgetListRow` (nearby APs and paired devices).
   - `Minimum.qml`: Connected SSID name + signal icon glyph.
   - `Circle.qml`: Signal icon glyph + connection status ring.

8. **AI API Key Quota Monitor**:
   - `Full.qml`: `WidgetProgressBar` (credits used %) + `WidgetTextView` (tokens count & reset date) + `WidgetStatusCard`.
   - `Minimum.qml`: Remaining percentage badge ("82% quota").
   - `Circle.qml`: `WidgetProgressRing` (remaining quota %) + AI glyph ("󰚩").

9. **Wallpaper Setter**:
   - `Full.qml`: `WidgetNoctaliaBridge` (`wallpaper-set`, `wallpaper-random`) + thumbnail grid + `WidgetActionButton` ("Next Random").
   - `Minimum.qml`: Active wallpaper theme color swatch dot.
   - `Circle.qml`: Centered wallpaper icon with transition indicator ring.

10. **AI Dictation App**:
    - `Full.qml`: `WidgetActionButton` (record toggle) + `WidgetProgressBar` (voice waveform level) + `WidgetTextView` (live streamed transcription).
    - `Minimum.qml`: Blinking red recording dot + "Listening...".
    - `Circle.qml`: Pulsing recording ring + microphone glyph.

11. **LocalSend File Sharing**:
    - `Full.qml`: `WidgetDropTarget` (drop to share) + `WidgetListRow` (available LAN devices) + `WidgetProgressBar` (send progress).
    - `Minimum.qml`: Transfer status pill ("Sending 45%...").
    - `Circle.qml`: Radial transfer progress ring + share glyph.

---

## 8. Auditing & Inspection CLI

Use `scripts/audit_widgets.py` to inspect and verify widget compliance across the repository:

```bash
# List all widgets and their element declarations
python3 scripts/audit_widgets.py --list-widgets

# Find all widgets that use a specific element (e.g. search_bar or timer_clock)
python3 scripts/audit_widgets.py --find-element timer_clock

# Check compliance of all widgets in the repo
python3 scripts/audit_widgets.py --verify-all
```
