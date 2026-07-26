#!/bin/sh
# Report whether the pre-push review gate is actually wired up, and why not
# if it isn't. Used by /init-workflow (deciding whether it's safe to offer
# git config core.hooksPath githooks) and by review-ok.sh (deciding whether
# to warn that the gate isn't active). Read-only — makes no changes.
#
# IMPORTANT: the literal string "DEST_FOREIGN" below doubles as this
# file's own identity marker in /init-workflow's SKILL.md (Step 1 and
# Step 5 item 1 grep for it to confirm a scripts/check-hook-status.sh
# found on disk is genuinely this file, not something else at that path).
# Do not rename or stop using this string without updating both call
# sites — this is exactly the kind of edit that silently invalidated the
# previous marker choice.
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
#   DEST_NEEDS_CHMOD    same, but githooks/pre-push itself lost +x — this
#                       can also fire with core.hooksPath already set to
#                       this project's own githooks/ dir
#   DEST_FOREIGN        nothing is wired up, and githooks/pre-push exists
#                       but isn't this gate's file (also reachable with
#                       core.hooksPath already = githooks)
#   UNCONFIGURED        nothing is wired up, and githooks/pre-push is
#                       missing entirely (also reachable with
#                       core.hooksPath already = githooks)
#   FOREIGN             something else (another hook manager, a leftover
#                       file, or core.hooksPath pointing at a directory
#                       that isn't this project's own githooks/) already
#                       claims this — never overwrite or repoint here.
#                       core.hooksPath already equal to this project's own
#                       githooks/ dir is never reported as FOREIGN, even
#                       when nothing is scaffolded there yet — that's our
#                       own conventional value, not another tool's

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

# core.hooksPath already pointing at THIS project's own githooks/ dir is
# not foreign, even if nothing has been scaffolded there yet — it's this
# gate's own conventional value, half-configured, not another tool's.
# Known limitation: this compares against $toplevel of the worktree the
# script runs in, so a linked worktree that inherits a relative
# core.hooksPath resolved against a *different* worktree's toplevel (rare —
# most real configs use an absolute path here, which this handles
# correctly) can still misreport FOREIGN; not solved here.
own_hooks_dir="$toplevel/githooks"
hooks_path_is_own=0
if [ -z "$hooks_path_cfg" ]; then
    hooks_path_is_own=1
else
    # Normalize a leading "./" and any trailing "/" before comparing —
    # git accepts "./githooks" and "githooks/" as equivalent to
    # "githooks", but a literal string comparison would not.
    normalized="${hooks_path_cfg#./}"
    normalized="${normalized%/}"
    case "$normalized" in
        /*) cfg_dir="$normalized" ;;
        *)  cfg_dir="$toplevel/$normalized" ;;
    esac
    [ "$cfg_dir" = "$own_hooks_dir" ] && hooks_path_is_own=1
fi

if [ "$hooks_path_is_own" = 0 ]; then
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
