const assert = require("node:assert/strict")
const Logic = require("../Logic.js")

// Legacy minWorkspaces migrates to a predictable 1..N pinned list.
assert.deepEqual(Logic.normalizedPinned(null, 5, 20), [1, 2, 3, 4, 5])
assert.deepEqual(Logic.normalizedPinned(undefined, -4, 20), [])
assert.deepEqual(Logic.normalizedPinned(undefined, 99, 20), Array.from({length: 20}, (_, i) => i + 1))

// User-edited JSON cannot introduce duplicates, fractions, garbage, or slots
// beyond the supported empty-workspace range.
assert.deepEqual(
  Logic.normalizedPinned([5, "2", 2, 0, -1, 21, 3.5, "oops"], 5, 20),
  [2, 5]
)

// Visible workspaces are the union of compositor state, the just-focused
// workspace, and pinned empty slots. Real Hyprland IDs remain unbounded.
assert.deepEqual(Logic.visibleWorkspaceIds([8, 2, 2, 37], 6, [1, 2, 5]), [1, 2, 5, 6, 8, 37])
assert.deepEqual(Logic.visibleWorkspaceIds([], 0, []), [])

// Saved labels keep an editor row alive after an empty workspace disappears,
// but malformed high-numbered labels cannot flood the panel. A real workspace
// above the creation cap is still editable.
assert.deepEqual(
  Logic.editableWorkspaceIds([1, 37], {"2": {}, "20": {}, "21": {}, nope: {}}, 20),
  [1, 2, 20, 37]
)

// Add always chooses the lowest free slot and keeps pin order stable.
assert.equal(Logic.nextFreeId([1, 2, 4, 7], 20), 3)
assert.equal(Logic.nextFreeId(Array.from({length: 20}, (_, i) => i + 1), 20), 0)
assert.deepEqual(
  Logic.addedWorkspaceState([1, 2, 4], [4, 1], 20),
  {id: 3, pinned: [1, 3, 4]}
)
assert.deepEqual(
  Logic.addedWorkspaceState(Array.from({length: 20}, (_, i) => i + 1), [1, 2], 20),
  {id: 0, pinned: [1, 2]}
)

// Rapid adds use the newly staged pinned state. This mirrors two clicks before
// shell.json has round-tripped back through the bar.
const firstAdd = Logic.addedWorkspaceState([1, 2], [1, 2], 20)
const secondAdd = Logic.addedWorkspaceState(
  Logic.visibleWorkspaceIds([1, 2], 0, firstAdd.pinned),
  firstAdd.pinned,
  20
)
assert.deepEqual(firstAdd, {id: 3, pinned: [1, 2, 3]})
assert.deepEqual(secondAdd, {id: 4, pinned: [1, 2, 3, 4]})

// A slot freed by removal is immediately the next one added.
const afterGapRemoval = Logic.removedWorkspaceState(
  2, true, false, [1, 2, 3], {"1": {}, "2": {}, "3": {}}, 20
)
assert.deepEqual(
  Logic.addedWorkspaceState(
    Logic.visibleWorkspaceIds([], 0, afterGapRemoval.pinned),
    afterGapRemoval.pinned,
    20
  ),
  {id: 2, pinned: [1, 2, 3]}
)

const labels = {
  "1": {icon: "terminal", name: "Code"},
  "2": {icon: "web", name: "Web"},
  "3": {icon: "mail", name: "Mail"}
}

// Removing an empty slot unpins it and forgets only its own label.
assert.deepEqual(
  Logic.removedWorkspaceState(2, true, false, [1, 2, 3], labels, 20),
  {
    removed: true,
    pinned: [1, 3],
    labels: {
      "1": {icon: "terminal", name: "Code"},
      "3": {icon: "mail", name: "Mail"}
    }
  }
)

// Occupied workspaces are protected: neither pin nor label state changes.
assert.deepEqual(
  Logic.removedWorkspaceState(2, true, true, [1, 2, 3], labels, 20),
  {removed: false, pinned: [1, 2, 3], labels}
)

// An unpinned, empty row with a saved label can still be removed cleanly.
assert.deepEqual(
  Logic.removedWorkspaceState(3, true, false, [1, 2], labels, 20),
  {
    removed: true,
    pinned: [1, 2],
    labels: {
      "1": {icon: "terminal", name: "Code"},
      "2": {icon: "web", name: "Web"}
    }
  }
)

