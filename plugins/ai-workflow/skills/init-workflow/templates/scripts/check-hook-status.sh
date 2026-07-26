#!/bin/sh
# Report whether the pre-push review gate is actually wired up, and why not
# if it isn't. Used by /init-workflow (deciding whether it's safe to offer
# git config core.hooksPath githooks) and by review-ok.sh (deciding whether
# to warn that the gate isn't active). Read-only — makes no changes.
#
# Resolves via `git rev-parse --git-path hooks/pre-push`, which accounts for
# core.hooksPath (set, unset, absolute, or relative), linked worktrees,
# submodules, and --separate-git-dir clones in one call — this is the exact
# location git will execute a pre-push hook from, so there is nothing left
# to hand-roll or compare against a literal path.
#
# Prints exactly one line, "VERDICT: detail":
#   ACTIVE              the gate is wired up and active — nothing to do
#   NEEDS_CHMOD         the active hook is this gate's file but lost +x
#   READY_TO_CONFIGURE  nothing is wired up, but githooks/pre-push is ready
#                       and core.hooksPath is unset — safe to set it
#   DEST_NEEDS_CHMOD    same, but githooks/pre-push itself lost +x
#   DEST_FOREIGN        nothing is wired up, and githooks/pre-push exists
#                       but isn't this gate's file
#   UNCONFIGURED        nothing is wired up, and githooks/pre-push is
#                       missing entirely
#   FOREIGN             something else (another hook manager, a leftover
#                       file, or core.hooksPath pointing elsewhere) already
#                       claims this — never overwrite or repoint here

set -eu

toplevel="$(git rev-parse --show-toplevel)"
resolved="$(git rev-parse --git-path hooks/pre-push)"
hooks_path_cfg="$(git config core.hooksPath || true)"

has_marker() {
    [ -f "$1" ] && grep -q '\.review-passed' "$1" 2>/dev/null
}

resolved_exec_marker=0
resolved_marker_only=0
if [ -x "$resolved" ] && has_marker "$resolved"; then
    resolved_exec_marker=1
elif has_marker "$resolved"; then
    resolved_marker_only=1
fi

dest="$toplevel/githooks/pre-push"
dest_exec_marker=0
dest_marker_only=0
dest_exists=0
if [ -e "$dest" ]; then
    dest_exists=1
    if [ -x "$dest" ] && has_marker "$dest"; then
        dest_exec_marker=1
    elif has_marker "$dest"; then
        dest_marker_only=1
    fi
fi

if [ "$resolved_exec_marker" = 1 ]; then
    echo "ACTIVE: $resolved"
    exit 0
fi

if [ "$resolved_marker_only" = 1 ]; then
    echo "NEEDS_CHMOD: $resolved"
    exit 0
fi

if [ -e "$resolved" ]; then
    echo "FOREIGN: something else is at $resolved (core.hooksPath=${hooks_path_cfg:-<unset>})"
    exit 0
fi

if [ -n "$hooks_path_cfg" ]; then
    echo "FOREIGN: core.hooksPath=$hooks_path_cfg but nothing resolves there (likely owned by another tool)"
    exit 0
fi

if [ "$dest_exec_marker" = 1 ]; then
    echo "READY_TO_CONFIGURE: githooks/pre-push is ready, offer git config core.hooksPath githooks"
    exit 0
fi

if [ "$dest_marker_only" = 1 ]; then
    echo "DEST_NEEDS_CHMOD: githooks/pre-push exists but is not executable"
    exit 0
fi

if [ "$dest_exists" = 1 ]; then
    echo "DEST_FOREIGN: githooks/pre-push exists but isn't this gate's file"
    exit 0
fi

echo "UNCONFIGURED: nothing anywhere, githooks/pre-push itself is missing"
