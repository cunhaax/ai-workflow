#!/bin/sh
# Computes the trustworthy parts of /feature's PR review guide. Read-only.
#
# Usage: sh review-guide.sh <default-branch> [<plan-file> | --plan-reapproved]
# Run inside the work tree. Prints markdown to stdout; /feature step 9 pastes
# it verbatim at the top of the PR's first comment.
#   <plan-file>        absolute path of the saved plan (.workflow-plans/<slug>.md
#                      under the main worktree; the caller passes it, nothing
#                      is resolved here)
#   --plan-reapproved  a --from-plan run was re-approved at step 2, so the saved
#                      plan is stale: the unplanned list is not computed
#   (no 2nd argument)  no plan file was saved
#
# Output, in order: a header (the base ref, origin/<default-branch> if it
# exists, else the local branch; merge-base; HEAD; the plan's basename, or
# "no plan file", "plan re-approved this run" or "plan file not readable");
# "Sensitive paths changed: <n> → floor 2" or "0 → none" (→ is U+2192), with
# the changed paths that match a Sensitive Area pattern; then, when they
# apply, the prose-only bullet count, "no patterns defined", mid-list bullets
# and patterns matching no file at HEAD; then "Unplanned changes", the changed
# paths the plan's "## Files" list did not name, and last "Unparsed plan Files
# bullets" if there are any. A part that cannot be computed says
# "not computed (<reason>)".
#
# Exit 0 whenever output was printed. Exit 1, "review-guide: <problem>" on
# stderr and nothing on stdout, for a usage error, no work tree, an
# unresolvable base, no merge-base or a failing git command.
#
# Changed paths: git diff --no-renames <merge-base> HEAD, so a rename is a
# delete plus an add (a planned MOVE lists both paths). Paths git still quotes
# (control characters, double quotes, backslashes) are a known limitation.
#
# Plan parsing: skip the leading frontmatter; ignore fenced blocks; stop at a
# line starting "# Plan-critic review"; read the "## Files" section's
# column-0 bullets "- NEW|EDIT|DELETE|MOVE <path>" (first backticked token,
# else first bare token; MOVE takes both paths). Other bullets are "unparsed".
#
# Sensitive Areas: the "## Sensitive Areas" section of AGENTS.md, in both the
# merge-base and HEAD versions, so the floor only goes up. Each column-0 bullet
# starts with its path pattern(s) in backticks, separated by "," or " / " or a
# space; only that leading run counts. Patterns are repo-relative and anchored
# at the repo root (a bare name matches only at the root; use */name for any
# depth). A pattern also covers everything under it. * matches any characters
# including /; ? and [...] work as in a shell, byte-wise (LC_ALL=C); ** matches
# zero or more directories (a/**/b matches a/b). A bullet with no leading pattern is
# "prose-only": counted, not checked. A pattern matching no file at HEAD is
# listed, since a typo would otherwise under-report silently.
#
# The awk is POSIX awk without regex intervals or character classes: mawk
# (the default on Debian and Ubuntu) does not support them.
#
# Known limitations: if AGENTS.md is a symlink, git show prints the link
# target and no patterns are found (the output says so); fence tracking
# ignores marker type and length, so nested fences in a plan can end a skip
# early; the zero-match check is a shell loop over patterns x files, slow on
# very large repos; only tested with macOS awk.

set -eu
LC_ALL=C
export LC_ALL

die() {
    echo "review-guide: $*" >&2
    exit 1
}

