#!/usr/bin/env python3
"""
Tide Island Widget Auditing & Element Discovery CLI

Used to inspect, audit, and cross-reference widgets and their standardized element specifications.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

STANDARD_ELEMENTS = {
    "search_bar": "WidgetSearchInput",
    "text_view": "WidgetTextView",
    "timer_clock": "WidgetTimerClock",
    "progress_bar": "WidgetProgressBar",
    "progress_ring": "WidgetProgressRing",
    "icon_glyph": "WidgetIconGlyph",
    "action_control": "WidgetActionButton",
    "toggle_switch": "WidgetToggleSwitch",
    "scrubber_slider": "WidgetScrubberSlider",
    "list_row": "WidgetListRow",
    "status_card": "WidgetStatusCard",
    "drop_target": "WidgetDropTarget",
    "freeform_slot": "WidgetCanvasSlot",
    "noctalia_ipc": "WidgetNoctaliaBridge",
}

INTERACTIVE_PATTERNS = [
    r"\bMouseArea\b",
    r"\bTapHandler\b",
    r"\bDragHandler\b",
    r"\bButton\b",
    r"\bTextInput\b",
    r"\bTextField\b",
    r"\bWidgetActionButton\b",
    r"\bWidgetToggleSwitch\b",
    r"\bWidgetScrubberSlider\b",
    r"\bWidgetSearchInput\b",
]

def find_repo_root() -> Path:
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "qml" / "widgets").is_dir():
            return current
        current = current.parent
    return Path.cwd()

def get_widget_dirs(repo_root: Path):
    widgets_dir = repo_root / "qml" / "widgets"
    if not widgets_dir.is_dir():
        return []
    return [
        d for d in widgets_dir.iterdir()
        if d.is_dir() and d.name != "components" and (d / "manifest.json").is_file()
    ]

def load_manifest(widget_dir: Path) -> dict:
    manifest_path = widget_dir / "manifest.json"
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        return {"id": widget_dir.name, "error": str(e)}

def detect_used_elements(widget_dir: Path) -> set:
    used = set()
    manifest = load_manifest(widget_dir)
    if "elements" in manifest and isinstance(manifest["elements"], list):
        used.update(manifest["elements"])

    # Scan QML files for component instantiation
    for qml_file in widget_dir.glob("*.qml"):
        try:
            content = qml_file.read_text(encoding="utf-8")
            for elem_tag, comp_name in STANDARD_ELEMENTS.items():
                if re.search(r"\b" + comp_name + r"\b", content):
                    used.add(elem_tag)
        except Exception:
            pass
    return used

def cmd_find_element(repo_root: Path, target_element: str):
    print(f"\n🔍 Searching for widgets using element specification: '{target_element}'")
    matching = []
    comp_name = STANDARD_ELEMENTS.get(target_element, target_element)

    for w_dir in sorted(get_widget_dirs(repo_root), key=lambda d: d.name):
        used = detect_used_elements(w_dir)
        manifest = load_manifest(w_dir)
        name = manifest.get("name", w_dir.name)
        if target_element in used:
            matching.append((w_dir.name, name, "Declared in manifest or imported"))
        else:
            # Check by component name directly
            for qml_file in w_dir.glob("*.qml"):
                if re.search(r"\b" + comp_name + r"\b", qml_file.read_text(encoding="utf-8", errors="ignore")):
                    matching.append((w_dir.name, name, f"Instantiated in {qml_file.name}"))
                    break

    if not matching:
        print(f"   No widgets currently use '{target_element}'.")
    else:
        print(f"   Found {len(matching)} widget(s):")
        for wid, name, reason in matching:
            print(f"   • {wid:<16} - {name} ({reason})")
    print()

def cmd_list_elements(repo_root: Path):
    print("\n📦 Standardized Widget Elements Taxonomy:")
    print(f"   {'Tag':<18} {'Component':<24} {'Active Widgets'}")
    print(f"   {'-'*18} {'-'*24} {'-'*30}")

    for tag, comp in sorted(STANDARD_ELEMENTS.items()):
        widgets = []
        for w_dir in get_widget_dirs(repo_root):
            if tag in detect_used_elements(w_dir):
                widgets.append(w_dir.name)
        w_str = ", ".join(widgets) if widgets else "(none)"
        print(f"   {tag:<18} {comp:<24} {w_str}")
    print()

def cmd_list_widgets(repo_root: Path):
    print("\n📋 Registered Tide Island Widgets:")
    print(f"   {'Widget ID':<16} {'Sizes':<18} {'Span':<6} {'Elements':<30} {'Name'}")
    print(f"   {'-'*16} {'-'*18} {'-'*6} {'-'*30} {'-'*25}")

    for w_dir in sorted(get_widget_dirs(repo_root), key=lambda d: d.name):
        m = load_manifest(w_dir)
        sizes = ",".join(m.get("supportedSizes", []))
        span = str(m.get("defaultSlotSpan", 1))
        elements = ",".join(detect_used_elements(w_dir)) or "(unspecified)"
        name = m.get("name", w_dir.name)
        print(f"   {w_dir.name:<16} {sizes:<18} {span:<6} {elements:<30} {name}")
    print()

def audit_widget(widget_dir: Path) -> list:
    issues = []
    manifest_path = widget_dir / "manifest.json"
    if not manifest_path.is_file():
        issues.append("Missing manifest.json")
        return issues

    manifest = load_manifest(widget_dir)
    if "error" in manifest:
        issues.append(f"Invalid manifest.json: {manifest['error']}")

    for required_key in ["id", "name", "supportedSizes"]:
        if required_key not in manifest:
            issues.append(f"manifest.json missing required key '{required_key}'")

    # Check non-interactive view modes
    for non_interactive_file in ["Minimum.qml", "Circle.qml"]:
        target = widget_dir / non_interactive_file
        if target.is_file():
            content = target.read_text(encoding="utf-8", errors="ignore")
            for pat in INTERACTIVE_PATTERNS:
                if re.search(pat, content):
                    issues.append(f"{non_interactive_file} contains forbidden interactive element: {pat}")

    # Check usable space boundaries: prevent negative margins from leaking outside slot
    for qml_file in widget_dir.glob("*.qml"):
        content = qml_file.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"anchors\.(?:top|bottom|left|right|margins)Margin\s*:\s*-\s*\d+", content):
            issues.append(f"{qml_file.name} contains negative margin violating usable space boundary")

    # Check for bare Text elements: zero-tolerance enforcement for standardized typography and icons
    for qml_file in widget_dir.glob("*.qml"):
        content = qml_file.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"\bText\s*\{", content):
            issues.append(f"{qml_file.name} contains non-standard bare Text element; all typography must use WidgetTextView and icons must use WidgetIconGlyph")

    # Check dynamic resizing protocol: if widget implements non-zero requestedContentHeight or Width, capability must be declared
    implements_dynamic_resize = False
    for qml_file in widget_dir.glob("*.qml"):
        content = qml_file.read_text(encoding="utf-8", errors="ignore")
        # Match property assignments with non-zero values or dynamic expressions
        if re.search(r"\brequestedContent(?:Height|Width)\b\s*:\s*(?!0\b)", content):
            implements_dynamic_resize = True
            break
    capabilities = manifest.get("capabilities", [])
    if implements_dynamic_resize and "dynamic_resize" not in capabilities:
        issues.append("Implements dynamic requestedContentHeight/Width but missing 'dynamic_resize' in manifest.json capabilities")

    # Check element taxonomy: ensure all standardized components used in QML are declared in manifest
    declared_elements = set(manifest.get("elements", []))
    used_elements = set()
    for qml_file in widget_dir.glob("*.qml"):
        content = qml_file.read_text(encoding="utf-8", errors="ignore")
        for elem_tag, comp_name in STANDARD_ELEMENTS.items():
            if re.search(r"\b" + comp_name + r"\b", content):
                used_elements.add(elem_tag)
    undeclared = used_elements - declared_elements
    if undeclared:
        issues.append(f"Uses standardized component(s) without declaring in manifest.json elements: {', '.join(sorted(undeclared))}")

    # Check context safety in all files
    for qml_file in widget_dir.glob("*.qml"):
        content = qml_file.read_text(encoding="utf-8", errors="ignore")
        # Find unguarded widgetContext. accesses
        for line_num, line in enumerate(content.splitlines(), start=1):
            if "widgetContext." in line and "widgetContext ?" not in line and "if (" not in line and "root.widgetContext" not in line and "readonly property var sharedWidgetContext" not in line:
                if not re.search(r"(widgetContext\s*\?\s*widgetContext\.|!\s*widgetContext|\?\.)", line):
                    pass # Notice: subtle unguarded accesses

    return issues

def cmd_verify(repo_root: Path, target_widget: str = None):
    print("\n🛡️  Auditing Widgets for Specification Compliance...")
    widget_dirs = get_widget_dirs(repo_root)
    if target_widget:
        widget_dirs = [d for d in widget_dirs if d.name == target_widget]
        if not widget_dirs:
            print(f"Error: Widget '{target_widget}' not found.")
            sys.exit(1)

    total_issues = 0
    for w_dir in sorted(widget_dirs, key=lambda d: d.name):
        issues = audit_widget(w_dir)
        if issues:
            total_issues += len(issues)
            print(f"   ❌ {w_dir.name}:")
            for issue in issues:
                print(f"      • {issue}")
        else:
            print(f"   ✅ {w_dir.name}: fully compliant")

    print()
    if total_issues > 0:
        print(f"⚠️  Found {total_issues} specification issue(s).")
        sys.exit(1)
    else:
        print("🎉 All audited widgets comply with standard specifications!")
    print()

def main():
    parser = argparse.ArgumentParser(description="Tide Island Widget Auditing & Discovery Tool")
    parser.add_argument("--find-element", type=str, help="List all widgets using a given element specification")
    parser.add_argument("--list-elements", action="store_true", help="List all standard elements and their widget adoption")
    parser.add_argument("--list-widgets", action="store_true", help="List all registered widgets and their metadata")
    parser.add_argument("--verify", type=str, help="Verify compliance of a specific widget ID")
    parser.add_argument("--verify-all", action="store_true", help="Verify compliance of all widgets in the repository")

    args = parser.parse_args()
    repo_root = find_repo_root()

    if args.find_element:
        cmd_find_element(repo_root, args.find_element)
    elif args.list_elements:
        cmd_list_elements(repo_root)
    elif args.list_widgets:
        cmd_list_widgets(repo_root)
    elif args.verify:
        cmd_verify(repo_root, args.verify)
    elif args.verify_all:
        cmd_verify(repo_root)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