// Invalid or non-editable removal requests are inert.
for (const id of [0, -1, 2.5, "oops"]) {
  const state = Logic.removedWorkspaceState(id, true, false, [1, 2, 3], labels, 20)
  assert.equal(state.removed, false)
  assert.deepEqual(state.pinned, [1, 2, 3])
  assert.deepEqual(state.labels, labels)
}
assert.equal(
  Logic.removedWorkspaceState(21, false, false, [1, 2, 3], labels, 20).removed,
  false
)

// A real editable workspace above the empty-slot creation cap can still have
// its saved label removed.
assert.deepEqual(
  Logic.removedWorkspaceState(
    37, true, false, [1, 2], Object.assign({}, labels, {"37": {icon: "", name: "Lab"}}), 20),
  {removed: true, pinned: [1, 2], labels}
)

// Two removals before a settings round-trip preserve the first transition.
const firstRemove = Logic.removedWorkspaceState(2, true, false, [1, 2, 3], labels, 20)
const secondRemove = Logic.removedWorkspaceState(
  3, true, false, firstRemove.pinned, firstRemove.labels, 20
)
assert.deepEqual(secondRemove, {
  removed: true,
  pinned: [1],
  labels: {"1": {icon: "terminal", name: "Code"}}
})

// Empty custom rows are dead state, while an empty built-in row intentionally
// overrides its default label and must remain stored.
assert.deepEqual(
  Logic.prunedLabels(
    {"1": {icon: "", name: ""}, "6": {icon: "", name: ""}, "7": {icon: "", name: "Notes"}},
    {"1": {icon: "code", name: "Code"}}
  ),
  {"1": {icon: "", name: ""}, "7": {icon: "", name: "Notes"}}
)

// Helpers return fresh state; a caller cannot mutate the original settings by
// editing a result object after an add/remove operation.
const originalPinned = [1, 2, 3]
const removed = Logic.removedWorkspaceState(2, true, false, originalPinned, labels, 20)
removed.pinned.push(9)
removed.labels["1"].name = "Changed"
assert.deepEqual(originalPinned, [1, 2, 3])
assert.equal(labels["1"].name, "Code")

