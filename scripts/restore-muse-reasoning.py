#!/usr/bin/env python3
"""restore-muse-reasoning.py — roll back fix-muse-reasoning.py from its backup.

Usage: python restore-muse-reasoning.py --backup-dir <dir>
Re-applies the ORIGINAL raw data strings (byte-exact) by row id, in chunks.
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
CHUNK = 2000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backup-dir", required=True)
    args = ap.parse_args()

    con = sqlite3.connect(DB, timeout=60)
    con.execute("PRAGMA busy_timeout=60000")
    total = 0
    for table in ("part", "event"):
        path = os.path.join(args.backup_dir, f"{table}.jsonl")
        if not os.path.exists(path):
            print(f"skip {table}: no backup file")
            continue
        rows = []
        with open(path, encoding="utf-8") as f:
            for line in f:
                r = json.loads(line)
                rows.append((r["data"], r["id"]))
        for i in range(0, len(rows), CHUNK):
            for attempt in range(5):
                try:
                    con.execute("BEGIN IMMEDIATE")
                    for data, rid in rows[i : i + CHUNK]:
                        con.execute(
                            f"UPDATE {table} SET data=? WHERE id=?", (data, rid)
                        )
                    con.commit()
                    total += len(rows[i : i + CHUNK])
                    break
                except sqlite3.OperationalError as e:
                    try:
                        con.rollback()
                    except Exception:
                        pass
                    if "locked" in str(e) and attempt < 4:
                        time.sleep(2 * (attempt + 1))
                        continue
                    print(f"restore failed: {e}")
                    con.close()
                    return 1
        print(f"{table}: restored {len(rows)} rows")
    con.close()
    print(f"restore complete: {total} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
