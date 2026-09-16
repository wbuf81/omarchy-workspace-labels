// Pure workspace-state helpers shared by the QML widget and the Node test
// suite. Keep this file free of Qt APIs so release checks can execute the same
// add/remove decisions that run in the bar.

function workspaceId(value, maximum) {
  var number = Number(value)
  if (!isFinite(number) || Math.floor(number) !== number || number <= 0) return 0
  if (maximum !== undefined && number > maximum) return 0
  return number
}

function pushUnique(out, value, maximum) {
  var id = workspaceId(value, maximum)
  if (id > 0 && out.indexOf(id) === -1) out.push(id)
}

function normalizedPinned(raw, legacyMinimum, maximum) {
  var max = Math.max(0, Math.floor(Number(maximum) || 0))
  var out = []

  if (Array.isArray(raw)) {
    for (var i = 0; i < raw.length; i++) pushUnique(out, raw[i], max)
  } else {
    var floor = Math.floor(Number(legacyMinimum))
    if (!isFinite(floor) || floor < 0) floor = 0
    floor = Math.min(floor, max)
    for (var id = 1; id <= floor; id++) out.push(id)
  }

  out.sort(function(left, right) { return left - right })
  return out
}

function visibleWorkspaceIds(liveIds, focusedId, pinnedIds) {
  var out = []
  var live = Array.isArray(liveIds) ? liveIds : []
  var pinned = Array.isArray(pinnedIds) ? pinnedIds : []

  // Live Hyprland workspaces are intentionally not capped. The cap only
  // limits user-created empty slots.
  for (var i = 0; i < live.length; i++) pushUnique(out, live[i])
  pushUnique(out, focusedId)
  for (var p = 0; p < pinned.length; p++) pushUnique(out, pinned[p])

  out.sort(function(left, right) { return left - right })
  return out
}

function editableWorkspaceIds(visibleIds, storedLabels, maximum) {
  var out = visibleWorkspaceIds(visibleIds, 0, [])
  var labels = storedLabels && typeof storedLabels === "object" ? storedLabels : {}

  // A malformed labels object must not manufacture an unlimited editor list.
  // A real live workspace above the cap remains editable because it is already
  // present in visibleIds.
  for (var key in labels) pushUnique(out, key, maximum)
  out.sort(function(left, right) { return left - right })
  return out
}

function nextFreeId(visibleIds, maximum) {
  var used = visibleWorkspaceIds(visibleIds, 0, [])
  var max = Math.max(0, Math.floor(Number(maximum) || 0))
  for (var id = 1; id <= max; id++) {
    if (used.indexOf(id) === -1) return id
  }
  return 0
}

function addedWorkspaceState(visibleIds, pinnedIds, maximum) {
  var id = nextFreeId(visibleIds, maximum)
  var pinned = normalizedPinned(pinnedIds, 0, maximum)
  if (id > 0) pushUnique(pinned, id, maximum)
  pinned.sort(function(left, right) { return left - right })
  return { id: id, pinned: pinned }
}

function labelsWithout(labels, id) {
  var out = {}
  var source = labels && typeof labels === "object" ? labels : {}
  var removeKey = String(workspaceId(id))
  for (var key in source) {
    if (key === removeKey) continue
    var value = source[key]
    if (value && typeof value === "object") {
      out[key] = { icon: String(value.icon || ""), name: String(value.name || "") }
    }
  }
  return out
}

function prunedLabels(labels, defaultLabels) {
  var out = labelsWithout(labels, 0)
  var defaults = defaultLabels && typeof defaultLabels === "object" ? defaultLabels : {}
  for (var key in out) {
    if (out[key].icon === "" && out[key].name === "" && defaults[key] === undefined) delete out[key]
  }
  return out
}

function removedWorkspaceState(id, editable, occupied, pinnedIds, labels, maximum) {
  // The creation cap does not apply here: a genuine live Hyprland workspace
  // above the cap can still be labeled and have that label removed.
  var removeId = workspaceId(id)
  var pinned = normalizedPinned(pinnedIds, 0, maximum)
  if (removeId === 0 || !editable || occupied) {
    return { removed: false, pinned: pinned, labels: labelsWithout(labels, 0) }
  }

  var at = pinned.indexOf(removeId)
  if (at !== -1) pinned.splice(at, 1)
  return {
    removed: true,
    pinned: pinned,
    labels: labelsWithout(labels, removeId)
  }
}

