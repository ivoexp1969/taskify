#!/usr/bin/env python3
"""Pull / push Google Play store listing texts (title, short & full description).

Uses the Android Publisher API (androidpublisher v3) with a service account.
Store texts live under `store_metadata/play/<locale>/{title,short_description,
full_description}.txt`, one file per field, exactly as the API returns them
(bytes are written verbatim — no trailing newline is added or stripped).

Commands:
  pull   Fetch ALL configured locales and write them to disk (read-only:
         the edit is abandoned, so NOTHING is committed to Play).
  push   Read the same files back and update each locale's listing, then
         commit. Validates length limits BEFORE committing. Supports
         --dry-run to show a diff without committing.

Examples:
  python tools/play_listing.py pull
  python tools/play_listing.py push --dry-run
  python tools/play_listing.py push
"""
import argparse
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
KEY_DEFAULT = r"C:/Users/Admin/keys/play-service-account.json"
PACKAGE_DEFAULT = "com.ivoexp.taskify"

# Google Play hard limits (characters).
LIMIT_TITLE = 30
LIMIT_SHORT = 80
LIMIT_FULL = 4000

# API field name -> filename stem.
FIELDS = [
    ("title", "title"),
    ("shortDescription", "short_description"),
    ("fullDescription", "full_description"),
]
LIMITS = {"title": LIMIT_TITLE, "shortDescription": LIMIT_SHORT,
          "fullDescription": LIMIT_FULL}


def _repo_root():
    # tools/ -> repo root
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _base_dir():
    return os.path.join(_repo_root(), "store_metadata", "play")


def _locale_dir(locale):
    return os.path.join(_base_dir(), locale)


def _file_path(locale, stem):
    return os.path.join(_locale_dir(locale), stem + ".txt")


def _service(key):
    creds = service_account.Credentials.from_service_account_file(key, scopes=SCOPES)
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def cmd_pull(args):
    service = _service(args.key)
    edits = service.edits()
    pkg = args.package

    edit = edits.insert(packageName=pkg, body={}).execute()
    eid = edit["id"]
    print("Opened read-only edit:", eid)

    rows = []  # (locale, api_field, value)
    mismatches = []
    try:
        listings = edits.listings().list(packageName=pkg, editId=eid).execute()
        entries = listings.get("listings", [])
        locales = sorted(e["language"] for e in entries)
        print("Configured locales (%d): %s" % (len(locales), ", ".join(locales)))

        for entry in sorted(entries, key=lambda e: e["language"]):
            locale = entry["language"]
            os.makedirs(_locale_dir(locale), exist_ok=True)
            for api_field, stem in FIELDS:
                value = entry.get(api_field, "") or ""
                path = _file_path(locale, stem)
                # Write bytes verbatim: no newline translation, no added newline.
                with open(path, "wb") as fh:
                    fh.write(value.encode("utf-8"))
                # Immediate byte-for-byte read-back verification.
                with open(path, "rb") as fh:
                    on_disk = fh.read()
                if on_disk != value.encode("utf-8"):
                    mismatches.append((locale, api_field, path))
                rows.append((locale, api_field, value))
    finally:
        # Abandon the edit so nothing is ever committed.
        edits.delete(packageName=pkg, editId=eid).execute()
        print("Abandoned edit (nothing committed).")

    # Report table.
    print("\n%-8s %-18s %7s" % ("locale", "field", "chars"))
    print("-" * 36)
    for locale, api_field, value in rows:
        print("%-8s %-18s %7d" % (locale, api_field, len(value)))

    if mismatches:
        print("\nBYTE-FOR-BYTE MISMATCH on:")
        for locale, api_field, path in mismatches:
            print("  %s / %s -> %s" % (locale, api_field, path))
        return 1
    print("\nByte-for-byte read-back: OK for all files.")
    return 0


def _read_file(locale, stem):
    path = _file_path(locale, stem)
    if not os.path.exists(path):
        return None
    with open(path, "rb") as fh:
        return fh.read().decode("utf-8")


def cmd_push(args):
    service = _service(args.key)
    edits = service.edits()
    pkg = args.package

    base = _base_dir()
    if not os.path.isdir(base):
        sys.exit("No local metadata dir: %s (run `pull` first)" % base)
    locales = sorted(d for d in os.listdir(base)
                     if os.path.isdir(os.path.join(base, d)))
    if not locales:
        sys.exit("No locale folders under %s" % base)

    # Load + validate BEFORE touching the API.
    payloads = {}   # locale -> {apiField: value}
    errors = []
    for locale in locales:
        body = {}
        for api_field, stem in FIELDS:
            value = _read_file(locale, stem)
            if value is None:
                errors.append("%s: missing %s.txt" % (locale, stem))
                continue
            limit = LIMITS[api_field]
            if len(value) > limit:
                errors.append("%s/%s: %d chars > limit %d"
                              % (locale, api_field, len(value), limit))
            body[api_field] = value
        payloads[locale] = body
    if errors:
        print("VALIDATION FAILED — nothing sent:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 2

    edit = edits.insert(packageName=pkg, body={}).execute()
    eid = edit["id"]
    print("Opened edit:", eid)
    changed = False
    try:
        current = edits.listings().list(packageName=pkg, editId=eid).execute()
        cur_map = {e["language"]: e for e in current.get("listings", [])}

        for locale in locales:
            body = payloads[locale]
            cur = cur_map.get(locale, {})
            diffs = []
            for api_field, _stem in FIELDS:
                old = (cur.get(api_field, "") or "")
                new = body.get(api_field, "")
                if old != new:
                    diffs.append((api_field, len(old), len(new)))
            if diffs:
                changed = True
                for api_field, oldn, newn in diffs:
                    print("  %s/%s: %d -> %d chars%s"
                          % (locale, api_field, oldn, newn,
                             "  [DRY-RUN]" if args.dry_run else ""))
            if not args.dry_run:
                edits.listings().update(
                    packageName=pkg, editId=eid, language=locale,
                    body={"language": locale, **body},
                ).execute()

        if args.dry_run:
            print("DRY-RUN: no changes committed." if changed
                  else "DRY-RUN: no differences.")
            edits.delete(packageName=pkg, editId=eid).execute()
            return 0

        edits.commit(packageName=pkg, editId=eid).execute()
        print("Committed listing update for %d locale(s)." % len(locales))
        return 0
    except Exception:
        # Best-effort abandon on failure.
        try:
            edits.delete(packageName=pkg, editId=eid).execute()
        except Exception:
            pass
        raise


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--key", default=KEY_DEFAULT)
    p.add_argument("--package", default=PACKAGE_DEFAULT)
    sub = p.add_subparsers(dest="cmd", required=True)

    sp_pull = sub.add_parser("pull", help="Fetch listings to disk (read-only).")
    sp_pull.set_defaults(func=cmd_pull)

    sp_push = sub.add_parser("push", help="Upload listings from disk.")
    sp_push.add_argument("--dry-run", action="store_true",
                         help="Show diff vs current, do not commit.")
    sp_push.set_defaults(func=cmd_push)

    args = p.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
