import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import "Logic.js" as Logic

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
//   omarchy bar set io.github.wbuf81.workspace-labels labels '{"1":{"icon":"","name":"Code"}}' --json
//
// The focused workspace keeps its own icon and gets its name underlined.
Panel {
  id: root
  moduleName: "io.github.wbuf81.workspace-labels"
  ipcTarget: "io.github.wbuf81.workspace-labels"
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
  // Station palette, in omastorm's spirit: one ink, one dim, one hairline,
  // the theme accent. The editor and the preview card draw only from these,
  // so a theme change re-inks the whole surface at once.
  // ---------------------------------------------------------------------
  readonly property color ink: Color.popups.text
  readonly property color dim: Util.alpha(ink, 0.55)
  readonly property color faint: Util.alpha(ink, 0.3)
  readonly property color line: Util.alpha(ink, 0.14)
  readonly property color well: Util.alpha(ink, 0.035)
  readonly property color screenWell: Qt.darker(Color.popups.background, 1.35)
  readonly property string panelFont: root.bar ? root.bar.fontFamily : Style.font.family

  function pad(n) { return String(Math.max(0, Number(n) || 0)).padStart(2, "0") }

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

  // What the bar paints. An icon-less workspace borrows the icon of the app
  // running on it (auto icons), and a workspace with both fields empty falls
  // back to its number so the button never becomes an invisible gap.
  readonly property bool autoIcons: root.effSetting("autoIcons", true) !== false

  function displayFor(id) {
    return Logic.displayLabel(root.labelFor(id), root.autoIcons ? root.autoIconFor(id) : "", id, root.autoIcons)
  }

  // Unique window classes currently on a workspace.
  function classesOn(id) {
    var classes = []
    var tl = root.toplevelsForWorkspace(id)
    for (var i = 0; i < tl.length; i++) {
      var o = tl[i].lastIpcObject
      var cls = o ? String(o["class"] || "") : ""
      if (cls) classes.push(cls)
    }
    return classes
  }

  function autoIconFor(id) {
    return Logic.autoIconFor(root.classesOn(id), root.desktopEntries)
  }

  // ---------------------------------------------------------------------
  // App icons
  //
  // A stored icon is normally a literal glyph. The "app:" prefix instead names
  // a desktop-entry icon, resolved through the shell's AppLibrary. Existing
  // configs are unaffected: no Nerd Font glyph starts with "app:".
  //
  // Note the icon name is NOT the window class. Brave's class is
  // "brave-browser" but its icon is "brave-desktop"; the two are linked only
  // by StartupWMClass in the .desktop file, which is why a naive
  // iconSource(class) lookup returns the generic fallback.
  // ---------------------------------------------------------------------
  readonly property string appIconPrefix: "app:"

  // Omarchy 4.0.3 hands bar-widget plugins a scoped shell facade whose
  // appLibrary is null (only menu plugins get it), so desktop entries and
  // icon lookups go straight to Quickshell here instead.
  readonly property var desktopEntries: DesktopEntries.applications.values

  function isAppIcon(icon) {
    return String(icon || "").indexOf(root.appIconPrefix) === 0
  }

  function appIconName(icon) {
    return String(icon || "").substring(root.appIconPrefix.length)
  }

  // Mirrors the shell's AppLibrary.iconSource: absolute paths and URLs pass
  // through, theme names resolve through the icon theme, and anything unknown
  // falls back to the generic executable icon rather than a blank Image.
  function appIconSource(name) {
    var value = String(name || "")
    if (value === "") return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    var themed = Quickshell.iconPath(value, true)
    if (themed.length > 0) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  // Every visible installed app whose icon actually resolves, filtered by
  // name. An entry naming an icon no theme provides would only ever paint the
  // generic executable fallback, so it is left out of the picker.
  function appEntries(query) {
    var rows = Logic.appEntryRows(root.desktopEntries, query)
    var out = []
    for (var i = 0; i < rows.length; i++) {
      var icon = rows[i].icon
      if (icon.charAt(0) === "/" || Quickshell.iconPath(icon, true) !== "") out.push(rows[i])
    }
    return out
  }

  // The icon behind one window class, for badges in the preview.
  function iconForClass(cls) {
    var rows = Logic.appsForClasses(root.desktopEntries, [String(cls || "")])
    return rows.length > 0 ? rows[0].icon : ""
  }

  // Apps currently running on a workspace, matched class -> StartupWMClass so
  // the workspace running Brave can be given the actual Brave icon in a click.
  function appsOnWorkspace(id) {
    return Logic.appsForClasses(root.desktopEntries, root.classesOn(id))
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
    return Logic.prunedLabels(map, root.defaultLabels)
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
    return Logic.normalizedPinned(raw, root.effSetting("minWorkspaces", 5), root.maxWorkspace)
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Workspace.toplevels can lag or omit sibling surfaces when an application
  // owns multiple windows. Use Quickshell's complete toplevel registry for
  // previews and filter by the workspace reported by each client instead.
  function toplevelsForWorkspace(id) {
    var out = []
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var toplevel = values[i]
      var ipc = toplevel.lastIpcObject
      var workspaceId = ipc && ipc.workspace ? ipc.workspace.id : 0
      if (Number(workspaceId) === Number(id)) out.push(toplevel)
    }
    return out
  }

  function hasWindows(id) {
    return root.toplevelsForWorkspace(id).length > 0
  }

  // Every workspace Hyprland currently reports, plus the pinned slots. No
  // upper bound on live ones: a workspace that exists always gets a button.
  function workspaceIds() {
    var liveIds = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0) liveIds.push(id)
    }

    // A freshly created workspace can be focused before it holds a toplevel.
    var focusedWs = Hyprland.focusedWorkspace
    return Logic.visibleWorkspaceIds(liveIds, focusedWs ? focusedWs.id : 0, root.pinnedIds)
  }

  // Workspaces worth showing a row for: the visible ones plus any that still
  // carry a saved label, so a label survives its workspace going away.
  function editableIds() {
    return Logic.editableWorkspaceIds(root.workspaceIds(), root.storedLabels, root.maxWorkspace)
  }

  // Lowest unused slot, or 0 when everything up to maxWorkspace is taken.
  function nextFreeId() {
    return Logic.nextFreeId(root.workspaceIds(), root.maxWorkspace)
  }

  readonly property bool canAdd: root.nextFreeId() > 0

  function addWorkspace() {
    var state = Logic.addedWorkspaceState(root.workspaceIds(), root.pinnedIds, root.maxWorkspace)
    var id = state.id
    if (id < 1) return

    root.persist({ pinned: state.pinned })
    root.focusWorkspace(id)
    root.openFor(id, true)
  }

  // Unpin a slot and forget its label. A workspace that still holds windows
  // keeps its button until it empties - unpinning only drops the reservation.
  function removeWorkspace(id) {
    var state = Logic.removedWorkspaceState(
      id, root.isEditable(id), root.hasWindows(id), root.pinnedIds,
      root.effectiveMap(), root.maxWorkspace)
    if (!state.removed) return

    root.persist({ pinned: state.pinned, labels: root.pruneLabels(state.labels) })
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

  // Middle-click: send the focused window to that workspace without following.
  function sendFocusedWindow(id) {
    if (!root.bar || Number(id) <= 0) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.move({ workspace = \"" + id + "\", follow = false })"))
  }

  // ---------------------------------------------------------------------
  // Urgent windows
  //
  // Hyprland announces urgency only as a raw IPC event carrying the window
  // address, so the set is kept here and cleared as soon as the window is
  // activated, closed, or its workspace is focused.
  // ---------------------------------------------------------------------
  property var urgentAddresses: []

  function normalizedAddress(value) {
    var s = String(value || "").trim().toLowerCase()
    return s.indexOf("0x") === 0 ? s.substring(2) : s
  }

  function focusedAddresses() {
    var focusedWs = Hyprland.focusedWorkspace
    if (!focusedWs) return []
    var out = []
    var tl = root.toplevelsForWorkspace(focusedWs.id)
    for (var i = 0; i < tl.length; i++) {
      var o = tl[i].lastIpcObject
      if (o && o.address) out.push(root.normalizedAddress(o.address))
    }
    return out
  }

  function isUrgent(id) {
    if (root.urgentAddresses.length === 0) return false
    var tl = root.toplevelsForWorkspace(id)
    for (var i = 0; i < tl.length; i++) {
      var o = tl[i].lastIpcObject
      if (o && o.address && root.urgentAddresses.indexOf(root.normalizedAddress(o.address)) !== -1) return true
    }
    return false
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event.name || "")
      if (name !== "urgent" && name !== "activewindowv2" && name !== "closewindow") return
      var address = root.normalizedAddress(String(event.data || "").split(",")[0])
      root.urgentAddresses = Logic.urgentAfter(root.urgentAddresses, name, address, root.focusedAddresses())
    }
    function onFocusedWorkspaceChanged() {
      if (root.urgentAddresses.length > 0)
        root.urgentAddresses = Logic.urgentAfter(root.urgentAddresses, "", "", root.focusedAddresses())
    }
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

  // Apps matching the search box, and the ones actually running on the
  // workspace being edited (offered first — that is the one-click path to
  // "this is my Brave workspace, give it the Brave icon").
  readonly property var filteredApps: root.showPicker ? root.appEntries(root.iconQuery) : []
  readonly property var workspaceApps: root.showPicker ? root.appsOnWorkspace(root.pickerFor) : []

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
  // capture | map | off. `map` draws blocks with app icons and never shows
  // screen content; it is also what a tile falls back to when a capture
  // yields nothing.
  readonly property string previewMode: Logic.previewMode(
    root.effSetting("previewMode", undefined), root.effSetting("hoverPreview", undefined))
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

    var all = root.toplevelsForWorkspace(root.hoverPreviewId)
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
        floating: !!o.floating,
        cls: String(o["class"] || ""),
        title: String(o.title || "")
      })
    }
    out.sort(function(a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0) })
    // One capture per window; cap it so a pathological workspace can't stall
    // the bar.
    return out.slice(0, 12)
  }

  function requestPreview(id, anchor) {
    if (root.previewMode === "off") return
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
  property alias grid: grid
  property alias hoverOwner: hoverOwner

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

      BarButton {
        required property int modelData
        host: root
        workspaceId: modelData
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

  PreviewCard { host: root }

  // ---------------------------------------------------------------------
  // Editor panel
  // ---------------------------------------------------------------------
  readonly property int liveCount: {
    var ids = root.workspaceIds()
    var n = 0
    for (var i = 0; i < ids.length; i++) if (root.hasWindows(ids[i])) n++
    return n
  }

  EditorPanel {
    host: root
    anchorItem: grid
    owner: root
    bar: root.bar
    open: root.opened
  }

  // Lets the editor be driven from a keybinding or a terminal:
  //   omarchy-shell io.github.wbuf81.workspace-labels toggleEditor
  //   omarchy-shell io.github.wbuf81.workspace-labels openFor 3
  //   omarchy-shell io.github.wbuf81.workspace-labels add
  //   omarchy-shell io.github.wbuf81.workspace-labels remove 6
  // Only the first bar instance's handler is registered, so on a multi-monitor
  // setup it forwards to the instance whose bar sits on the focused monitor,
  // matching what a right-click on that bar would do.
  function instanceOnFocusedMonitor() {
    var monitor = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var items = root.bar && typeof root.bar.moduleWidgets === "function"
      ? root.bar.moduleWidgets(root.moduleName) : []
    for (var i = 0; i < items.length; i++) {
      var item = items[i]
      var window = item && item.grid ? item.grid.QsWindow.window : null
      if (window && window.screen && String(window.screen.name || "") === monitor) return item
    }
    return root
  }

  function previewById(n) {
    if (n <= 0 || !root.hasWindows(n)) { root.hidePreview(); return }
    root.hoverAnchor = grid
    root.hoverPreviewId = n
  }

  IpcHandler {
    target: "io.github.wbuf81.workspace-labels"

    function toggleEditor(): void { root.instanceOnFocusedMonitor().toggle() }
    function toggle(): void { root.instanceOnFocusedMonitor().toggle() }
    function open(): void { root.instanceOnFocusedMonitor().controller.show() }
    function close(): void { root.instanceOnFocusedMonitor().close() }
    function openFor(id: string): void { root.instanceOnFocusedMonitor().openFor(parseInt(id, 10) || 0, false) }
    function picker(id: string): void {
      var target = root.instanceOnFocusedMonitor()
      target.openPicker(parseInt(id, 10) || 0)
      target.controller.show()
    }
    function add(): void { root.addWorkspace() }
    function reset(): void { root.resetLabels() }
    function preview(id: string): void { root.instanceOnFocusedMonitor().previewById(parseInt(id, 10) || 0) }
    function unpreview(): void { root.instanceOnFocusedMonitor().hidePreview() }
    function next(): void { root.cycleWorkspace(1) }
    function prev(): void { root.cycleWorkspace(-1) }
    function remove(id: string): void { root.removeWorkspace(parseInt(id, 10) || 0) }
    function send(id: string): void { root.sendFocusedWindow(parseInt(id, 10) || 0) }
  }
}