// Desktop-entry rows for the icon picker. `entries` are Quickshell
// DesktopEntry objects (or anything with id/name/icon/startupClass/noDisplay);
// only visible entries that declare an icon are offered.
function appEntryRow(entry) {
  if (!entry || typeof entry !== "object") return null
  if (entry.noDisplay === true) return null
  var icon = String(entry.icon || "")
  if (icon === "") return null
  return {
    id: String(entry.id || ""),
    icon: icon,
    name: String(entry.name || ""),
    wmClass: String(entry.startupClass || "")
  }
}

function appEntryRows(entries, query) {
  var list = entries && typeof entries.length === "number" ? entries : []
  var needle = String(query || "").toLowerCase()
  var out = []
  for (var i = 0; i < list.length; i++) {
    var row = appEntryRow(list[i])
    if (!row) continue
    if (needle !== "" && row.name.toLowerCase().indexOf(needle) === -1) continue
    out.push(row)
  }
  out.sort(function(left, right) {
    var a = left.name.toLowerCase(), b = right.name.toLowerCase()
    return a < b ? -1 : (a > b ? 1 : 0)
  })
  return out
}

// Which apps are behind a set of running window classes. StartupWMClass is
// the authoritative link (Brave: class brave-browser, icon brave-desktop); the
// desktop id and the app name are fallbacks for entries that omit it.
function appsForClasses(entries, classes) {
  var rows = appEntryRows(entries, "")
  var wanted = []
  var list = Array.isArray(classes) ? classes : []
  for (var c = 0; c < list.length; c++) {
    var cls = String(list[c] || "").toLowerCase()
    if (cls !== "" && wanted.indexOf(cls) === -1) wanted.push(cls)
  }

  var out = []
  function push(row) {
    for (var i = 0; i < out.length; i++) if (out[i].icon === row.icon) return
    out.push(row)
  }
  var keys = ["wmClass", "id", "name"]
  for (var w = 0; w < wanted.length; w++) {
    for (var k = 0; k < keys.length; k++) {
      var matched = false
      for (var r = 0; r < rows.length; r++) {
        if (rows[r][keys[k]].toLowerCase() === wanted[w]) { push(rows[r]); matched = true }
      }
      if (matched) break
    }
  }
  return out
}

// What the bar paints beside a workspace's icon. A vertical bar is one glyph
// wide, so the name is dropped when there is an icon and replaced by the
// number when there is not; a full name would spill past the bar.
function barName(vertical, icon, name, id) {
  if (!vertical) return String(name || "")
  if (String(icon || "") !== "") return ""
  return String(workspaceId(id) || "")
}

// Hover preview mode. The tri-state `previewMode` setting wins; the older
// `hoverPreview` boolean only still means "off" when it is false.
function previewMode(modeValue, legacyHoverPreview) {
  var mode = String(modeValue === undefined || modeValue === null ? "" : modeValue)
  if (mode === "capture" || mode === "map" || mode === "off") return mode
  return legacyHoverPreview === false ? "off" : "capture"
}

// The most frequent non-empty class; ties go to the one seen first.
function dominantClass(classes) {
  var list = Array.isArray(classes) ? classes : []
  var counts = {}
  var order = []
  for (var i = 0; i < list.length; i++) {
    var cls = String(list[i] || "")
    if (cls === "") continue
    if (counts[cls] === undefined) { counts[cls] = 0; order.push(cls) }
    counts[cls] += 1
  }
  var best = ""
  for (var o = 0; o < order.length; o++) {
    if (best === "" || counts[order[o]] > counts[best]) best = order[o]
  }
  return best
}

// The icon an unlabeled workspace borrows from what is running on it: the
// dominant app first, then any app we can identify at all.
function autoIconFor(classes, entries) {
  var list = Array.isArray(classes) ? classes : []
  var lead = dominantClass(list)
  var rows = lead === "" ? [] : appsForClasses(entries, [lead])
  if (rows.length === 0) rows = appsForClasses(entries, list)
  return rows.length > 0 ? "app:" + rows[0].icon : ""
}

// What the bar paints for a workspace once auto icons and the number
// fallback are applied. `label` is the stored/default {icon, name}.
function displayLabel(label, autoIcon, id, autoEnabled) {
  var icon = label && label.icon !== undefined && label.icon !== null ? String(label.icon) : ""
  var name = label && label.name !== undefined && label.name !== null ? String(label.name) : ""
  var auto = false
  if (icon === "" && autoEnabled !== false && String(autoIcon || "") !== "") {
    icon = String(autoIcon)
    auto = true
  }
  if (icon === "" && name === "") name = String(workspaceId(id) || id)
  return { icon: icon, name: name, auto: auto }
}

