#!/usr/bin/env python3
"""Promote an ALREADY UPLOADED versionCode in a Play track (start/resize rollout).

Use this when `play_upload.py` already put the AAB in the track as a draft — the
bundle cannot be uploaded twice, so promoting is a track-only edit.

Usage:
  python tools/play_promote.py --package com.ivoexp.taskify --version-code 61 \
      --track production --status completed \
      --notes-bg-file notes_bg.txt --notes-en-file notes_en.txt

  # staged rollout to 20% instead:
  ... --status inProgress --fraction 0.2

Status:
  completed  → full rollout (100%)
  inProgress → staged rollout, requires --fraction (0..1)
  draft      → back to draft (no rollout)
"""
import argparse

from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", default=r"C:/Users/Admin/keys/play-service-account.json")
    p.add_argument("--package", required=True)
    p.add_argument("--version-code", required=True)
    p.add_argument("--track", default="production")
    p.add_argument("--status", default="completed",
                   choices=["draft", "completed", "inProgress"])
    p.add_argument("--fraction", type=float, default=None,
                   help="User fraction 0..1 (required for inProgress).")
    p.add_argument("--notes-bg", default="")
    p.add_argument("--notes-en", default="")
    p.add_argument("--notes-bg-file", default="")
    p.add_argument("--notes-en-file", default="")
    args = p.parse_args()

    if args.status == "inProgress" and not args.fraction:
        p.error("--fraction is required when --status inProgress")

    if args.notes_bg_file:
        with open(args.notes_bg_file, encoding="utf-8") as f:
            args.notes_bg = f.read().strip()
    if args.notes_en_file:
        with open(args.notes_en_file, encoding="utf-8") as f:
            args.notes_en = f.read().strip()

    creds = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()
    pkg = args.package

    edit = edits.insert(packageName=pkg, body={}).execute()
    eid = edit["id"]
    print("Edit id:", eid)

    release = {
        "versionCodes": [str(args.version_code)],
        "status": args.status,
    }
    if args.status == "inProgress":
        release["userFraction"] = args.fraction

    notes = []
    if args.notes_en:
        notes.append({"language": "en-US", "text": args.notes_en})
    if args.notes_bg:
        notes.append({"language": "bg", "text": args.notes_bg})
    if notes:
        release["releaseNotes"] = notes

    edits.tracks().update(
        packageName=pkg, editId=eid, track=args.track,
        body={"track": args.track, "releases": [release]},
    ).execute()
    edits.commit(packageName=pkg, editId=eid).execute()

    where = "100%" if args.status == "completed" else (
        "%.0f%%" % (args.fraction * 100) if args.fraction else args.status)
    print("Track '%s': versionCode %s → status=%s (%s). Committed."
          % (args.track, args.version_code, args.status, where))


if __name__ == "__main__":
    main()
