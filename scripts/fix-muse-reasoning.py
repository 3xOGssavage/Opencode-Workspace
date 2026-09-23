#!/usr/bin/env python3
"""fix-muse-reasoning.py — un-brick Muse Spark sessions hit by
"reasoning 'encrypted_content' was not issued to this caller".

Opencode stores caller-bound encrypted reasoning blobs (metadata.openai.itemId
+ metadata.openai.reasoningEncryptedContent) in session history and replays
them. When the pooled gateway rotates, a different server cannot decrypt blobs
another server issued -> HTTP 400 on every turn, forever (session "bricked").

This script strips exactly those two caller-bound fields from `type ==
"reasoning"` parts (readable reasoning text is preserved), matching opencode's
own recovery design (PRs #48908 / #48918). Tool/text parts are never touched.
Cleans both the materialized `part` table and the `event` log (the projector's
source), plus verifies nothing else stores blobs.

Usage:
  python fix-muse-reasoning.py --dry-run            # count-only, no writes
  python fix-muse-reasoning.py --backup-dir <dir>   # backup + strip (refuses if dir exists)
"""

import argparse
import json
import os
import sqlite3
import sys
import time

DB = os.path.join(
    os.environ["USERPROFILE"], ".local", "share", "opencode", "opencode.db"
)
NEEDLE = "reasoningEncryptedContent"
CHUNK = 2000
RETRIES = 5

STRIP_FIELDS = ("itemId", "reasoningEncryptedContent")


def connect(write: bool):
    if write:
        con = sqlite3.connect(DB, timeout=60)
        con.execute("PRAGMA busy_timeout=60000")
        return con
    return sqlite3.connect(f"file:{DB.replace(os.sep, '/')}?mode=ro", uri=True)


def strip_reasoning_node(node, stats):
    """Remove caller-bound fields from a single type=='reasoning' dict.
    Returns True if the node was modified."""
    if not isinstance(node, dict) or node.get("type") != "reasoning":
        return False
    md = node.get("metadata")
    if not isinstance(md, dict):
        return False
    oa = md.get("openai")
    if not isinstance(oa, dict):
        return False
    changed = False
    for f in STRIP_FIELDS:
        if f in oa:
            del oa[f]
            changed = True
    for k in list(oa):
        stats["extra_openai_keys"][k] = stats["extra_openai_keys"].get(k, 0) + 1
    if changed and not oa:
        del md["openai"]
        if not md:
            del node["metadata"]
    return changed


def walk_events(obj, stats):
    """Recursively strip inside reasoning-typed dicts. Returns True if modified."""
    changed = False
    if isinstance(obj, dict):
        if strip_reasoning_node(obj, stats):
            changed = True
        for v in obj.values():
            if walk_events(v, stats):
                changed = True
    elif isinstance(obj, list):
        for v in obj:
            if walk_events(v, stats):
                changed = True
    return changed


def collect(con):
    """Return {table: [(rowid-ish id, raw_data)]} of rows needing the strip,
    plus (unhandled, per-session counts). Pure read."""
    targets = {"part": [], "event": []}
    unhandled = []
    per_session = {}
    stats = {"extra_openai_keys": {}}

    for pid, sid, raw in con.execute(
        f"SELECT id, session_id, data FROM part WHERE data LIKE '%{NEEDLE}%'"
    ):
        d = json.loads(raw)
        if d.get("type") == "reasoning":
            targets["part"].append((pid, raw))
            per_session[sid] = per_session.get(sid, 0) + 1
        else:
            unhandled.append(("part", pid, d.get("type")))

    for eid, etype, raw in con.execute(
        f"SELECT id, type, data FROM event WHERE data LIKE '%{NEEDLE}%'"
    ):
        d = json.loads(raw)
        if etype != "message.part.updated.1":
            unhandled.append(("event", eid, etype))
            continue
        probe = json.loads(json.dumps(d))  # deep copy
        s2 = {"extra_openai_keys": stats["extra_openai_keys"]}
        if walk_events(probe, s2):
            targets["event"].append((eid, raw))
        else:
            unhandled.append(("event", eid, etype))

    return targets, unhandled, per_session, stats


