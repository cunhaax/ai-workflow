#!/bin/sh
# Install or update the AI workflow template in a target repository.
#
# Run from a clone of the template:
#
#   scripts/install.sh /path/to/target-repo
#
# Two ownership classes decide what happens to each file:
#
#   template-owned  — the project-agnostic knowledge and enforcement layer
#                     (skills, sub-agents, git hook, review-ok.sh, the
#                     workflow guide). Copied on install, OVERWRITTEN on
#                     every re-run: updating = git pull in the template
#                     clone, then re-run this script.
#
#   project-owned   — everything a project fills in or extends (AGENTS.md,
#                     CLAUDE.md, docs/agent-rules/*, settings.json, the CI
#                     example, ADR/product-context scaffolding). Created
#                     only if missing, NEVER overwritten.
#
# The script is idempotent: re-running against an up-to-date target changes
# nothing and reports "unchanged"/"kept" for every file.

set -eu

die() {
    echo "install.sh: $*" >&2
    exit 1
}

TEMPLATE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

[ $# -eq 1 ] || die "usage: scripts/install.sh /path/to/target-repo"
[ -d "$1" ] || die "target directory not found: $1"
TARGET=$(CDPATH='' cd -- "$1" && pwd)

git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 \
    || die "target is not a git repository: $TARGET (the pre-push review gate needs one)"
[ "$TARGET" != "$TEMPLATE_DIR" ] || die "target is the template clone itself"

# --- helpers ---------------------------------------------------------------

copy_owned() { # $1 = repo-relative path; overwrite, preserving mode
    src="$TEMPLATE_DIR/$1"
    dst="$TARGET/$1"
    mkdir -p "$(dirname "$dst")"
    if [ ! -e "$dst" ]; then
        cp -p "$src" "$dst"
        echo "  installed  $1"
    elif cmp -s "$src" "$dst"; then
        echo "  unchanged  $1"
    else
        cp -p "$src" "$dst"
        echo "  updated    $1"
    fi
}

copy_if_missing() { # $1 = repo-relative path; never overwrite
    src="$TEMPLATE_DIR/$1"
    dst="$TARGET/$1"
    if [ -e "$dst" ]; then
        echo "  kept       $1 (project-owned)"
    else
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
        echo "  created    $1"
    fi
}

ensure_ignored() { # $1 = literal .gitignore line
    gi="$TARGET/.gitignore"
    [ -f "$gi" ] || : > "$gi"
    if ! grep -qxF "$1" "$gi"; then
        # ensure the file ends with a newline before appending
        [ ! -s "$gi" ] || [ -z "$(tail -c 1 "$gi")" ] || echo >> "$gi"
        printf '%s\n' "$1" >> "$gi"
        echo "  gitignore  added '$1'"
    fi
}

# --- template-owned: overwritten on every run ------------------------------

# A plain POSIX pipeline only surfaces the last stage's exit status, so a
# failing `find` below would be invisible — guard its roots up front instead.
[ -d "$TEMPLATE_DIR/.claude/skills" ] && [ -d "$TEMPLATE_DIR/.claude/agents" ] \
    || die "template clone is missing .claude/skills or .claude/agents — corrupted checkout?"

echo "Template-owned files (installed/updated):"

( CDPATH='' cd -- "$TEMPLATE_DIR" && find .claude/skills .claude/agents -type f ! -name '.DS_Store' ) \
| sort | while IFS= read -r f; do
    copy_owned "$f"
done

copy_owned "githooks/pre-push"
copy_owned "scripts/review-ok.sh"
copy_owned "docs/AI-workflow.md"

# --- project-owned: created once, then yours -------------------------------

echo "Project-owned files (created if missing):"

for f in \
    AGENTS.md \
    CLAUDE.md \
    .claude/settings.json \
    .github/workflows/ci.yml.example \
    docs/agent-rules/code-critic.md \
    docs/agent-rules/plan-critic.md \
    docs/adr/README.md \
    docs/adr/0001-record-architecture-decisions.md \
    docs/product-context/README.md
do
    copy_if_missing "$f"
done

ensure_ignored ".review-passed"
ensure_ignored ".qa-evidence/"

# --- version stamp ----------------------------------------------------------

if rev=$(git -C "$TEMPLATE_DIR" rev-parse --short HEAD 2>/dev/null); then
    printf '%s\n' "$rev" > "$TARGET/.claude/ai-workflow-template.rev"
    echo "Installed from template revision $rev (recorded in .claude/ai-workflow-template.rev" \
         "— commit that file with the install, so the repo history shows template updates)."
fi

# --- conditional warnings ---------------------------------------------------

if [ -f "$TARGET/CLAUDE.md" ] && ! grep -q '@AGENTS.md' "$TARGET/CLAUDE.md"; then
    echo "NOTE: $TARGET/CLAUDE.md does not import AGENTS.md — add a line containing" >&2
    echo "      '@AGENTS.md' so Claude Code (and its sub-agents) load the project guide." >&2
fi

if [ -f "$TARGET/.claude/settings.json" ] \
    && ! cmp -s "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"; then
    echo "NOTE: .claude/settings.json differs from the template version. It is" >&2
    echo "      project-owned so it was left alone — but the template's copy carries the" >&2
    echo "      review-gate permission rules (ask on review-ok.sh, deny on the bypass" >&2
    echo "      flags). Compare the two and merge anything missing:" >&2
    echo "      diff $TEMPLATE_DIR/.claude/settings.json $TARGET/.claude/settings.json" >&2
fi

if [ "$(git -C "$TARGET" config core.hooksPath || true)" != "githooks" ]; then
    echo "NOTE: the pre-push review gate is not active in the target clone. Enable it" >&2
    echo "      once per clone:  git -C $TARGET config core.hooksPath githooks" >&2
fi

# --- next steps ---------------------------------------------------------------

cat <<'EOF'

Done. If this was a first install, finish the adaptation:
  1. Fill in AGENTS.md — project overview, Commands (incl. app URL and
     default branch), Architecture, Testing, Sensitive Areas.
  2. Fill in docs/agent-rules/code-critic.md (project review rules + privacy
     anchors) and docs/agent-rules/plan-critic.md (product risk lenses).
  3. Rename .github/workflows/ci.yml.example to ci.yml and fill in the
     toolchain steps.
  4. Enable the review gate:  git config core.hooksPath githooks
To update later: git pull in the template clone, then re-run this script.
Project-owned files are never overwritten.
EOF
