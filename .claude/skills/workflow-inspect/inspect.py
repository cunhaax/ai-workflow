"""Compute the cost half of a workflow-retro record from Claude Code transcripts.

Usage:
    python3 inspect.py SESSION_ID [SESSION_ID ...]

Reads the session transcript(s) plus the sub-agent transcripts they spawned,
and prints a markdown "## Cost" section to stdout. Read-only: never writes
or modifies anything.

The transcript format is Claude Code internal, undocumented behavior. This
script fails soft: anything it cannot parse is counted and reported, never
silently dropped, and a missing file becomes a warning line instead of an
error. Numbers are therefore lower bounds whenever warnings are present.
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
TS_MIN = datetime.min.replace(tzinfo=timezone.utc)


def parse_ts(ts):
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def fmt_duration(seconds):
    seconds = int(seconds)
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m{s:02d}s"


def fmt_tokens(n):
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n)


def iter_records(path, unparsed):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                unparsed[str(path)] = unparsed.get(str(path), 0) + 1
                continue
            if isinstance(rec, dict):
                yield rec
            else:
                unparsed[str(path)] = unparsed.get(str(path), 0) + 1


class Tally:
    def __init__(self):
        self.messages = 0
        self.output = 0
        self.cache_read = 0
        self.cache_create = 0
        self.first_ts = None
        self.last_ts = None

    def add(self, rec):
        ts = parse_ts(rec.get("timestamp"))
        if ts:
            if self.first_ts is None or ts < self.first_ts:
                self.first_ts = ts
            if self.last_ts is None or ts > self.last_ts:
                self.last_ts = ts
        usage = (rec.get("message") or {}).get("usage")
        if usage:
            self.messages += 1
            self.output += usage.get("output_tokens") or 0
            self.cache_read += usage.get("cache_read_input_tokens") or 0
            self.cache_create += usage.get("cache_creation_input_tokens") or 0

    @property
    def duration(self):
        if self.first_ts and self.last_ts:
            return (self.last_ts - self.first_ts).total_seconds()
        return 0


def tool_uses(rec):
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                yield block


def main():
    session_ids = sys.argv[1:]
    if not session_ids:
        print(__doc__, file=sys.stderr)
        sys.exit(2)

    warnings = []
    unparsed = {}

    # -- locate and load the main transcripts, deduped by record uuid --------
    records = {}          # uuid -> record (uuid-less records get a synthetic key)
    versions = set()
    found_sessions = []
    for sid in session_ids:
        matches = sorted(PROJECTS_DIR.glob(f"*/{sid}.jsonl"))
        if not matches:
            warnings.append(f"session {sid}: transcript not found (pruned?) — "
                            f"its cost is missing from every number below")
            continue
        found_sessions.append(sid)
        for path in matches:
            try:
                for i, rec in enumerate(iter_records(path, unparsed)):
                    key = rec.get("uuid") or f"{path}:{i}"
                    records.setdefault(key, rec)
            except OSError as e:
                warnings.append(f"session {sid}: could not read {path.name} "
                                f"({e}) — its cost is missing")

    if not records:
        print("No transcript data found for any given session ID.", file=sys.stderr)
        sys.exit(1)

    # -- main chain: totals, spawn markers, plan-approval marker, reads ------
    main_tally = Tally()
    spawns = []           # dicts: tool_use_id, type, desc, ts
    main_reads = []       # (ts, file_path)
    exit_plan_ts = None
    bad_records = 0       # records with unexpected shapes, skipped fail-soft
    for rec in records.values():
        if rec.get("isSidechain"):
            continue
        try:
            if rec.get("version"):
                versions.add(rec["version"])
            main_tally.add(rec)
            ts = parse_ts(rec.get("timestamp"))
            for block in tool_uses(rec):
                name = block.get("name")
                inp = block.get("input") or {}
                if name in ("Agent", "Task"):
                    spawns.append({
                        "tool_use_id": block.get("id"),
                        "type": inp.get("subagent_type", "?"),
                        "desc": (inp.get("description") or "")[:60],
                        "ts": ts,
                    })
                elif name == "Read" and inp.get("file_path"):
                    main_reads.append((ts, inp["file_path"]))
                elif name == "ExitPlanMode" and exit_plan_ts is None:
                    exit_plan_ts = ts
        except Exception:
            bad_records += 1

    # -- resolve each spawn's sub-agent transcript by toolUseId, globally ----
    meta_index = {}       # toolUseId -> (meta dict, jsonl path, owning session id)
    for meta_path in PROJECTS_DIR.glob("*/*/subagents/agent-*.meta.json"):
        try:
            meta = json.loads(meta_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        tuid = meta.get("toolUseId")
        if tuid:
            meta_index[tuid] = (meta, meta_path.with_suffix("").with_suffix(".jsonl"),
                                meta_path.parent.parent.name)

    agent_rows = []       # per spawn: label, model, tally, reads, note
    related_sessions = set()
    for spawn in sorted(spawns, key=lambda s: s["ts"] or TS_MIN):
        entry = meta_index.get(spawn["tool_use_id"])
        row = {"label": spawn["type"], "desc": spawn["desc"], "ts": spawn["ts"],
               "model": "", "tally": Tally(), "reads": set(), "note": ""}
        if entry is None:
            row["note"] = "sub-agent transcript not found"
            warnings.append(f"{spawn['type']} ({spawn['desc']}): sub-agent "
                            f"transcript not found — its cost is missing")
        else:
            meta, jsonl_path, owner_sid = entry
            row["model"] = meta.get("model", "")
            if owner_sid not in session_ids:
                related_sessions.add(owner_sid)
            if jsonl_path.exists():
                try:
                    for rec in iter_records(jsonl_path, unparsed):
                        try:
                            row["tally"].add(rec)
                            for block in tool_uses(rec):
                                if block.get("name") == "Read" and (block.get("input") or {}).get("file_path"):
                                    row["reads"].add(block["input"]["file_path"])
                        except Exception:
                            bad_records += 1
                except OSError as e:
                    row["note"] = "transcript unreadable"
                    warnings.append(f"{spawn['type']}: could not read "
                                    f"{jsonl_path.name} ({e}) — its cost is missing")
            else:
                row["note"] = "meta found but transcript file missing"
                warnings.append(f"{spawn['type']}: agent meta found but "
                                f"{jsonl_path.name} is missing — its cost is missing")
        agent_rows.append(row)

    if related_sessions:
        warnings.append(
            "some sub-agent transcripts belong to session(s) not listed in the "
            "retro record: " + ", ".join(sorted(related_sessions)) +
            " — the feature likely spanned these too (resumed sessions carry "
            "history over); consider adding them to the record's Sessions line")

    # -- derived numbers ------------------------------------------------------
    agent_output = sum(r["tally"].output for r in agent_rows)
    total_output = main_tally.output + agent_output
    share = round(100 * agent_output / total_output) if total_output else 0

    # Handoff tax cutoff = the LAST planner spawn: what matters is drift after
    # the final plan; anchoring earlier would count inter-replan reads as tax.
    planner_reads = set()
    planner_spawn_ts = None
    planner_runs = 0
    for r in agent_rows:
        if r["label"] == "planner":
            planner_runs += 1
            planner_reads |= r["reads"]
            if r["ts"] and (planner_spawn_ts is None or r["ts"] > planner_spawn_ts):
                planner_spawn_ts = r["ts"]
    reread = set()
    if planner_reads:
        after = planner_spawn_ts or TS_MIN
        reread = {fp for ts, fp in main_reads
                  if fp in planner_reads and (ts is None or ts >= after)}

    # -- emit the Cost section ------------------------------------------------
    out = []
    today = main_tally.last_ts.date().isoformat() if main_tally.last_ts else "?"
    out.append("## Cost")
    out.append("")
    out.append(f"- Inspected: {today}; sessions parsed: {', '.join(found_sessions)}; "
               f"claude-code version(s): {', '.join(sorted(versions)) or '?'}")
    if main_tally.first_ts and main_tally.last_ts:
        out.append(f"- Wall-clock: {main_tally.first_ts.strftime('%Y-%m-%d %H:%M')} → "
                   f"{main_tally.last_ts.strftime('%Y-%m-%d %H:%M')} UTC "
                   f"({fmt_duration(main_tally.duration)}, includes idle time)")
    out.append(f"- Main agent: {main_tally.messages} assistant messages; "
               f"output {fmt_tokens(main_tally.output)} tokens; "
               f"cache read {fmt_tokens(main_tally.cache_read)}; "
               f"cache write {fmt_tokens(main_tally.cache_create)}")
    out.append("- Sub-agents:")
    out.append("")
    out.append("  | Agent | Model | Output | Cache read | Duration | Msgs | Files read |")
    out.append("  |-------|-------|--------|------------|----------|------|------------|")
    for r in agent_rows:
        t = r["tally"]
        if r["note"]:
            out.append(f"  | {r['label']} | ? | — | — | — | — | — ({r['note']}) |")
        else:
            out.append(f"  | {r['label']} | {r['model'] or 'default'} | "
                       f"{fmt_tokens(t.output)} | {fmt_tokens(t.cache_read)} | "
                       f"{fmt_duration(t.duration)} | {t.messages} | {len(r['reads'])} |")
    out.append("")
    out.append(f"- Sub-agent share of output tokens: {share}% "
               f"({fmt_tokens(agent_output)} of {fmt_tokens(total_output)})")
    if planner_reads:
        runs_note = ("" if planner_runs == 1 else
                     f" (approximate — {planner_runs} planner runs, reads "
                     f"counted only after the last one)")
        out.append(f"- Handoff tax: planner read {len(planner_reads)} files; the main "
                   f"agent re-read {len(reread)} of them after the planner ran"
                   f"{runs_note}" + (":" if reread else ""))
        for fp in sorted(reread):
            out.append(f"  - {fp}")
    else:
        out.append("- Handoff tax: not computed (no planner sub-agent transcript found)")
    if exit_plan_ts:
        out.append(f"- Plan approved (ExitPlanMode): {exit_plan_ts.strftime('%H:%M')} UTC")
    total_unparsed = sum(unparsed.values())
    if total_unparsed:
        warnings.append(f"{total_unparsed} unparseable line(s) across "
                        f"{len(unparsed)} file(s) — numbers are lower bounds")
    if bad_records:
        warnings.append(f"{bad_records} record(s) with unexpected shapes were "
                        f"skipped — numbers are lower bounds")
    if warnings:
        out.append("- Warnings:")
        for w in warnings:
            out.append(f"  - {w}")
    print("\n".join(out))


if __name__ == "__main__":
    main()