// Urgent window bookkeeping driven by Hyprland raw events. `set` is the
// current sorted list of urgent addresses; the result is a fresh list.
function urgentAfter(set, eventName, address, focusedAddresses) {
  var out = Array.isArray(set) ? set.slice() : []
  var addr = String(address || "")
  var event = String(eventName || "")
  function drop(value) {
    var at = out.indexOf(value)
    if (at !== -1) out.splice(at, 1)
  }
  if (event === "urgent" && addr !== "") {
    if (out.indexOf(addr) === -1) out.push(addr)
  } else if ((event === "activewindowv2" || event === "closewindow" || event === "focusedmon") && addr !== "") {
    drop(addr)
  }
  var focused = Array.isArray(focusedAddresses) ? focusedAddresses : []
  for (var i = 0; i < focused.length; i++) drop(String(focused[i]))
  out.sort()
  return out
}

// Where the sliding focus bar sits: along the bottom edge of the focused
// button on a horizontal bar, along its right edge on a vertical one.
function focusGeometry(items, focusedId, vertical, thickness) {
  var list = Array.isArray(items) ? items : []
  var t = Math.max(1, Number(thickness) || 1)
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item || Number(item.id) !== Number(focusedId)) continue
    if (vertical) {
      return { x: item.x + item.width - t, y: item.y, width: t, height: item.height, visible: true }
    }
    return { x: item.x, y: item.y + item.height - t, width: item.width, height: t, visible: true }
  }
  return { x: 0, y: 0, width: 0, height: 0, visible: false }
}

// A monitor's geometry in the logical pixels Hyprland uses for window
// positions. `hyprctl monitors` gives physical width/height plus scale and a
// transform; odd transforms are 90/270 degree rotations.
function logicalMonitor(monitor) {
  if (!monitor || typeof monitor !== "object") return null
  var scale = Number(monitor.scale)
  if (!isFinite(scale) || scale <= 0) scale = 1
  var w = Math.round((Number(monitor.width) || 0) / scale)
  var h = Math.round((Number(monitor.height) || 0) / scale)
  var rotated = (Math.floor(Number(monitor.transform) || 0) % 2) === 1
  return {
    x: Number(monitor.x) || 0,
    y: Number(monitor.y) || 0,
    width: rotated ? h : w,
    height: rotated ? w : h,
    scale: scale
  }
}

// Hyprland spells window addresses two ways: events carry bare lowercase hex,
// `hyprctl clients` carries a 0x prefix. One key for both.
function normalizedAddress(value) {
  var text = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
  return text.indexOf("0x") === 0 ? text.substring(2) : text
}

// The windows a preview draws, from the IPC snapshots of one workspace's
// clients: only mapped, visible, positively sized ones, tiled before floating
// so floaters stack on top, capped so a pathological workspace cannot stall
// the bar with captures.
function isPair(value) {
  return value !== null && value !== undefined && typeof value === "object"
    && Number(value.length) >= 2 && value[0] !== undefined && value[1] !== undefined
}

function previewLayout(clients, limit) {
  var list = Array.isArray(clients) ? clients : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var o = list[i]
    // `at`/`size` arrive as JS arrays under Node but as Qt array-likes in
    // QML, so test for indexable pairs rather than Array.isArray.
    if (!o || !isPair(o.at) || !isPair(o.size)) continue
    if (o.hidden || o.mapped === false) continue
    var w = Number(o.size[0]), h = Number(o.size[1])
    if (!(w > 0) || !(h > 0)) continue
    out.push({
      address: String(o.address || ""),
      ax: Number(o.at[0]) || 0, ay: Number(o.at[1]) || 0,
      aw: w, ah: h,
      floating: !!o.floating,
      cls: String(o["class"] || ""),
      title: String(o.title || "")
    })
  }
  out.sort(function(a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0) })
  var cap = Math.max(0, Math.floor(Number(limit) || 0))
  return cap > 0 ? out.slice(0, cap) : out
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizedAddress: normalizedAddress,
    previewLayout: previewLayout,
    logicalMonitor: logicalMonitor,
    previewMode: previewMode,
    dominantClass: dominantClass,
    autoIconFor: autoIconFor,
    displayLabel: displayLabel,
    urgentAfter: urgentAfter,
    focusGeometry: focusGeometry,
    barName: barName,
    appEntryRows: appEntryRows,
    appsForClasses: appsForClasses,
    workspaceId: workspaceId,
    normalizedPinned: normalizedPinned,
    visibleWorkspaceIds: visibleWorkspaceIds,
    editableWorkspaceIds: editableWorkspaceIds,
    nextFreeId: nextFreeId,
    addedWorkspaceState: addedWorkspaceState,
    labelsWithout: labelsWithout,
    prunedLabels: prunedLabels,
    removedWorkspaceState: removedWorkspaceState
  }
}
