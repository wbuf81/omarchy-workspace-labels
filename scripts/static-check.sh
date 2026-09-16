#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

jq -e '
  .schemaVersion == 1 and
  .id == "io.github.wbuf81.workspace-labels" and
  .version == "3.2.2" and
  .license == "MIT" and
  .kinds == ["bar-widget"] and
  .entryPoints.barWidget == "Workspaces.qml" and
  .barWidget.allowMultiple == false and
  .barWidget.defaultSection == "left" and
  .barWidget.defaults.hoverPreview == true and
  (.barWidget.defaults.pinned | length) == 5
' manifest.json >/dev/null

for required in Workspaces.qml BarButton.qml EditorPanel.qml IconPicker.qml PreviewCard.qml \
  WindowTile.qml Caption.qml Rule.qml Mark.qml BlockCursor.qml CornerFrame.qml \
  FlipBoard.qml FlipStep.qml Logic.js README.md CHANGELOG.md CONTRIBUTING.md \
  MAINTAINER_NOTES.md LICENSE docs/bar.png docs/editor.png docs/picker.png \
  docs/preview.png docs/social-preview.png preview.png \
  assets/social/share-card-background.png; do
  test -s "$required"
done

dimensions="$(identify -format '%wx%h' docs/social-preview.png)"
test "$dimensions" = "1280x640"
test "$(stat -c %s docs/social-preview.png)" -lt 1048576
cmp -s preview.png docs/social-preview.png

# These are release-critical integration contracts, not style preferences.
rg -q 'import "Logic.js" as Logic' Workspaces.qml
rg -q 'Logic\.addedWorkspaceState' Workspaces.qml
rg -q 'Logic\.removedWorkspaceState' Workspaces.qml
rg -q 'Hyprland\.toplevels\.values' Workspaces.qml
# Omarchy 4.0.3 withholds the shell's AppLibrary from bar-widget plugins, so
# app icons must come straight from Quickshell's desktop-entry registry.
rg -q 'DesktopEntries\.applications\.values' Workspaces.qml
rg -q 'Logic\.appsForClasses' Workspaces.qml
rg -q 'Logic\.barName' BarButton.qml
rg -q 'Logic\.previewMode' Workspaces.qml
rg -q 'Logic\.displayLabel' Workspaces.qml
rg -q 'Logic\.urgentAfter' Workspaces.qml
rg -q 'Logic\.focusGeometry' Workspaces.qml
if rg -q 'shell\.appLibrary' -- *.qml; then
  echo "Static check failed: shell.appLibrary is null for bar widgets on Omarchy 4.0.3" >&2
  exit 1
fi
if rg -q 'workspace\.toplevels\.values|ws\.toplevels\.values' Workspaces.qml; then
  echo "Static check failed: workspace-local toplevel registry reintroduced" >&2
  exit 1
fi

bash -n scripts/build-social-card.sh scripts/dev-sync.sh scripts/release-check.sh scripts/restart-soak.sh scripts/static-check.sh
node tests/logic.test.js

# qmlformat parses the complete file before producing output. It is available
# on Omarchy but intentionally optional in the portable GitHub Actions job.
qmlformat_bin="$(command -v qmlformat || true)"
for candidate in /usr/lib/qt6/bin/qmlformat /usr/lib/x86_64-linux-gnu/qt6/bin/qmlformat /usr/lib/qt6/libexec/qmlformat; do
  if [[ -z $qmlformat_bin && -x $candidate ]]; then qmlformat_bin=$candidate; fi
done
if [[ -n $qmlformat_bin ]]; then
  for qml in *.qml; do "$qmlformat_bin" -n "$qml" >/dev/null; done
elif [[ -n ${CI:-} ]]; then
  echo "Static check failed: qmlformat is required in CI so every QML file is parsed" >&2
  exit 1
fi
# qmllint is deliberately not run: the `qs.Ui` / `qs.Commons` modules only
# exist inside the running shell's engine, so every file reports unresolved
# imports and the real errors would drown in that noise.

if rg -n '(^|[^[:alpha:]])(TODO|FIXME|HACK)([^[:alpha:]]|$)' \
  --glob '*.qml' --glob '*.js' --glob '*.sh' --glob '!scripts/static-check.sh' .; then
  echo "Static check failed: unresolved marker" >&2
  exit 1
fi

echo "static checks passed"