[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: sh review-guide.sh <default-branch> [<plan-file>|--plan-reapproved]"
base_name=$1
plan_arg=${2-}
tab=$(printf '\t')

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"
if git rev-parse --verify -q "refs/remotes/origin/$base_name^{commit}" >/dev/null 2>&1; then
    ref="origin/$base_name"
elif git rev-parse --verify -q "$base_name^{commit}" >/dev/null 2>&1; then
    ref=$base_name
else
    die "cannot resolve base '$base_name'"
fi
mb=$(git merge-base "$ref" HEAD 2>/dev/null) || die "no merge base between $ref and HEAD"
mb_short=$(git rev-parse --short "$mb") || die "cannot resolve merge base"
head_short=$(git rev-parse --short HEAD) || die "cannot resolve HEAD"
changed=$(git -c core.quotepath=off -c diff.relative=false diff --no-renames --name-only "$mb" HEAD) || die "git diff failed"
files=$(git -c core.quotepath=off ls-tree -r --full-tree --name-only HEAD) || die "git ls-tree failed"

parse_areas() {
    awk '
    function emit(tok, disp,    g1, g2) {
        sub(/^\.\//, "", tok); sub(/^\//, "", tok); sub(/\/+$/, "", tok)
        if (tok == "") return
        g1 = tok; gsub(/\*\*/, "*", g1)
        g2 = tok; gsub(/\/\*\*\//, "/", g2); sub(/^\*\*\//, "", g2); gsub(/\*\*/, "*", g2)
        print "P\t" disp "\t" g1 "\t" g2
    }
    function bullet(text,    e, tok, n, last, sep) {
        sub(/^ +/, "", text)
        if (substr(text, 1, 5) == "[TODO") return
        if (substr(text, 1, 1) != "`") { prose++; return }
        while (substr(text, 1, 1) == "`") {
            e = index(substr(text, 2), "`")
            if (e == 0) break
            tok = substr(text, 2, e - 1); text = substr(text, e + 2)
            if (tok ~ /^\[TODO/) return
            if (tok != "") { emit(tok, tok); n++; last = tok }
            sep = 0
            if (match(text, /^ *, */)) sep = 1
            else if (match(text, /^ +\/ +/)) sep = 1
            else if (match(text, /^ +\/ *$/)) sep = 1
            else if (match(text, /^ +/)) sep = 0
            else break
            text = substr(text, RLENGTH + 1)
        }
        if (sep && text == "" && n > 0) print "M\t" last
    }
    {
        line = $0; out = ""
        while (1) {
            if (cm) {
                i = index(line, "-->")
                if (i == 0) { line = ""; break }
                line = substr(line, i + 3); cm = 0
            } else {
                i = index(line, "<!--")
                if (i == 0) break
                out = out substr(line, 1, i - 1); line = substr(line, i + 4); cm = 1
            }
        }
        line = out line
    }
    line ~ /^## Sensitive Areas/ { sec = 1; next }
    line ~ /^## / { sec = 0; next }
    sec && line ~ /^[-*] / { bullet(substr(line, 3)) }
    END { print "X\t" prose + 0 }
    '
}

parse_plan() {
    awk '
    function entry(l,    t, tag, rest, p1, p2, a, n, i, q) {
        if (!match(l, /^[-*] +(NEW|EDIT|DELETE|MOVE) +/)) { bad++; return }
        t = substr(l, RSTART, RLENGTH); rest = substr(l, RLENGTH + 1)
        sub(/^[-*] +/, "", t); sub(/ +$/, "", t); tag = t
        if (substr(rest, 1, 1) == "`") {
            q = index(substr(rest, 2), "`")
            if (q > 0) { p1 = substr(rest, 2, q - 1); rest = substr(rest, q + 2) }
            if (tag == "MOVE" && (q = index(rest, "`")) > 0) {
                rest = substr(rest, q + 1)
                if ((q = index(rest, "`")) > 0) p2 = substr(rest, 1, q - 1)
            }
        } else {
            n = split(rest, a, / +/)
            p1 = a[1]; sub(/:$/, "", p1)
            if (tag == "MOVE") for (i = 1; i < n; i++) if (a[i] == "→") { p2 = a[i + 1]; sub(/:$/, "", p2); break }
        }
        sub(/^\.\//, "", p1); sub(/^\.\//, "", p2)
        if (p1 == "") { bad++; return }
        parsed++; print "F\t" p1
        if (p2 != "") print "F\t" p2
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm { if ($0 == "---") fm = 0; next }
    $0 ~ /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    $0 ~ /^# Plan-critic review/ { exit }
    $0 ~ /^#+ / {
        if (sec) { sec = 0; done = 1 }
        if (!done && $0 ~ /^## Files([ \t].*)?$/) { sec = 1; seen = 1 }
        next
    }
    sec && $0 ~ /^[-*] / { entry($0) }
    END { print "S\t" seen + 0 "\t" parsed + 0 "\t" bad + 0 }
    '
}

# matches <path> <glob>: the glob names the path or a parent of it
matches() {
    case $1 in
    $2 | $2/*) return 0 ;;
    esac
    return 1
}

head_rec=""
base_rec=""
if git cat-file -e HEAD:AGENTS.md 2>/dev/null; then
    head_rec=$(git show HEAD:AGENTS.md | parse_areas)
fi
if git cat-file -e "$mb:AGENTS.md" 2>/dev/null; then
    base_rec=$(git show "$mb:AGENTS.md" | parse_areas)
fi
pats=$(printf '%s\n%s\n' "$head_rec" "$base_rec" | grep '^P' | sort -u || true)
prose=$(printf '%s\n' "$head_rec" | awk -F'\t' '$1 == "X" { n = $2 } END { print n + 0 }')
mids=$(printf '%s\n' "$head_rec" | awk -F'\t' '$1 == "M" { print $2 }')

hits=""
nhits=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    found=0
    while IFS=$tab read -r kind disp g1 g2; do
        [ "$kind" = P ] && [ "$found" = 0 ] || continue
        if matches "$p" "$g1" || matches "$p" "$g2"; then
            found=1
            hits="$hits- \`$p\` matches \`$disp\`
"
            nhits=$((nhits + 1))
        fi
    done <<EOF
$pats
EOF
done <<EOF
$changed
EOF

zero=""
while IFS=$tab read -r kind disp g1 g2; do
    [ "$kind" = P ] || continue
    found=0
    while IFS= read -r f; do
        if matches "$f" "$g1" || matches "$f" "$g2"; then
            found=1
            break
        fi
    done <<EOF
$files
EOF
    [ "$found" = 1 ] || zero="${zero}Pattern matches no file at HEAD: \`$disp\`
"
done <<EOF
$pats
EOF

plan_label="no plan file"
reason="no plan file"
planned=""
unparsed=0
case $plan_arg in
"") ;;
--plan-reapproved)
    plan_label="plan re-approved this run"
    reason="plan re-approved this run; the saved plan is the pre-deviation version"
    ;;
*)
    if [ -f "$plan_arg" ] && [ -r "$plan_arg" ]; then
        plan_label="plan \`$(basename "$plan_arg")\`"
        rec=$(parse_plan <"$plan_arg")
        seen=$(printf '%s\n' "$rec" | awk -F'\t' '$1 == "S" { print $2 }')
        parsed=$(printf '%s\n' "$rec" | awk -F'\t' '$1 == "S" { print $3 }')
        unparsed=$(printf '%s\n' "$rec" | awk -F'\t' '$1 == "S" { print $4 }')
        if [ "$seen" != 1 ]; then
            reason='no "## Files" section in the plan text'
        elif [ "$parsed" = 0 ]; then
            reason='no parseable entries in "## Files"'
        else
            reason=""
            planned=$(printf '%s\n' "$rec" | awk -F'\t' '$1 == "F" { print $2 }')
        fi
    else
        plan_label="plan file not readable"
        reason="plan file not readable"
    fi
    ;;
esac

out="**Computed by review-guide.sh** — base \`$ref\` · merge-base \`$mb_short\` · HEAD \`$head_short\` · $plan_label

"
if [ "$nhits" -gt 0 ]; then
    out="${out}Sensitive paths changed: $nhits → floor 2
$hits"
else
    out="${out}Sensitive paths changed: 0 → none
"
fi
[ "$prose" = 0 ] || out="${out}Not path-checked: $prose prose-only Sensitive Areas bullet(s)
"
[ -z "$pats" ] && out="${out}No Sensitive Area patterns defined; not re-checked
"
[ -z "$mids" ] || out="${out}$(printf '%s\n' "$mids" | while IFS= read -r m; do printf 'Sensitive Areas bullet ends mid-list: `%s`\n' "$m"; done)
"
out="$out$zero
"
if [ -n "$reason" ]; then
    out="${out}Unplanned changes: not computed ($reason)
"
else
    unplanned=""
    nun=0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        if ! printf '%s\n' "$planned" | grep -Fxq -- "$p"; then
            unplanned="$unplanned- \`$p\`
"
            nun=$((nun + 1))
        fi
    done <<EOF
$changed
EOF
    if [ "$nun" -gt 0 ]; then
        out="${out}Unplanned changes ($nun):
$unplanned"
    else
        out="${out}Unplanned changes: none
"
    fi
    [ "$unparsed" = 0 ] || out="${out}Unparsed plan Files bullets: $unparsed
"
fi
printf '%s' "$out"
