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

console.log("workspace add/remove logic tests passed")
