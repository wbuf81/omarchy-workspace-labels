# Workspace Labels 3.2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the widget into focused files, make previews reliable with a private "map" mode, add auto icons, urgent state, middle-click send, per-monitor IPC, a two-step reset, and give the bar and preview the station-board character the panels already have.

**Architecture:** `Workspaces.qml` stays the single manifest entry point and keeps settings plumbing, the workspace/label/pin model, and IPC. Everything visual moves into sibling QML files in the plugin root (same-directory implicit import, no qmldir). Every rule that can be expressed without Qt lives in `Logic.js` and is exercised by `tests/logic.test.js` under Node. Child components receive the root as `required property var host` and read model state and palette from it.

**Tech Stack:** QML / Quickshell 0.3.1 on Omarchy 4.0.3 (`qs.Ui`, `qs.Commons`), Quickshell.Hyprland, Quickshell.Wayland (ScreencopyView), Quickshell.Io (FileView), Node for tests, bash for release checks.

**Spec:** The approved proposal in the 2026-09-16 session (recorded in `MAINTAINER_NOTES.md` under "Design language" and the 3.2.0 changelog entry written in Task 15).

## Global Constraints

- Plugin id `io.github.wbuf81.workspace-labels`; version `3.2.0` in `manifest.json` and `scripts/static-check.sh` together.
- No Qt APIs in `Logic.js`. Every new rule there gets a test first.
- Never read `bar.shell.appLibrary` (null on 4.0.3). Icons come from `DesktopEntries` + `Quickshell.iconPath`.
- Honor `Style.cornerRadius` as-is. Uppercase letter-spaced captions, hairline rules, `Color.accent` only for focus/live/selected, `Color.urgent` only for urgent.
- Hyprland 0.56 Lua dispatch: `hl.dsp.focus({ workspace = "N" })`, `hl.dsp.window.move({ workspace = "N", follow = false })`.
- Source edits need `./scripts/dev-sync.sh` then `omarchy restart shell` (wait 4 s between). Verify each visual task with `grim -g "0,0 WxH" file.png` and view the image.
- Run `./scripts/static-check.sh < /dev/null` before every commit; `./scripts/release-check.sh < /dev/null` before tagging.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Workspaces.qml` (modify, shrink to ~650 lines) | Root `Panel`: settings plumbing, labels/pins/auto-icon model, desktop entries, urgent tracking, preview state, IPC, bar row + `FocusBar`. Exposes palette + `pad()` for children. |
| `Caption.qml` (create) | Uppercase letter-spaced dim `Text`. |
| `Rule.qml` (create) | 1 px hairline `Rectangle`. |
| `Mark.qml` (create) | 6 px accent square with steps(1) blink. |
| `BlockCursor.qml` (create) | Blinking `█` glyph, same cadence as `Mark`. |
| `CornerFrame.qml` (create) | Four L-shaped accent corners around a rectangle (OmaFinance). |
| `BarButton.qml` (create) | One workspace button: icon/name, urgent color, left/middle/right press, wheel, hover. |
| `WindowTile.qml` (create) | One window in the preview: capture with fallback, or map block with icon badge. |
| `PreviewCard.qml` (create) | Hover card: header, screen well with grid/ticks/corners, footer. |
| `EditorPanel.qml` (create) | `KeyboardPanel` with station row, rows, footer, two-step reset; hosts `IconPicker`. |
| `IconPicker.qml` (create) | Search field, ON THIS WORKSPACE / GLYPHS / APPS sections, glyph footer. |
| `FlipBoard.qml`, `FlipStep.qml` (create, copied from idle counter, MIT) | Stepped flip tiles for the header readout and row counts. |
| `Logic.js` (modify) | New pure rules: preview mode, dominant class, auto icon, display label, urgent set bookkeeping, focus geometry. |
| `tests/logic.test.js` (modify) | Tests for every new rule. |
| `scripts/dev-sync.sh` (modify) | `--restart` flag. |
| `scripts/static-check.sh` (modify) | Version 3.2.0, new file list, new contracts, optional qmllint. |
| `manifest.json` (modify) | Version, `previewMode` + `autoIcons` schema entries. |
| `README.md`, `CHANGELOG.md`, `MAINTAINER_NOTES.md`, `docs/*.png`, `preview.png` (modify) | Release docs and screenshots. |

---

### Task 1: Pure rules in Logic.js (tests first)

**Files:**
- Modify: `Logic.js`
- Test: `tests/logic.test.js`

**Interfaces (Produces):**
- `previewMode(modeValue, legacyHoverPreview)` → `"capture" | "map" | "off"`. Valid `modeValue` wins; otherwise `legacyHoverPreview === false` → `"off"`, else `"capture"`.
- `dominantClass(classes)` → most frequent non-empty class, ties by first appearance, `""` when none.
- `autoIconFor(classes, entries)` → `"app:<icon>"` for the dominant class via `appsForClasses`, falling back to any matching class, else `""`.
- `displayLabel(label, autoIcon, id, autoEnabled)` → `{icon, name, auto}`; fills `icon` from `autoIcon` when the stored icon is `""` and `autoEnabled`; when both fields end up empty, `name` becomes `String(id)`. `auto` is true only when the auto icon was used.
- `urgentAfter(set, eventName, address, focusedAddresses)` → new sorted array of urgent addresses: adds on `"urgent"`, removes the address on `"activewindowv2"`/`"focusedmon"`/`"closewindow"` events for that address, and removes every address listed in `focusedAddresses`.
- `focusGeometry(items, focusedId, vertical, thickness)` → `{x, y, width, height, visible}` for the sliding bar given `items = [{id, x, y, width, height}]`.

- [ ] **Step 1: Append failing tests** to `tests/logic.test.js` before the final `console.log`:

```js
// Preview mode: the new tri-state setting wins; the legacy boolean maps to off/capture.
assert.equal(Logic.previewMode("map", true), "map")
assert.equal(Logic.previewMode("off", true), "off")
assert.equal(Logic.previewMode("capture", false), "capture")
assert.equal(Logic.previewMode(undefined, false), "off")
assert.equal(Logic.previewMode("bogus", undefined), "capture")

// Dominant class: most frequent wins, ties go to first seen, blanks ignored.
assert.equal(Logic.dominantClass(["a", "b", "b", "", "a", "b"]), "b")
assert.equal(Logic.dominantClass(["x", "y"]), "x")
assert.equal(Logic.dominantClass([]), "")
assert.equal(Logic.dominantClass(null), "")

// Auto icon: an unlabeled workspace borrows its dominant app's icon.
assert.equal(Logic.autoIconFor(["brave-browser", "Alacritty", "brave-browser"], apps), "app:brave-desktop")
assert.equal(Logic.autoIconFor(["unknown", "Alacritty"], apps), "app:Alacritty")
assert.equal(Logic.autoIconFor(["unknown"], apps), "")
assert.equal(Logic.autoIconFor([], apps), "")

// Display label: auto icon fills an empty icon only when enabled; empty/empty shows the number.
assert.deepEqual(Logic.displayLabel({icon: "", name: "Web"}, "app:x", 3, true), {icon: "app:x", name: "Web", auto: true})
assert.deepEqual(Logic.displayLabel({icon: "", name: "Web"}, "app:x", 3, false), {icon: "", name: "Web", auto: false})
assert.deepEqual(Logic.displayLabel({icon: "", name: ""}, "app:x", 3, true), {icon: "", name: "", auto: false})
assert.deepEqual(Logic.displayLabel({icon: "", name: ""}, "", 7, true), {icon: "", name: "7", auto: false})
assert.deepEqual(Logic.displayLabel({icon: "", name: ""}, "app:x", 7, true), {icon: "app:x", name: "", auto: true})

// Urgent bookkeeping from Hyprland raw events.
assert.deepEqual(Logic.urgentAfter([], "urgent", "0xb", []), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xb"], "urgent", "0xa", []), ["0xa", "0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "activewindowv2", "0xb", []), ["0xa"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "closewindow", "0xa", []), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "tick", "", ["0xa"]), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa"], "urgent", "", []), ["0xa"])

// Sliding focus bar geometry.
const items = [{id: 1, x: 0, y: 0, width: 40, height: 30}, {id: 2, x: 42, y: 0, width: 60, height: 30}]
assert.deepEqual(Logic.focusGeometry(items, 2, false, 2), {x: 42, y: 28, width: 60, height: 2, visible: true})
assert.deepEqual(Logic.focusGeometry(items, 1, true, 2), {x: 38, y: 0, width: 2, height: 30, visible: true})
assert.equal(Logic.focusGeometry(items, 9, false, 2).visible, false)
```

- [ ] **Step 2: Run** `node tests/logic.test.js` → FAIL `Logic.previewMode is not a function`.
- [ ] **Step 3: Implement** the six functions in `Logic.js` above the `module.exports` block and export them.
- [ ] **Step 4: Run** `node tests/logic.test.js` → `workspace add/remove logic tests passed`.
- [ ] **Step 5: Commit** `feat(logic): preview mode, auto icons, urgent set, focus geometry`.

---

### Task 2: Shared station pieces

**Files:**
- Create: `Caption.qml`, `Rule.qml`, `Mark.qml`, `BlockCursor.qml`, `CornerFrame.qml`

**Interfaces (Produces):**
- `Caption`: `Text` with `textFormat: PlainText`, `color: Util.alpha(Color.popups.text, 0.55)`, `font.family: Style.font.family`, `font.pixelSize: Style.font.caption`, `letterSpacing 1.4`, `AllUppercase`, `ElideRight`.
- `Rule`: `Rectangle { width: parent ? parent.width : 0; height: 1; color: Util.alpha(Color.popups.text, 0.14) }`.
- `Mark`: `Rectangle { property bool blinking; width: Style.space(6); height: width; color: Color.accent }` with the steps(1) 550 ms opacity loop; opacity resets to 1 when blinking stops.
- `BlockCursor`: `Text { text: "█"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }` with the same loop, `property bool blinking: true`.
- `CornerFrame`: `Item { property color color: Color.accent; property int arm: Style.space(8); property int thickness: 1 }` painting four L corners with eight thin Rectangles anchored to its own edges.

- [ ] **Step 1: Create the five files** with the exact properties above; each imports `QtQuick` and `qs.Commons`.
- [ ] **Step 2: Parse** `for f in Caption Rule Mark BlockCursor CornerFrame; do /usr/lib/qt6/bin/qmlformat -n $f.qml; done` → no output.
- [ ] **Step 3: Commit** `refactor: shared station components`.

---

### Task 3: Split the editor and picker out of Workspaces.qml

**Files:**
- Create: `EditorPanel.qml`, `IconPicker.qml`
- Modify: `Workspaces.qml` (remove the `KeyboardPanel` block; instantiate `EditorPanel { host: root; anchorItem: grid }`)

**Interfaces:**
- Consumes from host: `opened`, `showPicker`, `pickerFor`, `editorTarget`, `editableIds()`, `labelFor(id)`, `displayFor(id)`, `toplevelsForWorkspace(id)`, `isAppIcon`, `appIconName`, `appIconSource`, `filteredIcons`, `filteredApps`, `workspaceApps`, `iconQuery`, `canAdd`, `nextFreeId()`, `maxWorkspace`, `liveCount`, `pad()`, `openPicker`, `closePicker`, `chooseIcon`, `setName`, `removeWorkspace`, `addWorkspace`, `resetLabels`, `escapeFrom`, `noteFieldFocus`, `focusedFields`, `autoFocusTarget`, `moveTarget`, `editTarget`, `switchPanel`, `close`, `controller`, `bar`, `ink/dim/faint/line/well`.
- Produces: `EditorPanel { required property var host; property alias anchorItem; readonly property Item keyCatcher }` and `IconPicker { required property var host; property Item keyCatcher }` (same-directory types, no import needed).

- [ ] **Step 1: Move** the current `KeyboardPanel { ... }` block verbatim into `EditorPanel.qml` as the root object; replace every `root.` with `host.` except `root.controller`, which becomes `host.controller`. Add `required property var host` and `property alias anchorItem: panel.anchorItem` is not possible on the root itself; instead make the root `KeyboardPanel` and expose `host` only (anchorItem is set by the caller).
- [ ] **Step 2: Cut** the `// ---------- icon picker ----------` Column out of `EditorPanel.qml` into `IconPicker.qml` (root `Column`, `required property var host`, `property Item keyCatcher`), replace inline `Caption`/`Rule` usage with the new files, and instantiate `IconPicker { host: panel.host; keyCatcher: keyCatcher; width: parent.width; visible: host.showPicker }` where it was.
- [ ] **Step 3: In `Workspaces.qml`** delete the moved block, the inline `component Caption/Rule/Mark` declarations, and instantiate `EditorPanel { id: panel; host: root; anchorItem: grid; owner: root; bar: root.bar; open: root.opened }`. `focusTarget` binds inside `EditorPanel` to its own key catcher.
- [ ] **Step 4: Parse** all three files with qmlformat, then `./scripts/dev-sync.sh`, wait 4 s, `omarchy restart shell`, wait 8 s, `omarchy-shell io.github.wbuf81.workspace-labels openFor 2`, `grim -g "0,0 608x520" /tmp/.../split-editor.png`, then `picker 2`, capture, `close`. Confirm the editor and picker look identical to the 3.1.1 screenshots and the log has no `Workspaces.qml|EditorPanel.qml|IconPicker.qml` warnings.
- [ ] **Step 5: Commit** `refactor: EditorPanel and IconPicker as their own files`.

---

### Task 4: Split the preview card and bar button

**Files:**
- Create: `PreviewCard.qml`, `WindowTile.qml`, `BarButton.qml`
- Modify: `Workspaces.qml`

**Interfaces:**
- `PreviewCard { required property var host }` is a `PopupCard`; reads `host.hoverAnchor`, `host.grid` (expose `readonly property alias grid: grid` on root), `host.hoverPreviewId`, `host.previewMonitor`, `host.previewWindows`, `host.previewBoxWidth/Height`, `host.displayFor`, `host.pad`, `host.previewMode`, `host.appIconSource`, `host.iconForClass(cls)`; `owner` is `host.hoverOwner` (expose `readonly property alias hoverOwner: hoverOwner`).
- `WindowTile { required property var host; required property var win; required property real sx; required property real originX; required property real originY; required property string mode }` paints one window (Task 6 fills in fallback/map; this task moves the current Rectangle + ScreencopyView).
- `BarButton { required property var host; required property int workspaceId }` is a `WidgetButton`; produces `readonly property bool focused`, `readonly property bool occupied`, `readonly property bool urgent` (false until Task 8).

- [ ] **Step 1: Move** the `PopupCard { id: hoverCard ... }` block into `PreviewCard.qml` with `root.` → `host.`; move the window `Rectangle` delegate into `WindowTile.qml`.
- [ ] **Step 2: Move** the workspace `WidgetButton` delegate into `BarButton.qml` (`modelData` → `workspaceId`; `root.` → `host.`).
- [ ] **Step 3: In `Workspaces.qml`** instantiate `PreviewCard { host: root }` and use `BarButton { host: root; workspaceId: modelData }` in the Repeater.
- [ ] **Step 4: Sync, restart, verify** bar (`grim -g "0,0 545x30"`), `preview 3` capture, and log silence.
- [ ] **Step 5: Commit** `refactor: PreviewCard, WindowTile, BarButton as their own files`.

---

### Task 5: Preview modes setting

**Files:**
- Modify: `manifest.json` (schema + defaults), `Workspaces.qml`, `README.md`

**Interfaces (Produces):** `readonly property string previewMode: Logic.previewMode(root.effSetting("previewMode", undefined), root.effSetting("hoverPreview", true))` on host; `requestPreview` returns early when `previewMode === "off"`.

- [ ] **Step 1: Manifest**: add default `"previewMode": "capture"` and a schema entry `{ "key": "previewMode", "type": "string", "label": "Hover preview", "description": "capture shows window screenshots; map draws windows as blocks with their app icons and never shows screen content; off disables the preview. The older boolean hoverPreview still turns it off.", "defaultValue": "capture", "options": ["capture", "map", "off"] }` (keep `hoverPreview` entry, mark it legacy in its description).
- [ ] **Step 2: Host**: replace `hoverPreviewEnabled` with `previewMode`; `requestPreview` checks `previewMode !== "off"`.
- [ ] **Step 3: README**: settings table row for `previewMode`; `hoverPreview` marked legacy.
- [ ] **Step 4: Sync/restart**; `omarchy bar set io.github.wbuf81.workspace-labels previewMode off`, hover via `preview 3` → no card; set back to `capture` → card. Commit `feat: previewMode setting (capture | map | off)`.

---

### Task 6: WindowTile fallback and map mode, icon badges

**Files:**
- Modify: `WindowTile.qml`, `Workspaces.qml` (add `iconForClass`)

**Interfaces:**
- Host produces `function iconForClass(cls)` → `Logic.appsForClasses(root.desktopEntries, [cls])[0]?.icon || ""` and `previewWindows[i].cls` (add `cls: String(o["class"] || "")` and `title` to each entry).
- `WindowTile` shows: in `capture` mode a `ScreencopyView` (`live: false`) and, when `shot.hasContent === false` after 600 ms or the source is null, the map block; in `map` mode the block always. The block is `color: Util.alpha(Color.popups.text, 0.06)`, hairline border, an app icon badge (`Image`, `Style.space(16)`, centered, via `host.appIconSource(host.iconForClass(win.cls))`), and a `Caption` with the class below when the tile is taller than `Style.space(40)`. Both modes draw a 12 px icon badge in the top-left corner when the tile is at least 32 px wide.

- [ ] **Step 1: Implement** the tile per the interface. Use `readonly property bool captured: mode === "capture" && shot.captureSource !== null && shot.hasContent` and a `Timer { interval: 600; running: mode === "capture"; onTriggered: tile.settled = true }` so the fallback appears only after the capture had its chance (`visible: !captured && (mode !== "capture" || settled)`).
- [ ] **Step 2: Sync/restart**; capture `preview 3` in `capture` mode (thumbnails + badges) and in `map` mode (blocks + icons). Commit `feat: map preview mode and capture fallback with app icon badges`.

---

### Task 7: Instrument-console preview chrome

**Files:**
- Modify: `PreviewCard.qml`

- [ ] **Step 1: Grid**: inside the screen well add `Repeater { model: 7 }` vertical hairlines at `x = width * (index + 1) / 8` and `Repeater { model: 3 }` horizontal at `y = height * (index + 1) / 4`, `color: Util.alpha(host.ink, 0.05)`, below the tiles.
- [ ] **Step 2: Ticks**: four 4 px accent ticks at the midpoints of each edge (`Util.alpha(Color.accent, 0.6)`).
- [ ] **Step 3: Corners**: `CornerFrame { anchors.fill: screenRect; anchors.margins: -1; color: Util.alpha(Color.accent, 0.7) }` above the tiles.
- [ ] **Step 4: Header**: after the title `Caption`, append the focused marker `Caption { text: host.hoverPreviewId === (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0) ? "· now" : "" }`.
- [ ] **Step 5: Sync/restart**, capture `preview 3`, confirm grid, ticks, corners render without covering thumbnails. Commit `style: instrument-console preview chrome`.

---

### Task 8: Urgent state and middle-click send

**Files:**
- Modify: `Workspaces.qml`, `BarButton.qml`, `README.md`

**Interfaces (Produces):** host `property var urgentAddresses: []`, `function isUrgent(id)` → any toplevel on the workspace whose `address` (from `lastIpcObject.address`, normalized without `0x` prefix, lowercase) is in the set; `function sendFocusedWindow(id)` runs `hl.dsp.window.move({ workspace = "<id>", follow = false })` via `bar.run`.

- [ ] **Step 1: Host**: `Connections { target: Hyprland; function onRawEvent(event) { root.urgentAddresses = Logic.urgentAfter(root.urgentAddresses, event.name, root.normalizedAddress(event.data.split(",")[0]), root.focusedAddresses()) } }` where `normalizedAddress` strips `0x` and lowercases, and `focusedAddresses()` returns the addresses of toplevels on `Hyprland.focusedWorkspace`.
- [ ] **Step 2: BarButton**: `readonly property bool urgent: host.isUrgent(workspaceId)`; icon and name `color: urgent ? host.bar.urgent : foreground`; `opacity: occupied || focused || urgent ? 1 : 0.5`; `onPressed`: `Qt.MiddleButton` → `host.sendFocusedWindow(workspaceId)`, `Qt.RightButton` → editor, else focus.
- [ ] **Step 3: README**: controls table: middle-click sends the focused window; urgent windows color their workspace.
- [ ] **Step 4: Verify**: focus workspace 2, `omarchy-shell ... ` is not needed; run `hyprctl dispatch 'hl.dsp.window.move({ workspace = "5", follow = false })'` manually to confirm syntax, then via middle click is not scriptable, so test `host.sendFocusedWindow` through a temporary IPC verb `send` (keep it: `function send(id: string)`). Urgent: `notify-send` cannot raise urgency; confirm no errors from the rawEvent handler in the log and unit tests cover the set logic. Commit `feat: urgent workspaces and middle-click send`.

---

### Task 9: Auto icons for unlabeled workspaces

**Files:**
- Modify: `manifest.json`, `Workspaces.qml`, `BarButton.qml`, `EditorPanel.qml`, `README.md`

**Interfaces (Produces):** host `readonly property bool autoIcons: root.effSetting("autoIcons", true) !== false`, `function autoIconFor(id)` → `Logic.autoIconFor(classesOn(id), root.desktopEntries)`, and `displayFor(id)` now returns `Logic.displayLabel(root.labelFor(id), root.autoIconFor(id), id, root.autoIcons)`.

- [ ] **Step 1: Manifest**: default `"autoIcons": true`, schema boolean "Auto icons: a workspace without an icon shows the icon of the app running on it".
- [ ] **Step 2: Host**: implement `classesOn(id)` (unique classes of `toplevelsForWorkspace(id)`), `autoIconFor`, and route `displayFor` through `Logic.displayLabel`.
- [ ] **Step 3: EditorPanel**: the row icon button shows the auto icon at `opacity: 0.55` when `displayFor(id).auto` and its tooltip says "Auto icon from <class> · click to choose".
- [ ] **Step 4: Verify**: `omarchy bar set ... labels '{"3":{"icon":"","name":"Web"}}' --json` → bar shows Brave's icon on workspace 3 (Brave runs there); set `autoIcons false` → glyph gone. Commit `feat: auto icons for unlabeled workspaces`.

---

### Task 10: Sliding focus bar

**Files:**
- Modify: `Workspaces.qml`, `BarButton.qml`

- [ ] **Step 1: BarButton**: remove `font.underline`.
- [ ] **Step 2: Host**: after the `GridLayout`, add `Rectangle { id: focusBar; color: Color.accent; readonly property var geo: Logic.focusGeometry(root.buttonGeometry(), Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0, root.vertical, Style.space(2)); x: geo.x; y: geo.y; width: geo.width; height: geo.height; visible: geo.visible; Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } Behavior on width { ... } Behavior on y { ... } Behavior on height { ... } }` where `buttonGeometry()` maps the Repeater's items to `{id, x, y, width, height}` (depend on `grid.width` and each item's geometry via a `Repeater.onItemAdded` counter property `layoutRevision` to re-evaluate).
- [ ] **Step 3: Verify**: `hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'`, capture bar twice 100 ms apart to see motion, then final. Commit `style: sliding accent focus bar`.

---

### Task 11: Block cursor and flip readouts

**Files:**
- Create: `FlipBoard.qml`, `FlipStep.qml` (copied from `~/Projects/omarchy-idle-screencounter`, keep MIT headers)
- Modify: `EditorPanel.qml`, `LICENSE` (add "FlipBoard.qml and FlipStep.qml © 2026 Wes, from Idle Screen Counter, MIT")

- [ ] **Step 1: Copy** the two files; in `FlipBoard.qml` reduce `styleFiles` to `{ step: "FlipStep.qml" }` and default `style: "step"`.
- [ ] **Step 2: Station row**: after the title `Text`, add `BlockCursor { anchors.verticalCenter: parent.verticalCenter; blinking: host.opened }`.
- [ ] **Step 3: Readout**: replace the "NOW 04 X" caption's number with `FlipBoard { value: host.pad(focusedId); tileWidth: Style.space(12); tileHeight: Style.space(16); gap: 2; foreground: host.ink; accent: Color.accent; dim: host.dim; line: host.line; well: host.well; fontFamily: Style.font.family; animated: host.opened }` beside the `NOW` caption and name caption.
- [ ] **Step 4: Row counts**: the per-row window count becomes `FlipBoard { value: host.pad(windows) }` (same tile size) followed by a `Caption { text: windows === 1 ? "window" : "windows" }`; `EMPTY` stays a caption.
- [ ] **Step 5: Verify**: open editor, `hyprctl dispatch 'hl.dsp.focus({ workspace = "1" })'` while open, capture mid-flip and settled. Commit `style: block cursor and stepped flip readouts`.

---

### Task 12: Two-step reset and `/` search

**Files:**
- Modify: `EditorPanel.qml`

- [ ] **Step 1: Reset**: `property bool confirmingReset: false; Timer { id: resetArm; interval: 3000; onTriggered: panel.confirmingReset = false }`. Button text `confirmingReset ? "SURE?" : "RESET"`, `accent: confirmingReset ? Color.urgent : Color.accent`, `selected: confirmingReset`; `onClicked: if (confirmingReset) { host.resetLabels(); confirmingReset = false } else { confirmingReset = true; resetArm.restart() }`. Reset `confirmingReset` on `host.onOpenedChanged`.
- [ ] **Step 2: Search key**: in the key catcher `onTextKey`, `if (t === "/" && host.editorTarget > 0) host.openPicker(host.editorTarget)`; footer hint becomes `"j/k move  ·  enter rename  ·  i or / icon\na add  ·  x remove  ·  esc close"`.
- [ ] **Step 3: Verify** by clicking RESET once via IPC is impossible; instead expose nothing new and verify visually: open editor, capture, and confirm the button label. Commit `feat: two-step reset and / to search icons`.

---

### Task 13: Per-monitor IPC and unresolvable icons

**Files:**
- Modify: `Workspaces.qml`

- [ ] **Step 1: Instance routing**: `function instanceOnFocusedMonitor() { var mon = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : ""; var items = root.bar && typeof root.bar.moduleWidgets === "function" ? root.bar.moduleWidgets(root.moduleName) : [root]; for (var i = 0; i < items.length; i++) { var w = items[i] && items[i].grid ? items[i].grid.QsWindow.window : null; if (w && w.screen && String(w.screen.name) === mon) return items[i] } return root }`. Every IPC verb calls the method on `instanceOnFocusedMonitor()` instead of `root`.
- [ ] **Step 2: Icons**: `appEntries(query)` filters rows where `Quickshell.iconPath(row.icon, true) === "" && row.icon.charAt(0) !== "/"`.
- [ ] **Step 3: Verify**: `hyprctl output create headless`, focus it, `openFor 2` → editor on the headless output (`grim -o HEADLESS-N`), remove the output. Picker no longer shows generic fallback tiles. Commit `feat: IPC targets the focused monitor; hide unresolvable app icons`.

---

### Task 14: Tooling

**Files:**
- Modify: `scripts/dev-sync.sh`, `scripts/static-check.sh`

- [ ] **Step 1: dev-sync** accepts `--restart`: after rescan, `sleep 4; omarchy restart shell`.
- [ ] **Step 2: static-check**: version `3.2.0`; required files include every new QML file; contracts `rg -q 'Logic\.previewMode'`, `rg -q 'Logic\.displayLabel'`, `rg -q 'Logic\.urgentAfter'`, `rg -q 'Logic\.focusGeometry'`; qmlformat loop over `*.qml`; try `qmllint --qml-import-path /usr/lib/qt6/qml -I /usr/share/omarchy/shell *.qml`, and keep it only if it exits 0 on a clean tree (otherwise leave a comment explaining why it is omitted).
- [ ] **Step 3: Run** `./scripts/static-check.sh < /dev/null` → passes. Commit `chore: dev-sync --restart, static checks for 3.2.0`.

---

### Task 15: Release 3.2.0

**Files:**
- Modify: `manifest.json`, `CHANGELOG.md`, `README.md`, `MAINTAINER_NOTES.md`, `scripts/build-social-card.sh`, `docs/bar.png`, `docs/editor.png`, `docs/picker.png`, `docs/preview.png`, `docs/social-preview.png`, `preview.png`

- [ ] **Step 1: CHANGELOG** `## 3.2.0` covering Tasks 3–13 in user terms.
- [ ] **Step 2: README**: file table lists the new files; controls table (middle-click); settings table (`previewMode`, `autoIcons`); "Why it feels native" mentions auto icons, urgent color, sliding focus bar, map mode privacy.
- [ ] **Step 3: MAINTAINER_NOTES**: current state 3.2.0; file map; the host/child contract; verification status.
- [ ] **Step 4: Screenshots**: with the shell running, capture `docs/bar.png` (545×30), `docs/editor.png` (608×520), `docs/picker.png` (628×640), `docs/preview.png` (608×300, capture mode). Social card version text `v3.2.0`; run `./scripts/build-social-card.sh`; `cp docs/social-preview.png preview.png`.
- [ ] **Step 5:** `./scripts/release-check.sh < /dev/null` → passes. Commit `Release v3.2.0`, tag `v3.2.0`, push, `gh release create v3.2.0 --latest`, confirm the Actions run is green.
