#!/usr/bin/env bash

# Restart the running Omarchy shell N times and fail if Quickshell dumps core.
# Startup is where the plugin's bindings first meet Quickshell's Hyprland IPC
# state, and two of the plugin's regressions only showed up there, one restart
# in three. Ten clean restarts is the bar before tagging a release.
set -euo pipefail

count="${1:-10}"
settle="${2:-9}"

if ! command -v coredumpctl >/dev/null || ! command -v omarchy >/dev/null; then
  echo "restart-soak needs coredumpctl and omarchy on this machine" >&2
  exit 2
fi

cores() { coredumpctl list quickshell --no-pager 2>/dev/null | grep -c '/usr/bin/quickshell' || true; }

before="$(cores)"
for i in $(seq 1 "$count"); do
  omarchy restart shell >/dev/null 2>&1
  sleep "$settle"
  now="$(cores)"
  if [[ "$now" -gt "$before" ]]; then
    echo "restart $i/$count: Quickshell dumped core (coredumpctl list quickshell)" >&2
    exit 1
  fi
  echo "restart $i/$count: clean"
done
echo "restart soak passed: $count restarts, no core dumps"