def write_backup(backup_dir, targets):
    if os.path.exists(backup_dir):
        print(f"REFUSING: backup dir already exists: {backup_dir}")
        return False
    os.makedirs(backup_dir)
    for table, rows in targets.items():
        with open(
            os.path.join(backup_dir, f"{table}.jsonl"), "w", encoding="utf-8"
        ) as f:
            for rid, raw in rows:
                f.write(json.dumps({"id": rid, "data": raw}, ensure_ascii=False) + "\n")
    return True


def transform_part(raw):
    d = json.loads(raw)
    s = {"extra_openai_keys": {}}
    if strip_reasoning_node(d, s):
        return json.dumps(d, ensure_ascii=False)
    return None


def transform_event(raw):
    d = json.loads(raw)
    s = {"extra_openai_keys": {}}
    if walk_events(d, s):
        return json.dumps(d, ensure_ascii=False)
    return None  # no reasoning node changed: leave the row untouched


def apply_chunked(con, table, rows, transform):
    idcol = "id"
    done = errors = 0
    for i in range(0, len(rows), CHUNK):
        chunk = rows[i : i + CHUNK]
        payload = []
        for rid, raw in chunk:
            new = transform(raw)
            if new is not None and new != raw:
                payload.append((new, rid))
        for attempt in range(RETRIES):
            try:
                con.execute("BEGIN IMMEDIATE")
                for new, rid in payload:
                    con.execute(
                        f"UPDATE {table} SET data=? WHERE {idcol}=?", (new, rid)
                    )
                con.commit()
                done += len(payload)
                break
            except sqlite3.OperationalError as e:
                try:
                    con.rollback()
                except Exception:
                    pass
                if "locked" in str(e) and attempt < RETRIES - 1:
                    time.sleep(2 * (attempt + 1))
                    continue
                errors += len(payload)
                print(f"  chunk failed after {RETRIES} attempts: {e}")
                break
        print(f"  {table}: {done}/{len(rows)} rows updated...", flush=True)
    return done, errors


def verify_zero(con):
    left = {}
    for table in ("part", "event"):
        n = con.execute(
            f"SELECT COUNT(*) FROM {table} WHERE data LIKE '%{NEEDLE}%'"
        ).fetchone()[0]
        left[table] = n
    return left


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--backup-dir", default=None)
    args = ap.parse_args()

    if args.dry_run:
        con = connect(write=False)
        targets, unhandled, per_session, stats = collect(con)
        print(
            f"DRY-RUN: part rows to strip: {len(targets['part'])}, event rows to strip: {len(targets['event'])}"
        )
        print(f"DRY-RUN: unhandled (left untouched): {len(unhandled)}")
        for u in unhandled[:10]:
            print(f"  unhandled: {u}")
        print(
            f"DRY-RUN: top sessions by part rows: {sorted(per_session.items(), key=lambda x: -x[1])[:8]}"
        )
        print(f"DRY-RUN: extra openai keys seen: {stats['extra_openai_keys']}")
        con.close()
        return 0

    if not args.backup_dir:
        print("Need --dry-run or --backup-dir <dir>")
        return 2

    con = connect(write=False)
    targets, unhandled, per_session, stats = collect(con)
    con.close()
    print(
        f"matched: part={len(targets['part'])} event={len(targets['event'])} unhandled={len(unhandled)}"
    )

    if not write_backup(args.backup_dir, targets):
        return 3
    print(f"backup written to {args.backup_dir}")

    con = connect(write=True)
    d1, e1 = apply_chunked(con, "part", targets["part"], transform_part)
    d2, e2 = apply_chunked(con, "event", targets["event"], transform_event)
    left = verify_zero(con)
    con.close()

    print(f"done: part updated={d1} errors={e1}; event updated={d2} errors={e2}")
    print(
        f"remaining blobs: {left} (only non-reasoning/tool-text matches in part are expected)"
    )
    sess = ", ".join(
        f"{k[:8]}:{v}" for k, v in sorted(per_session.items(), key=lambda x: -x[1])[:8]
    )
    print(f"top sessions cleaned: {sess}")
    return 0 if (e1 == 0 and e2 == 0) else 4


if __name__ == "__main__":
    sys.exit(main())
