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

if (typeof module !== "undefined") {
  module.exports = {
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
