import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Workspace labels for the Omarchy bar.
//
// Built on Ui.Panel + Ui.KeyboardPanel, the same machinery the built-in
// wifi / volume / displays widgets use, so the editor is a real layer-shell
// panel: it takes keyboard focus, clamps and scrolls inside the screen, and
// hands the popout slot over to other bar widgets correctly.
//
// Labels and the pinned-slot list live in shell.json under this widget's
// layout entry, NOT in this file, so editing them needs no shell restart:
//
//   right-click any workspace  ->  editor, focused on that workspace's row
//   click "+"                  ->  pin, focus and name the next free workspace
//   omarchy bar set wes.workspaces labels '{"1":{"icon":"","name":"Code"}}' --json
//
// The focused workspace keeps its own icon and gets its name underlined.
Panel {
  id: root
  moduleName: "wes.workspaces"
  ipcTarget: "wes.workspaces"
  // We own the IpcHandler so the target can carry openFor/add/remove on top
  // of the open/close/toggle set Panel would otherwise register.
  manageIpc: false

  // Panel is not a BarWidget, so the bar geometry helpers BarWidget would
  // have provided have to be lifted off the host here.

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  // Fallbacks used for any workspace with nothing stored in shell.json.
  // `barWidget.defaults` in the manifest is NOT auto-merged into `settings`,
  // so the defaults have to live here too.
  readonly property var defaultLabels: ({
    "1": { icon: "󰚩", name: "Code" },
    "2": { icon: "", name: "Home" },
    "3": { icon: "", name: "Web" },
    "4": { icon: "", name: "X" },
    "5": { icon: "", name: "Gmail" }
  })

  // Every glyph here was render-verified against JetBrainsMono Nerd Font.
  readonly property var iconPresets: [
    { value: "", label: "—  (no icon)", description: "text only" },
    { value: "", label: "   terminal", description: "U+0F120" },
    { value: "", label: "   code", description: "U+0F121" },
    { value: "󰚩", label: "󰚩   robot", description: "U+F06A9" },
    { value: "", label: "   home", description: "U+0F015" },
    { value: "", label: "   globe", description: "U+0F0AC" },
    { value: "", label: "   bird", description: "U+0F099" },
    { value: "", label: "   mail", description: "U+0F0E0" },
    { value: "", label: "   chat", description: "U+0F075" },
    { value: "", label: "   chats", description: "U+0F086" },
    { value: "", label: "   music", description: "U+0F001" },
    { value: "", label: "   film", description: "U+0F008" },
    { value: "", label: "   image", description: "U+0F03E" },
    { value: "", label: "   folder", description: "U+0F07B" },
    { value: "", label: "   document", description: "U+0F0F6" },
    { value: "", label: "   book", description: "U+0F02D" },
    { value: "", label: "   settings", description: "U+0F013" },
    { value: "", label: "   wrench", description: "U+0F0AD" },
    { value: "", label: "   gears", description: "U+0F085" },
    { value: "", label: "   user", description: "U+0F007" },
    { value: "", label: "   users", description: "U+0F0C0" },
    { value: "", label: "   clock", description: "U+0F017" },
    { value: "", label: "   calendar", description: "U+0F073" },
    { value: "", label: "   bell", description: "U+0F0F3" },
    { value: "", label: "   star", description: "U+0F005" },
    { value: "", label: "   heart", description: "U+0F004" },
    { value: "", label: "   cloud", description: "U+0F0C2" },
    { value: "", label: "   wifi", description: "U+0F1EB" },
    { value: "", label: "   lock", description: "U+0F023" },
    { value: "", label: "   key", description: "U+0F084" },
    { value: "", label: "   github", description: "U+0F09B" },
    { value: "", label: "   linux", description: "U+0F17C" },
    { value: "", label: "   apple", description: "U+0F179" },
    { value: "", label: "   cube", description: "U+0F1B2" },
    { value: "", label: "   rocket", description: "U+0F135" },
    { value: "", label: "   fire", description: "U+0F06D" },
    { value: "", label: "   bolt", description: "U+0F0E7" },
    { value: "", label: "   idea", description: "U+0F0EB" },
    { value: "", label: "   chart", description: "U+0F080" },
    { value: "", label: "   database", description: "U+0F1C0" },
    { value: "", label: "   server", description: "U+0F233" },
    { value: "", label: "   desktop", description: "U+0F108" },
    { value: "", label: "   mobile", description: "U+0F10B" },
    { value: "", label: "   coffee", description: "U+0F0F4" },
    { value: "", label: "   paint", description: "U+0F1FC" },
    { value: "", label: "   search", description: "U+0F002" },
    { value: "", label: "   pencil", description: "U+0F040" },
    { value: "", label: "   link", description: "U+0F0C1" },
    { value: "", label: "   refresh", description: "U+0F021" },
  ]

  // Hyprland numbers workspaces from 1. The cap matches the manifest's schema
  // so a hand-edited settings value can't spray hundreds of buttons into the bar.
  readonly property int maxWorkspace: 20

  // ---------------------------------------------------------------------
  // Settings plumbing
  //
  // updateEntryInline writes shell.json, and the new value only reaches
  // `settings` once the config has round-tripped back through the shell. Two
  // edits in quick succession would therefore both read the pre-write
  // `settings`, and the second would silently clobber the first. Writes are
  // staged in `pendingPatch` and read back through effSetting() until the
  // round-trip lands.
  // ---------------------------------------------------------------------
  property var pendingPatch: null

  // The overlay must never outlive the round-trip it is bridging. A write
  // from outside this widget (`omarchy bar set`, a hand-edited shell.json)
  // will never match what was staged, so without an expiry the overlay would
  // mask that external change until the next shell restart.
  Timer {
    id: pendingExpiry
    interval: 1500
    onTriggered: root.pendingPatch = null
  }

  function effSetting(name, fallback) {
    if (root.pendingPatch && root.pendingPatch.hasOwnProperty(name)) {
      var staged = root.pendingPatch[name]
      return (staged === undefined || staged === null) ? fallback : staged
    }
    return root.setting(name, fallback)
  }

  // Deferred, never called inline. Clearing the overlay retriggers every
  // binding that reads it, including the Repeater models - doing that
  // synchronously inside the settings-changed handler re-enters QML object
  // creation while the bar is still rebuilding its slots, which segfaults
  // quickshell in IpcHandler::updateRegistration. Qt.callLater also folds a
  // burst of settings changes into a single reconcile.
  onSettingsChanged: Qt.callLater(root.reconcilePending)

  // Drop the overlay once every staged key matches what came back.
  function reconcilePending() {
    if (!root.pendingPatch) return
    for (var key in root.pendingPatch) {
      var want = root.pendingPatch[key]
      var have = root.settings ? root.settings[key] : undefined
      var wantJson = (want === undefined || want === null) ? "" : JSON.stringify(want)
      var haveJson = (have === undefined || have === null) ? "" : JSON.stringify(have)
      if (wantJson !== haveJson) return
    }
    pendingExpiry.stop()
    root.pendingPatch = null
  }

  // updateEntryInline REPLACES the whole layout entry rather than merging, so
  // every other setting has to be carried across explicitly. A patch value of
  // undefined deletes the key - that is how "reset" drops back to defaults.
  function persist(patch) {
    var merged = {}
    if (root.pendingPatch) {
      for (var a in root.pendingPatch) merged[a] = root.pendingPatch[a]
    }
    for (var b in patch) merged[b] = patch[b]
    root.pendingPatch = merged
    pendingExpiry.restart()

    if (!root.bar || !root.bar.shell) return
    if (typeof root.bar.shell.updateEntryInline !== "function") return

    var payload = {}
    if (root.settings) {
      for (var k in root.settings) if (k !== "id") payload[k] = root.settings[k]
    }
    for (var p in merged) {
      if (merged[p] === undefined || merged[p] === null) delete payload[p]
      else payload[p] = merged[p]
    }
    root.bar.shell.updateEntryInline(root.moduleName, payload)
  }

  // ---------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------
  readonly property var storedLabels: {
    var v = root.effSetting("labels", null)
    return (v && typeof v === "object") ? v : ({})
  }

  // The stored truth for a workspace. `name` may legitimately be "" meaning
  // "nothing set"; only displayFor() substitutes a fallback. Keeping the two
  // apart is what lets the editor show an empty field with its placeholder
  // instead of pre-filling it with the workspace number.
  function labelFor(id) {
    var key = String(id)
    var stored = root.storedLabels[key]
    var def = root.defaultLabels[key]

    var icon = ""
    if (stored && stored.icon !== undefined && stored.icon !== null) icon = String(stored.icon)
    else if (def) icon = def.icon

    var name = ""
    if (stored && stored.name !== undefined && stored.name !== null) name = String(stored.name)
    else if (def) name = def.name

    return { icon: icon, name: name }
  }

  // What the bar paints. WidgetButton hides itself when its text is empty, so
  // a workspace with both fields cleared would otherwise become an invisible,
  // unclickable gap - fall back to the number instead.
  function displayFor(id) {
    var label = root.labelFor(id)
    if (label.icon === "" && label.name === "") return { icon: "", name: String(id) }
    return label
  }

  // Bar button text is rich text (see the <span> note below), so anything the
  // user typed has to be escaped or a name like "R&D" or "<3" renders as markup.
  function escapeMarkup(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  // Snapshot of the effective labels, so editing one row can't drop the others.
  function effectiveMap() {
    var out = {}
    for (var k in root.storedLabels) {
      var s = root.storedLabels[k]
      if (s && typeof s === "object") out[k] = { icon: String(s.icon || ""), name: String(s.name || "") }
    }
    var ids = root.editableIds()
    for (var i = 0; i < ids.length; i++) {
      var key = String(ids[i])
      if (out[key] === undefined) {
        var l = root.labelFor(ids[i])
        out[key] = { icon: l.icon, name: l.name }
      }
    }
    return out
  }

  // A row that has just been removed must not be written back by the
  // editingFinished its own TextField fires while losing focus.
  function isEditable(id) {
    return root.editableIds().indexOf(id) !== -1
  }

  // An all-empty entry only carries meaning where it overrides a built-in
  // default (clearing "Twitter" to get a bare "4" back). Anywhere else it is
  // dead weight that would keep a phantom row in the editor forever, since
  // editableIds() keeps every id that still has a stored label.
  function pruneLabels(map) {
    for (var k in map) {
      var v = map[k]
      if (v && v.icon === "" && v.name === "" && root.defaultLabels[k] === undefined) delete map[k]
    }
    return map
  }

  function setIcon(id, glyph) {
    if (!root.isEditable(id)) return
    if (String(glyph) === root.labelFor(id).icon) return
    var m = root.effectiveMap()
    var key = String(id)
    if (!m[key]) m[key] = { icon: "", name: "" }
    m[key].icon = String(glyph)
    root.persist({ labels: root.pruneLabels(m) })
  }

  function setName(id, text) {
    if (!root.isEditable(id)) return
    if (String(text) === root.labelFor(id).name) return
    var m = root.effectiveMap()
    var key = String(id)
    if (!m[key]) m[key] = { icon: "", name: "" }
    m[key].name = String(text)
    root.persist({ labels: root.pruneLabels(m) })
  }

  function resetLabels() {
    root.persist({ labels: undefined, pinned: undefined })
    root.editorTarget = 0
    root.showPicker = false
  }

  // ---------------------------------------------------------------------
  // Pinned slots
  //
  // Kept as an explicit list so "+" and the per-row remove can add or drop
  // any slot, not just the last one. `minWorkspaces` was the original
  // floor-only setting and still seeds the list the first time, so an
  // existing config keeps its 1..N behaviour untouched.
  // ---------------------------------------------------------------------
  readonly property var pinnedIds: {
    var raw = root.effSetting("pinned", null)
    var out = []

    if (Array.isArray(raw)) {
      for (var i = 0; i < raw.length; i++) {
        var id = parseInt(raw[i], 10)
        if (!isNaN(id) && id > 0 && id <= root.maxWorkspace && out.indexOf(id) === -1) out.push(id)
      }
    } else {
      var floor = parseInt(root.effSetting("minWorkspaces", 5), 10)
      if (isNaN(floor) || floor < 0) floor = 0
      if (floor > root.maxWorkspace) floor = root.maxWorkspace
      for (var n = 1; n <= floor; n++) out.push(n)
    }

    out.sort(function(left, right) { return left - right })
    return out
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function hasWindows(id) {
    var ws = root.workspaceById(id)
    return ws !== null && ws.toplevels.values.length > 0
  }

  // Every workspace Hyprland currently reports, plus the pinned slots. No
  // upper bound on live ones: a workspace that exists always gets a button.
  function workspaceIds() {
    var ids = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && ids.indexOf(id) === -1) ids.push(id)
    }

    // A freshly created workspace can be focused before it holds a toplevel.
    var focusedWs = Hyprland.focusedWorkspace
    if (focusedWs && focusedWs.id > 0 && ids.indexOf(focusedWs.id) === -1) ids.push(focusedWs.id)

    var pinned = root.pinnedIds
    for (var p = 0; p < pinned.length; p++) {
      if (ids.indexOf(pinned[p]) === -1) ids.push(pinned[p])
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Workspaces worth showing a row for: the visible ones plus any that still
  // carry a saved label, so a label survives its workspace going away.
  function editableIds() {
    var ids = root.workspaceIds()
    for (var k in root.storedLabels) {
      var n = parseInt(k, 10)
      if (!isNaN(n) && n > 0 && ids.indexOf(n) === -1) ids.push(n)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Lowest unused slot, or -1 when everything up to maxWorkspace is taken.
  function nextFreeId() {
    var ids = root.workspaceIds()
    for (var n = 1; n <= root.maxWorkspace; n++) {
      if (ids.indexOf(n) === -1) return n
    }
    return -1
  }

  readonly property bool canAdd: root.nextFreeId() > 0

  function addWorkspace() {
    var id = root.nextFreeId()
    if (id < 1) return

    var pinned = root.pinnedIds.slice()
    if (pinned.indexOf(id) === -1) pinned.push(id)
    pinned.sort(function(left, right) { return left - right })

    root.persist({ pinned: pinned })
    root.focusWorkspace(id)
    root.openFor(id, true)
  }

  // Unpin a slot and forget its label. A workspace that still holds windows
  // keeps its button until it empties - unpinning only drops the reservation.
  function removeWorkspace(id) {
    if (root.hasWindows(id)) return

    var pinned = root.pinnedIds.slice()
    var at = pinned.indexOf(id)
    if (at !== -1) pinned.splice(at, 1)

    var labels = root.effectiveMap()
    delete labels[String(id)]

    root.persist({ pinned: pinned, labels: root.pruneLabels(labels) })
    if (root.editorTarget === id) root.editorTarget = 0
    if (root.pickerFor === id) root.showPicker = false
  }

  // Scrolling over the bar row moves between workspaces. Deltas accumulate so
  // a trackpad's stream of small ticks doesn't fire a jump for each one.
  function handleWheel(delta) {
    root.wheelAccum += delta
    while (root.wheelAccum >= 120) { root.wheelAccum -= 120; root.cycleWorkspace(-1) }
    while (root.wheelAccum <= -120) { root.wheelAccum += 120; root.cycleWorkspace(1) }
  }

  function cycleWorkspace(step) {
    var ids = root.workspaceIds()
    if (ids.length === 0) return
    var current = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : ids[0]
    var at = ids.indexOf(current)
    if (at === -1) at = 0
    var next = at + step
    if (next < 0) next = ids.length - 1
    if (next >= ids.length) next = 0
    root.focusWorkspace(ids[next])
  }

  // Keyboard cursor through the editor rows.
  function moveTarget(step) {
    var ids = root.editableIds()
    if (ids.length === 0) return
    var at = ids.indexOf(root.editorTarget)
    if (at === -1) { root.editorTarget = ids[0]; return }
    var next = at + step
    if (next < 0) next = ids.length - 1
    if (next >= ids.length) next = 0
    root.editorTarget = ids[next]
  }

  // Enter/Space on the cursor row hands input to that row's name field.
  function editTarget() {
    if (root.editorTarget === 0) {
      var ids = root.editableIds()
      if (ids.length === 0) return
      root.editorTarget = ids[0]
    }
    root.autoFocusTarget = true
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---------------------------------------------------------------------
  // Editor lifecycle
  //
  // Panel supplies open/close/toggle/closeForPopoutSwitch and the popout
  // handshake; close() is overridden (the same way the built-in network
  // panel does) so dismissing also drops the row target and the icon picker.
  // ---------------------------------------------------------------------
  property int editorTarget: 0
  property bool showPicker: false
  property int pickerFor: 0
  property string iconQuery: ""

  // PanelKeyCatcher takes keys before its children, so it has to stand down
  // whenever a text field owns input or nothing could be typed. Counted
  // rather than bound to one field because every row carries an input.
  // Set only by entry points that mean "start typing here" (right-click, +,
  // Enter on the cursor row). Keyboard navigation deliberately leaves it
  // false: focusing a field blocks PanelKeyCatcher and would swallow the
  // next j/k.
  property bool autoFocusTarget: false
  property int wheelAccum: 0

  property int focusedFields: 0
  function noteFieldFocus(has) {
    root.focusedFields = Math.max(0, root.focusedFields + (has ? 1 : -1))
  }

  // PanelKeyCatcher is blocked while a field owns input, so every field has
  // to route Escape itself or the panel would be untypable-out-of.
  function escapeFrom() {
    if (root.showPicker) root.closePicker()
    else root.close()
  }

  function close() {
    root.controller.hide()
    root.editorTarget = 0
    root.showPicker = false
    root.pickerFor = 0
    root.iconQuery = ""
    root.focusedFields = 0
    root.autoFocusTarget = false
  }

  // Right-clicking a different workspace while the editor is up retargets it
  // rather than closing it; only re-clicking the workspace it already points
  // at toggles it shut. `force` is for entry points with no toggle sense.
  function openFor(id, force) {
    if (!force && root.opened && !root.showPicker && root.editorTarget === id) {
      root.close()
      return
    }
    root.editorTarget = id
    root.showPicker = false
    root.pickerFor = 0
    root.iconQuery = ""
    root.autoFocusTarget = true
    root.controller.show()
  }

  function openPicker(id) {
    root.pickerFor = id
    root.editorTarget = id
    root.iconQuery = ""
    root.showPicker = true
  }

  function closePicker() {
    root.showPicker = false
    root.pickerFor = 0
    root.iconQuery = ""
  }

  function chooseIcon(glyph) {
    root.setIcon(root.pickerFor, glyph)
    root.closePicker()
  }

  function toggleEditor() { root.toggle() }

  function iconMatches(preset, query) {
    if (query === "") return true
    var q = String(query).toLowerCase()
    return String(preset.label).toLowerCase().indexOf(q) !== -1
        || String(preset.description).toLowerCase().indexOf(q) !== -1
  }

  readonly property var filteredIcons: {
    var out = []
    for (var i = 0; i < root.iconPresets.length; i++) {
      if (root.iconMatches(root.iconPresets[i], root.iconQuery)) out.push(root.iconPresets[i])
    }
    return out
  }

  // ---------------------------------------------------------------------
  // Hover preview
  //
  // Hovering a workspace shows what is actually on it. Capture goes through
  // ScreencopyView pointed at each window's `wayland` handle — a
  // HyprlandToplevel is not itself a capture source, it only carries a
  // reference to one.
  //
  // Deliberately single-shot (`live: false` + captureFrame) rather than a live
  // feed: a live capture per window is far too expensive for something that
  // appears whenever the pointer crosses the bar.
  // ---------------------------------------------------------------------
  readonly property bool hoverPreviewEnabled: String(root.effSetting("hoverPreview", true)) !== "false"
  property int hoverPreviewId: 0
  property int pendingPreviewId: 0
  property Item hoverAnchor: null
  property Item pendingPreviewAnchor: null

  // The preview box is sized here, not derived from the Column's implicit
  // size: a Rectangle with an explicit `width` still has implicitWidth 0, so
  // the Column under-reported and the card clipped the miniature.
  readonly property int previewBoxWidth: Style.space(300)
  readonly property int previewBoxHeight: {
    var m = root.previewMonitor
    var ratio = (m && m.width > 0) ? m.height / m.width : 0.625
    return Math.max(40, Math.round(root.previewBoxWidth * ratio))
  }

  // Geometry of the monitor the previewed workspace lives on. An empty or
  // pinned workspace may not be assigned to one, so fall back to the focused
  // monitor rather than giving up.
  readonly property var previewMonitor: {
    if (root.hoverPreviewId <= 0) return null
    var ws = root.workspaceById(root.hoverPreviewId)
    if (ws && ws.monitor && ws.monitor.lastIpcObject) return ws.monitor.lastIpcObject
    var focusedMon = Hyprland.focusedMonitor
    return (focusedMon && focusedMon.lastIpcObject) ? focusedMon.lastIpcObject : null
  }

  // Real window geometry, straight off Hyprland, so the preview is a scaled
  // map of the workspace rather than a row of equal-sized tiles. Tiled windows
  // are emitted first so floating ones stack above them, matching what you'd
  // actually see.
  readonly property var previewWindows: {
    if (root.hoverPreviewId <= 0) return []
    var ws = root.workspaceById(root.hoverPreviewId)
    if (!ws) return []

    var all = ws.toplevels.values
    var out = []
    for (var i = 0; i < all.length; i++) {
      var o = all[i].lastIpcObject
      if (!o || !o.at || !o.size) continue
      if (o.hidden || o.mapped === false) continue
      if (o.size[0] <= 0 || o.size[1] <= 0) continue
      out.push({
        toplevel: all[i],
        ax: o.at[0], ay: o.at[1],
        aw: o.size[0], ah: o.size[1],
        floating: !!o.floating
      })
    }
    out.sort(function(a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0) })
    // One capture per window; cap it so a pathological workspace can't stall
    // the bar.
    return out.slice(0, 12)
  }

  function requestPreview(id, anchor) {
    if (!root.hoverPreviewEnabled) return
    // The editor owns the bar's single popout slot; a preview would evict it.
    if (root.opened) return
    if (!root.hasWindows(id)) return
    root.pendingPreviewId = id
    root.pendingPreviewAnchor = anchor
    previewDelay.restart()
  }

  // Only clears state belonging to `id`, so sweeping from one workspace to the
  // next doesn't cancel the arriving one's pending timer.
  function cancelPreview(id) {
    if (root.pendingPreviewId === id) { previewDelay.stop(); root.pendingPreviewId = 0 }
    if (root.hoverPreviewId === id) root.hoverPreviewId = 0
  }

  function hidePreview() {
    previewDelay.stop()
    root.pendingPreviewId = 0
    root.hoverPreviewId = 0
  }

  onOpenedChanged: if (root.opened) root.hidePreview()

  Timer {
    id: previewDelay
    interval: 450
    onTriggered: {
      if (root.opened || root.pendingPreviewId <= 0) return
      root.hoverAnchor = root.pendingPreviewAnchor
      root.hoverPreviewId = root.pendingPreviewId
      // The text tooltip is redundant once the preview is up, and they overlap.
      if (root.hoverAnchor && typeof root.hoverAnchor.hideOwnTooltip === "function")
        root.hoverAnchor.hideOwnTooltip()
    }
  }

  // ---------------------------------------------------------------------
  // Bar row
  // ---------------------------------------------------------------------
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    // The "+" occupies a cell, so it has to be counted or it wraps onto a
    // second row and disappears off the bar.
    columns: root.vertical ? 1 : root.workspaceIds().length + (root.canAdd ? 1 : 0)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        // Named wsLabel, not label: WidgetButton already has an internal
        // `label` item and a plain `label` property would shadow it.
        readonly property var wsLabel: root.displayFor(modelData)

        bar: root.bar

        // Always wrapped in <span> so Text.AutoText resolves to rich text every
        // time - otherwise the icon/label gap would shift when the <u> appears,
        // since rich text collapses plain consecutive spaces.
        text: {
          var glyph = root.escapeMarkup(wsButton.wsLabel.icon)
          var name = root.escapeMarkup(wsButton.wsLabel.name)

          if (root.vertical) return "<span>" + (glyph !== "" ? glyph : name) + "</span>"
          if (name === "") return "<span>" + glyph + "</span>"

          var shown = wsButton.focused ? "<u>" + name + "</u>" : name
          if (glyph === "") return "<span>" + shown + "</span>"
          return "<span>" + glyph + "&nbsp;&nbsp;" + shown + "</span>"
        }

        tooltipText: wsButton.wsLabel.name + "  —  right-click to edit"
        opacity: wsButton.occupied || wsButton.focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : -1
        fixedHeight: root.barSize
        onPressed: function(button) {
          if (button === Qt.RightButton || button === Qt.MiddleButton) root.openFor(wsButton.modelData, false)
          else root.focusWorkspace(wsButton.modelData)
        }
        onWheelMoved: function(delta) { root.handleWheel(delta) }
        onTooltipHoveredChanged: {
          if (wsButton.tooltipHovered) root.requestPreview(wsButton.modelData, wsButton)
          else root.cancelPreview(wsButton.modelData)
        }
      }
    }

    WidgetButton {
      id: addButton
      bar: root.bar
      text: "+"
      // Drives its own visibility (WidgetButton hides itself when this is
      // false) and the column count above, so the two can't drift apart.
      hasVisualContent: root.canAdd
      tooltipText: root.canAdd ? "Add workspace " + root.nextFreeId() : ""
      opacity: 0.5
      horizontalMargin: 6
      verticalPadding: 6
      fixedWidth: root.vertical ? root.barSize : -1
      fixedHeight: root.barSize
      onPressed: function(button) {
        if (button === Qt.RightButton || button === Qt.MiddleButton) root.openFor(0, true)
        else root.addWorkspace()
      }
      onWheelMoved: function(delta) { root.handleWheel(delta) }
    }
  }

  // PopupCard.close() assigns `open` directly unless its owner has a close(),
  // which would overwrite the binding below for good. The editor can't be that
  // owner — its close() would tear down the wrong thing — so the preview gets
  // its own.
  QtObject {
    id: hoverOwner
    function close() { root.hidePreview() }
  }

  PopupCard {
    id: hoverCard
    anchorItem: root.hoverAnchor ? root.hoverAnchor : grid
    owner: hoverOwner
    bar: root.bar
    triggerMode: "hover"
    open: root.hoverPreviewId > 0 && root.previewMonitor !== null && root.previewWindows.length > 0
    // contentWidth/Height are the card's OUTER size. fittedContentHeight adds
    // the padding+border inset for you; fittedContentWidth does not, so the
    // horizontal one has to be added by hand or the card is exactly one
    // inset too narrow and clips the right edge of its own content.
    readonly property real horizontalContentInset: hoverCard.padding * 2
      + Border.left(hoverCard.borderSpec) + Border.right(hoverCard.borderSpec)

    contentWidth: hoverCard.fittedContentWidth(
      root.previewBoxWidth + hoverCard.horizontalContentInset)
    contentHeight: hoverCard.fittedContentHeight(
      root.previewBoxHeight + Style.space(6) + previewCaption.implicitHeight)

    Column {
      id: previewColumn
      anchors.centerIn: parent
      spacing: Style.space(6)

      // Stands in for the monitor. Everything inside is positioned in real
      // Hyprland coordinates scaled by `sx`, so relative sizes and positions
      // survive.
      Rectangle {
        id: screenRect
        width: root.previewBoxWidth
        height: root.previewBoxHeight
        implicitWidth: width
        implicitHeight: height
        radius: Style.cornerRadius
        color: Qt.alpha(Color.popups.text, 0.05)
        border.width: 1
        border.color: Qt.alpha(Color.popups.text, 0.14)
        clip: true

        readonly property real sx: root.previewMonitor && root.previewMonitor.width > 0
          ? width / root.previewMonitor.width : 0
        readonly property real originX: root.previewMonitor ? root.previewMonitor.x : 0
        readonly property real originY: root.previewMonitor ? root.previewMonitor.y : 0

        Repeater {
          model: root.previewWindows

          Rectangle {
            id: winRect
            required property var modelData

            x: Math.round((winRect.modelData.ax - screenRect.originX) * screenRect.sx)
            y: Math.round((winRect.modelData.ay - screenRect.originY) * screenRect.sx)
            width: Math.max(3, Math.round(winRect.modelData.aw * screenRect.sx))
            height: Math.max(3, Math.round(winRect.modelData.ah * screenRect.sx))

            color: Color.popups.background
            border.width: 1
            border.color: Qt.alpha(Color.popups.text, winRect.modelData.floating ? 0.45 : 0.22)
            radius: 2
            clip: true

            ScreencopyView {
              id: shot
              anchors.fill: parent
              captureSource: winRect.modelData.toplevel ? winRect.modelData.toplevel.wayland : null
              live: false
              paintCursor: false
            }
          }
        }
      }

      Text {
        id: previewCaption
        width: screenRect.width
        elide: Text.ElideRight
        text: {
          var label = root.displayFor(root.hoverPreviewId)
          var n = root.previewWindows.length
          return label.name + "  ·  " + n + (n === 1 ? " window" : " windows")
        }
        color: Qt.darker(Color.popups.text, 1.3)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---------------------------------------------------------------------
  // Editor panel
  // ---------------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: grid
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Stand down while any field owns input, or typing a name would be
      // eaten as j/k/x navigation.
      blocked: root.focusedFields > 0
      onCloseRequested: root.showPicker ? root.closePicker() : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dy !== 0 && !root.showPicker) root.moveTarget(dy) }
      onActivateRequested: if (!root.showPicker) root.editTarget()
      onDeleteRequested: if (!root.showPicker && root.editorTarget > 0) root.removeWorkspace(root.editorTarget)
      onTextKey: function(t) {
        if (root.showPicker) return
        if (t === "i" && root.editorTarget > 0) root.openPicker(root.editorTarget)
        else if (t === "a" || t === "+") root.addWorkspace()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > scrollArea.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: root.showPicker
                ? (root.labelFor(root.pickerFor).icon !== "" ? root.labelFor(root.pickerFor).icon : "")
                : ""
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: root.showPicker ? "Choose icon" : "Workspaces"
                color: Color.popups.text
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.showPicker
                  ? ("WORKSPACE " + root.pickerFor + "  ·  " + root.filteredIcons.length + " ICONS")
                  : (root.editableIds().length + " WORKSPACES  ·  RIGHT-CLICK TO EDIT")
                color: Qt.darker(Color.popups.text, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          PanelSeparator { width: parent.width; foreground: Color.popups.text }

          // ---------- List view ----------
          PanelSectionHeader {
            visible: !root.showPicker
            text: "LABELS"
            foreground: Color.popups.text
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Column {
            width: parent.width
            visible: !root.showPicker
            spacing: Style.space(4)

            Repeater {
              model: root.editableIds()

              Rectangle {
                id: editRow
                required property int modelData
                readonly property var wsLabel: root.labelFor(editRow.modelData)
                readonly property bool targeted: root.editorTarget === editRow.modelData
                readonly property bool live: root.hasWindows(editRow.modelData)

                width: parent.width
                height: rowLayout.implicitHeight + Style.space(8)
                radius: Style.cornerRadius
                color: editRow.targeted ? Qt.alpha(Color.popups.text, 0.10) : "transparent"

                RowLayout {
                  id: rowLayout
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Text {
                    text: String(editRow.modelData)
                    color: Qt.darker(Color.popups.text, 1.5)
                    Layout.preferredWidth: Style.space(12)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  // Opens the inline picker rather than a nested dropdown -
                  // a QQC.Popup inside this panel would be clipped by the
                  // ScrollView and could not take keyboard focus.
                  PanelActionButton {
                    iconText: editRow.wsLabel.icon !== "" ? editRow.wsLabel.icon : "—"
                    tooltipText: "Choose icon for workspace " + editRow.modelData
                    bordered: true
                    foreground: Color.popups.text
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onClicked: root.openPicker(editRow.modelData)
                  }

                  TextField {
                    id: nameField
                    Layout.fillWidth: true
                    height: Style.spacing.controlHeight
                    text: editRow.wsLabel.name
                    placeholderText: "name"
                    foreground: Color.popups.text
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    onEditingFinished: root.setName(editRow.modelData, text)
                    onAccepted: { root.setName(editRow.modelData, text); keyCatcher.forceActiveFocus() }
                    Keys.onEscapePressed: function(event) { root.escapeFrom(); event.accepted = true }
                    onActiveFocusChanged: root.noteFieldFocus(activeFocus)
                    Component.onDestruction: if (activeFocus) root.noteFieldFocus(false)

                    // Opening from a right-click (or from "+") drops the
                    // cursor straight into that workspace's name.
                    function grabIfTargeted() {
                      if (!root.autoFocusTarget) return
                      if (root.opened && !root.showPicker && editRow.targeted) {
                        root.autoFocusTarget = false
                        nameField.forceActiveFocus()
                      }
                    }

                    Component.onCompleted: Qt.callLater(nameField.grabIfTargeted)

                    Connections {
                      target: root
                      function onEditorTargetChanged() { Qt.callLater(nameField.grabIfTargeted) }
                      function onOpenedChanged() { Qt.callLater(nameField.grabIfTargeted) }
                      function onAutoFocusTargetChanged() { Qt.callLater(nameField.grabIfTargeted) }
                    }
                  }

                  PanelActionButton {
                    iconText: "×"
                    tooltipText: editRow.live
                      ? "Workspace " + editRow.modelData + " still has windows"
                      : "Remove workspace " + editRow.modelData
                    foreground: Color.popups.text
                    opacity: editRow.live ? 0.25 : 0.8
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onClicked: root.removeWorkspace(editRow.modelData)
                  }
                }
              }
            }
          }

          // ---------- Icon picker view ----------
          Column {
            width: parent.width
            visible: root.showPicker
            spacing: Style.space(10)

            TextField {
              id: searchField
              width: parent.width
              height: Style.spacing.controlHeight
              text: root.iconQuery
              placeholderText: "Search icons…"
              foreground: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              onTextChanged: root.iconQuery = text
              Keys.onEscapePressed: function(event) { root.escapeFrom(); event.accepted = true }
              onActiveFocusChanged: root.noteFieldFocus(activeFocus)
              Component.onDestruction: if (activeFocus) root.noteFieldFocus(false)
              // The picker is summoned by a click, so put the caret where the
              // user is already looking.
              onVisibleChanged: if (visible) Qt.callLater(searchField.forceActiveFocus)
              Component.onCompleted: if (visible) Qt.callLater(searchField.forceActiveFocus)
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.filteredIcons

                PanelActionButton {
                  required property var modelData
                  iconText: modelData.value !== "" ? modelData.value : "—"
                  tooltipText: String(modelData.label).replace(modelData.value, "").trim()
                    + "   " + modelData.description
                  bordered: root.labelFor(root.pickerFor).icon === modelData.value
                  foreground: Color.popups.text
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.chooseIcon(modelData.value)
                }
              }
            }

            Text {
              width: parent.width
              visible: root.filteredIcons.length === 0
              text: "No matching icons. Paste any glyph below instead."
              color: Qt.darker(Color.popups.text, 1.4)
              wrapMode: Text.WordWrap
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: customGlyph
                Layout.preferredWidth: Style.space(70)
                height: Style.spacing.controlHeight
                placeholderText: "glyph"
                horizontalAlignment: Text.AlignHCenter
                foreground: Color.popups.text
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                onAccepted: root.chooseIcon(text)
                Keys.onEscapePressed: function(event) { root.escapeFrom(); event.accepted = true }
                onActiveFocusChanged: root.noteFieldFocus(activeFocus)
                Component.onDestruction: if (activeFocus) root.noteFieldFocus(false)
              }

              Button {
                text: "Use glyph"
                bordered: true
                foreground: Color.popups.text
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.chooseIcon(customGlyph.text)
              }

              Item { Layout.fillWidth: true }

              Button {
                text: "Back"
                bordered: true
                foreground: Color.popups.text
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.closePicker()
              }
            }
          }

          PanelSeparator {
            width: parent.width
            visible: !root.showPicker
            foreground: Color.popups.text
          }

          Text {
            width: parent.width
            visible: !root.showPicker
            text: "j/k move  ·  enter rename  ·  i icon  ·  a add  ·  x remove  ·  esc close"
            color: Qt.darker(Color.popups.text, 1.6)
            wrapMode: Text.WordWrap
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          RowLayout {
            width: parent.width
            visible: !root.showPicker
            spacing: Style.space(8)

            Button {
              text: root.canAdd ? "Add workspace " + root.nextFreeId() : "All slots used"
              iconText: "+"
              bordered: true
              enabled: root.canAdd
              opacity: root.canAdd ? 1 : 0.4
              foreground: Color.popups.text
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.addWorkspace()
            }

            Item { Layout.fillWidth: true }

            Button {
              id: resetButton
              text: "Reset"
              bordered: true
              foreground: Color.popups.text
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.resetLabels()
            }
          }
        }
      }
    }
  }

  // Lets the editor be driven from a keybinding or a terminal:
  //   omarchy-shell wes.workspaces toggleEditor
  //   omarchy-shell wes.workspaces openFor 3
  //   omarchy-shell wes.workspaces add
  //   omarchy-shell wes.workspaces remove 6
  IpcHandler {
    target: "wes.workspaces"

    function toggleEditor(): void { root.toggle() }
    function toggle(): void { root.toggle() }
    function open(): void { root.controller.show() }
    function close(): void { root.close() }
    function openFor(id: string): void { root.openFor(parseInt(id, 10) || 0, false) }
    function picker(id: string): void { root.openPicker(parseInt(id, 10) || 0); root.controller.show() }
    function add(): void { root.addWorkspace() }
    function reset(): void { root.resetLabels() }
    function next(): void { root.cycleWorkspace(1) }
    function prev(): void { root.cycleWorkspace(-1) }
    function remove(id: string): void { root.removeWorkspace(parseInt(id, 10) || 0) }
  }
}
