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
  cores_before="$(coredumpctl list quickshell --no-pager 2>/dev/null | grep -c '/usr/bin/quickshell' || true)"
  sleep 4
  omarchy restart shell
  # A startup crash relaunches the shell silently apart from a desktop
  # notification; surface it here where the edit that caused it is visible.
  sleep 10
  cores_after="$(coredumpctl list quickshell --no-pager 2>/dev/null | grep -c '/usr/bin/quickshell' || true)"
  if [[ "$cores_after" -gt "$cores_before" ]]; then
    echo "Synced $plugin_id, but Quickshell dumped core on restart. See: coredumpctl list quickshell" >&2
    exit 1
  fi
  echo "Synced $plugin_id and restarted the shell (no core dump within 10 s)."
else
  echo "Synced $plugin_id. Source edits need 'omarchy restart shell' (or pass --restart)."
fi
