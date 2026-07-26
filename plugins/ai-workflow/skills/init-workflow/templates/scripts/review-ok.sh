#!/bin/sh
# Record a passing code review for the current HEAD.
#
# The /feature workflow runs the code-critic sub-agent; after it passes with
# no FAIL items, run this script to write the reviewed commit SHA to
# .review-passed (gitignored, one per worktree). The pre-push hook
# (githooks/pre-push) refuses to push any commit that does not match it, so any
# commit made after the review forces a re-review.
#
# Never run this without a passing review of the current HEAD.
#
# If your project has a task runner, wire this up as a target/recipe
# (e.g. `make review-ok`) that calls this script.

set -eu

status="$("$(git rev-parse --show-toplevel)/scripts/check-hook-status.sh" 2>/dev/null)" || status="UNKNOWN: scripts/check-hook-status.sh is missing or not executable"
case "$status" in
    ACTIVE:*) : ;;
    READY_TO_CONFIGURE:*)
        echo "WARNING: pre-push review gate is not active in this clone ($status)" >&2
        echo "Enable it once per clone: git config core.hooksPath githooks" >&2
        ;;
    *)
        echo "WARNING: pre-push review gate is not active in this clone ($status)" >&2
        echo "Run /init-workflow (doctor mode) to diagnose and fix this." >&2
        ;;
esac

sha="$(git rev-parse HEAD)"
echo "$sha" > "$(git rev-parse --show-toplevel)/.review-passed"
echo "Recorded review pass for commit $(git rev-parse --short HEAD)."
