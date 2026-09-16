#!/usr/bin/env bash

# Copy this working tree into Omarchy's user-plugin directory and make the
# shell rescan it. Omarchy intentionally rejects plugin symlinks, so copying
# is the supported local-development workflow.
set -euo pipefail

plugin_id="io.github.wbuf81.workspace-labels"
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$HOME/.config/omarchy/plugins/$plugin_id"
enable=false
restart=false

for arg in "$@"; do
  case "$arg" in
    --enable) enable=true ;;
    # Omarchy 4.0.3 logs a reload after a sync but keeps the previously
    # compiled QML, so source edits only show after a shell restart. The
    # pause lets the hot-reload settle first; restarting mid-reload has
    # segfaulted Quickshell.
    --restart) restart=true ;;
    *) echo "Usage: $0 [--enable] [--restart]" >&2; exit 2 ;;
  esac
done

omarchy plugin validate "$source_dir"
mkdir -p "$target_dir"
rsync -a --delete --exclude '.git/' --exclude '.gitignore' "$source_dir/" "$target_dir/"
omarchy-shell shell rescanPlugins

if "$enable"; then
  omarchy plugin enable "$plugin_id" --section left
fi

if "$restart"; then
  sleep 4
  omarchy restart shell
  echo "Synced $plugin_id and restarted the shell."
else
  echo "Synced $plugin_id. Source edits need 'omarchy restart shell' (or pass --restart)."
fi
