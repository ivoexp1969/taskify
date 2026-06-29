#!/usr/bin/env python3
"""Upload an AAB to Google Play via the Android Publisher API (service account).

Usage:
  python tools/play_upload.py --aab path/to/app-release.aab \
      --package com.example.app --track production --status draft \
      --notes-bg "..." --notes-en "..."

Status 'draft' uploads the bundle and creates a release in the track WITHOUT
rolling out (you finish/submit it manually in Play Console). Status 'completed'
would roll it out. We default to draft for safety.
"""
import argparse
import sys
import json

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", default=r"C:/Users/Admin/keys/play-service-account.json")
    p.add_argument("--aab", required=True)
    p.add_argument("--package", required=True)
    p.add_argument("--track", default="production")
    p.add_argument("--status", default="draft", choices=["draft", "completed", "inProgress"])
    p.add_argument("--notes-bg", default="")
    p.add_argument("--notes-en", default="")
    p.add_argument("--notes-bg-file", default="")
    p.add_argument("--notes-en-file", default="")
    p.add_argument("--dry-run", action="store_true",
                   help="Only test auth + list current track state, do not upload.")
    args = p.parse_args()

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

    if args.dry_run:
        # Verify access + show current production track releases.
        edit = edits.insert(packageName=pkg, body={}).execute()
        eid = edit["id"]
        try:
            tr = edits.tracks().get(packageName=pkg, editId=eid, track=args.track).execute()
            print("ACCESS OK. Current track '%s':" % args.track)
            print(json.dumps(tr, indent=2, ensure_ascii=False))
        finally:
            edits.delete(packageName=pkg, editId=eid).execute()
        return

    # Create edit
    edit = edits.insert(packageName=pkg, body={}).execute()
    eid = edit["id"]
    print("Edit id:", eid)

    # Upload bundle
    media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
    bundle = edits.bundles().upload(packageName=pkg, editId=eid, media_body=media).execute()
    vcode = bundle["versionCode"]
    print("Uploaded AAB, versionCode =", vcode)

    # Build release
    release = {
        "versionCodes": [str(vcode)],
        "status": args.status,
    }
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
    print("Track '%s' updated with release (status=%s)." % (args.track, args.status))

    # Commit
    edits.commit(packageName=pkg, editId=eid).execute()
    print("Committed edit. Done.")


if __name__ == "__main__":
    main()
