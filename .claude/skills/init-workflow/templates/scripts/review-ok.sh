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

hooks_path="$(git config core.hooksPath || true)"
resolved="$hooks_path"
case "$hooks_path" in
    /*) : ;;                                            # already absolute
    "") resolved="" ;;
    *)  resolved="$(git rev-parse --show-toplevel)/$hooks_path" ;;
esac
if [ -z "$resolved" ] || [ ! -x "$resolved/pre-push" ]; then
    echo "WARNING: no active pre-push hook at core.hooksPath — the review gate is NOT active in this clone." >&2
    echo "Enable it once per clone: git config core.hooksPath githooks" >&2
fi

sha="$(git rev-parse HEAD)"
echo "$sha" > "$(git rev-parse --show-toplevel)/.review-passed"
echo "Recorded review pass for commit $(git rev-parse --short HEAD)."
