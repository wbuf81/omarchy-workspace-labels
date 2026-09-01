#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

jq -e '
  .schemaVersion == 1 and
  .id == "io.github.wbuf81.workspace-labels" and
  .version == "3.0.1" and
  .license == "MIT" and
  .kinds == ["bar-widget"] and
  .entryPoints.barWidget == "Workspaces.qml" and
  .barWidget.allowMultiple == false and
  .barWidget.defaultSection == "left" and
  .barWidget.defaults.hoverPreview == true and
  (.barWidget.defaults.pinned | length) == 5
' manifest.json >/dev/null

for required in Workspaces.qml Logic.js README.md CHANGELOG.md CONTRIBUTING.md \
  MAINTAINER_NOTES.md LICENSE docs/bar.png docs/editor.png docs/picker.png \
  docs/preview.png docs/social-preview.png assets/social/share-card-background.png; do
  test -s "$required"
done

dimensions="$(identify -format '%wx%h' docs/social-preview.png)"
test "$dimensions" = "1280x640"
test "$(stat -c %s docs/social-preview.png)" -lt 1048576

# These are release-critical integration contracts, not style preferences.
rg -q 'import "Logic.js" as Logic' Workspaces.qml
rg -q 'Logic\.addedWorkspaceState' Workspaces.qml
rg -q 'Logic\.removedWorkspaceState' Workspaces.qml
rg -q 'Hyprland\.toplevels\.values' Workspaces.qml
if rg -q 'workspace\.toplevels\.values|ws\.toplevels\.values' Workspaces.qml; then
  echo "Static check failed: workspace-local toplevel registry reintroduced" >&2
  exit 1
fi

bash -n scripts/build-social-card.sh scripts/dev-sync.sh scripts/release-check.sh scripts/static-check.sh
node tests/logic.test.js

# qmlformat parses the complete file before producing output. It is available
# on Omarchy but intentionally optional in the portable GitHub Actions job.
qmlformat_bin="$(command -v qmlformat || true)"
if [[ -z $qmlformat_bin && -x /usr/lib/qt6/bin/qmlformat ]]; then
  qmlformat_bin=/usr/lib/qt6/bin/qmlformat
fi
if [[ -n $qmlformat_bin ]]; then
  "$qmlformat_bin" -n Workspaces.qml >/dev/null
fi

if rg -n '(^|[^[:alpha:]])(TODO|FIXME|HACK)([^[:alpha:]]|$)' \
  --glob '*.qml' --glob '*.js' --glob '*.sh' --glob '!scripts/static-check.sh'; then
  echo "Static check failed: unresolved marker" >&2
  exit 1
fi

echo "static checks passed"
