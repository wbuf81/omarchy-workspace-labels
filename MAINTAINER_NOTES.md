# Maintainer Notes

This is the durable handoff for future releases. Keep details here that are
easy to lose between sessions; user-facing changes belong in `CHANGELOG.md`.

## Current state

- Manifest version prepared in this tree: **3.0.1**.
- Development branch: `main`.
- Release hardening was performed against **Omarchy 4.0.2-1** on September 1,
  2026.
- The repository had one pre-existing uncommitted fix when hardening began:
  workspace previews and occupancy now use `Hyprland.toplevels` instead of a
  workspace-local toplevel list that could omit sibling application windows.
- Confirm the remote GitHub release/tag state before publishing v3.0.1.

## Workspace-state contract

`Logic.js` is production code imported by `Workspaces.qml`, not a test-only
model. It owns normalization, visible/editor workspace unions, next-free-slot
selection, and add/remove state transitions. Keep it free of Qt APIs so
`tests/logic.test.js` can execute those exact decisions under Node.

The invariants are:

- Empty slots created by the plugin are limited to 1–20.
- Live Hyprland workspaces remain visible even above 20.
- Add selects the lowest free slot and stages it in `pinned` immediately.
- Rapid adds see the staged pin list rather than stale shell settings.
- Remove is inert while a workspace contains any window.
- Removing an empty workspace unpins it and deletes only its label.
- A saved label keeps an empty workspace in the editor until it is removed.
- Malformed pinned/label settings cannot create duplicate, fractional,
  negative, or arbitrarily high empty rows.

## Toplevel contract

Use the complete `Hyprland.toplevels.values` registry and filter each client's
`lastIpcObject.workspace.id`. Do not revert occupancy, app matching, or preview
capture to `workspace.toplevels.values`; that collection was observed to lag or
omit sibling surfaces when one application owns multiple windows.

## Verification status

Automated checks completed during the hardening pass:

- Node coverage for pinned migration, visible/editor unions, add selection,
  max capacity, rapid adds, occupied removal protection, unpinned-label
  removal, malformed IDs, and immutable result state.
- QML parser check with Qt's `qmlformat`.
- Omarchy's native `omarchy plugin validate`.
- Manifest, release asset, shell-script, integration-contract, and unresolved
  marker checks in `scripts/static-check.sh`.

The shell was not running at the beginning of this pass. Before tagging, use
the README's manual checklist to exercise real clicks, Hyprland dispatch, QML
focus, screencopy, and config persistence.

## Future version checklist

1. Add user-facing changes to `CHANGELOG.md`.
2. Update `manifest.json` and the expected version in
   `scripts/static-check.sh` together.
3. Run `./scripts/static-check.sh` during development.
4. Run `./scripts/release-check.sh` and the README's manual checks on Omarchy.
5. Update the tested-version badge when appropriate.
6. Commit the release, create the matching Git tag, and verify GitHub Actions.
7. Upload `docs/social-preview.png` under the repository's Social preview
   setting if its artwork changed.