// Desktop entries come straight from Quickshell now; the shell's AppLibrary is
// withheld from bar-widget plugins on Omarchy 4.0.3. Only visible entries that
// declare an icon are offered, matched by name, sorted case-insensitively.
const apps = [
  {id: "brave-browser", name: "Brave", icon: "brave-desktop", startupClass: "brave-browser", noDisplay: false},
  {id: "hidden", name: "Hidden", icon: "x", startupClass: "", noDisplay: true},
  {id: "noicon", name: "No icon", icon: "", startupClass: "", noDisplay: false},
  {id: "Alacritty", name: "alacritty", icon: "Alacritty", startupClass: "", noDisplay: false},
  {id: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus", startupClass: "", noDisplay: false}
]
assert.deepEqual(Logic.appEntryRows(apps, ""), [
  {id: "Alacritty", icon: "Alacritty", name: "alacritty", wmClass: ""},
  {id: "brave-browser", icon: "brave-desktop", name: "Brave", wmClass: "brave-browser"},
  {id: "org.gnome.Nautilus", icon: "org.gnome.Nautilus", name: "Files", wmClass: ""}
])
assert.deepEqual(Logic.appEntryRows(apps, "BRA"), [
  {id: "brave-browser", icon: "brave-desktop", name: "Brave", wmClass: "brave-browser"}
])
assert.deepEqual(Logic.appEntryRows(null, "x"), [])
assert.deepEqual(Logic.appEntryRows([{name: "Broken"}], ""), [])

// A running window's class finds its app through StartupWMClass first, then
// the desktop id, then the app name. Brave's class is brave-browser while its
// icon is brave-desktop, so a naive class -> icon lookup would fail. Matches
// are case-insensitive and deduplicated by icon.
assert.deepEqual(Logic.appsForClasses(apps, ["BRAVE-BROWSER", "brave-browser", "unknown"]), [
  {id: "brave-browser", icon: "brave-desktop", name: "Brave", wmClass: "brave-browser"}
])
assert.deepEqual(Logic.appsForClasses(apps, ["Alacritty"]), [
  {id: "Alacritty", icon: "Alacritty", name: "alacritty", wmClass: ""}
])
assert.deepEqual(Logic.appsForClasses(apps, ["org.gnome.nautilus"]), [
  {id: "org.gnome.Nautilus", icon: "org.gnome.Nautilus", name: "Files", wmClass: ""}
])
assert.deepEqual(Logic.appsForClasses(apps, []), [])
assert.deepEqual(Logic.appsForClasses(apps, ["hidden"]), [])

// A vertical bar has room for one glyph per workspace. With an icon the name
// is dropped; without one the number stands in, the way the stock widget
// paints every workspace. Horizontal bars always show the name.
assert.equal(Logic.barName(false, "", "Gmail", 5), "Gmail")
assert.equal(Logic.barName(false, "\uf0e0", "Gmail", 5), "Gmail")
assert.equal(Logic.barName(true, "\uf0e0", "Gmail", 5), "")
assert.equal(Logic.barName(true, "app:brave-origin", "Brave", 2), "")
assert.equal(Logic.barName(true, "", "Gmail", 5), "5")
assert.equal(Logic.barName(true, "", "", 12), "12")
assert.equal(Logic.barName(false, "", "", 5), "")

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
assert.deepEqual(Logic.displayLabel({icon: "\uf0ac", name: ""}, "app:x", 3, true), {icon: "\uf0ac", name: "", auto: false})
assert.deepEqual(Logic.displayLabel({icon: "", name: ""}, "", 7, true), {icon: "", name: "7", auto: false})
assert.deepEqual(Logic.displayLabel({icon: "", name: ""}, "app:x", 7, true), {icon: "app:x", name: "", auto: true})

// Urgent bookkeeping from Hyprland raw events.
assert.deepEqual(Logic.urgentAfter([], "urgent", "0xb", []), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xb"], "urgent", "0xa", []), ["0xa", "0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "activewindowv2", "0xb", []), ["0xa"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "closewindow", "0xa", []), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa", "0xb"], "tick", "", ["0xa"]), ["0xb"])
assert.deepEqual(Logic.urgentAfter(["0xa"], "urgent", "", []), ["0xa"])
assert.deepEqual(Logic.urgentAfter(null, "urgent", "0xa", null), ["0xa"])

// Sliding focus bar geometry.
const items = [{id: 1, x: 0, y: 0, width: 40, height: 30}, {id: 2, x: 42, y: 0, width: 60, height: 30}]
assert.deepEqual(Logic.focusGeometry(items, 2, false, 2), {x: 42, y: 28, width: 60, height: 2, visible: true})
assert.deepEqual(Logic.focusGeometry(items, 1, true, 2), {x: 38, y: 0, width: 2, height: 30, visible: true})
assert.equal(Logic.focusGeometry(items, 9, false, 2).visible, false)
assert.equal(Logic.focusGeometry(null, 1, false, 2).visible, false)

// Hyprland reports a monitor's size in physical pixels but window geometry in
// logical pixels, so the preview scales against the logical size. Rotated
// monitors swap the axes.
assert.deepEqual(Logic.logicalMonitor({x: 0, y: 0, width: 3440, height: 1440, scale: 1.25, transform: 0}),
  {x: 0, y: 0, width: 2752, height: 1152, scale: 1.25})
assert.deepEqual(Logic.logicalMonitor({x: 3440, y: 0, width: 1920, height: 1080, scale: 1, transform: 1}),
  {x: 3440, y: 0, width: 1080, height: 1920, scale: 1})
assert.deepEqual(Logic.logicalMonitor({x: 0, y: 0, width: 2560, height: 1440, scale: 0, transform: 3}),
  {x: 0, y: 0, width: 1440, height: 2560, scale: 1})
assert.equal(Logic.logicalMonitor(null), null)

// Address normalization: Hyprland events carry bare lowercase hex, hyprctl
// carries a 0x prefix; both must land on the same key.
assert.equal(Logic.normalizedAddress("0x5559FE065F80"), "5559fe065f80")
assert.equal(Logic.normalizedAddress(" 5559fe065f80 "), "5559fe065f80")
assert.equal(Logic.normalizedAddress(""), "")
assert.equal(Logic.normalizedAddress(null), "")

// Logical monitor: common scales and awkward rounding.
assert.deepEqual(Logic.logicalMonitor({x: 0, y: 0, width: 2880, height: 1800, scale: 1.5, transform: 0}),
  {x: 0, y: 0, width: 1920, height: 1200, scale: 1.5})
assert.deepEqual(Logic.logicalMonitor({x: -2560, y: -300, width: 2560, height: 1440, scale: 2, transform: 0}),
  {x: -2560, y: -300, width: 1280, height: 720, scale: 2})
assert.deepEqual(Logic.logicalMonitor({x: 0, y: 0, width: 3440, height: 1440, scale: 1.333333, transform: 2}),
  {x: 0, y: 0, width: 2580, height: 1080, scale: 1.333333})

// Preview layout: only mapped, visible, positively sized windows; tiled before
// floating; capped at `limit`; class and title carried for badges and blocks.
const clients = [
  {address: "0xa", at: [12, 38], size: [1357, 1102], floating: false, hidden: false, mapped: true, class: "brave-origin", title: "Sheets"},
  {address: "0xb", at: [300, 300], size: [600, 400], floating: true, hidden: false, mapped: true, class: "com.mitchellh.ghostty", title: "term"},
  {address: "0xc", at: [1383, 38], size: [1357, 544], floating: false, hidden: false, mapped: true, class: "com.mitchellh.ghostty", title: "term2"},
  {address: "0xd", at: [0, 0], size: [0, 400], floating: false, hidden: false, mapped: true, class: "x", title: "zero width"},
  {address: "0xe", at: [0, 0], size: [100, 100], floating: false, hidden: true, mapped: true, class: "x", title: "hidden"},
  {address: "0xf", at: [0, 0], size: [100, 100], floating: false, hidden: false, mapped: false, class: "x", title: "unmapped"},
  {address: "0x10", at: null, size: [100, 100], floating: false, hidden: false, mapped: true, class: "x", title: "no at"},
  null
]
const laidOut = Logic.previewLayout(clients, 12)
assert.deepEqual(laidOut.map(w => w.address), ["0xa", "0xc", "0xb"])
assert.deepEqual(laidOut[0], {address: "0xa", ax: 12, ay: 38, aw: 1357, ah: 1102, floating: false, cls: "brave-origin", title: "Sheets"})
assert.equal(laidOut[2].floating, true)
assert.equal(Logic.previewLayout(clients, 2).length, 2)
assert.deepEqual(Logic.previewLayout(clients, 2).map(w => w.address), ["0xa", "0xc"])
// Qt hands QML array-likes, not JS Arrays, for the `at`/`size` lists.
const arrayLike = {address: "0xq", at: {0: 5, 1: 6, length: 2}, size: {0: 200, 1: 100, length: 2}, floating: false, hidden: false, mapped: true, class: "c", title: "t"}
assert.deepEqual(Logic.previewLayout([arrayLike], 12), [{address: "0xq", ax: 5, ay: 6, aw: 200, ah: 100, floating: false, cls: "c", title: "t"}])
assert.deepEqual(Logic.previewLayout(null, 12), [])
assert.deepEqual(Logic.previewLayout([], 12), [])

// Auto icon churn: the dominant app closes, the next takes over, and on a
// vertical bar an icon-less workspace falls back to its number.
const before = Logic.autoIconFor(["brave-browser", "brave-browser", "Alacritty"], apps)
const after = Logic.autoIconFor(["Alacritty"], apps)
const gone = Logic.autoIconFor([], apps)
assert.equal(before, "app:brave-desktop")
assert.equal(after, "app:Alacritty")
assert.equal(gone, "")
assert.equal(Logic.barName(true, Logic.displayLabel({icon: "", name: ""}, before, 9, true).icon, "", 9), "")
assert.equal(Logic.barName(true, Logic.displayLabel({icon: "", name: ""}, gone, 9, true).icon, Logic.displayLabel({icon: "", name: ""}, gone, 9, true).name, 9), "9")

console.log("workspace add/remove logic tests passed")
