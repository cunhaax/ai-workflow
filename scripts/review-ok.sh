#!/bin/sh
# Record a passing code review for the current HEAD.
#
# The /feature workflow runs the code-reviewer sub-agent; after it passes with
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

sha="$(git rev-parse HEAD)"
echo "$sha" > "$(git rev-parse --show-toplevel)/.review-passed"
echo "Recorded review pass for commit $(git rev-parse --short HEAD)."
