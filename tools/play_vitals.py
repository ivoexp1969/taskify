#!/usr/bin/env python3
"""Check Android vitals (crash rate + top crash issues) via the Play Developer
Reporting API, using the same service account as play_upload.py.

Usage:
  python tools/play_vitals.py --package com.ivoexp.taskify --days 7

Note: needs the Play Developer Reporting API ENABLED for the service account's
GCP project (taskify-1969 / 929046134968 — as of 2026-07-13 it is DISABLED:
https://console.developers.google.com/apis/api/playdeveloperreporting.googleapis.com/overview?project=929046134968)
AND the service account granted access in Play Console. Vitals data lags a few
hours — a release published minutes ago will show nothing yet.

The crash-rate query is written against the documented API shape but is UNVERIFIED
until the API is enabled.
"""
import argparse
import datetime as dt

from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/playdeveloperreporting"]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", default=r"C:/Users/Admin/keys/play-service-account.json")
    p.add_argument("--package", required=True)
    p.add_argument("--days", type=int, default=7)
    args = p.parse_args()

    creds = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    svc = build("playdeveloperreporting", "v1beta1", credentials=creds,
                cache_discovery=False)
    app = "apps/%s" % args.package

    today = dt.date.today()

    # Данните изостават — API-то отказва край след „freshness" датата. Питаме я.
    end = today - dt.timedelta(days=1)
    try:
        info = svc.vitals().crashrate().get(
            name="%s/crashRateMetricSet" % app).execute()
        for fi in info.get("freshnessInfo", {}).get("freshnesses", []):
            if fi.get("aggregationPeriod") == "DAILY":
                d = fi["latestEndTime"]
                end = dt.date(d["year"], d["month"], d["day"])
    except Exception as e:
        print("(freshness lookup failed: %s)" % str(e)[:120])

    start = end - dt.timedelta(days=args.days)
    print("Data window: %s → %s (freshness)\n" % (start, end))
    timeline = {
        "aggregationPeriod": "DAILY",
        "startTime": {"year": start.year, "month": start.month, "day": start.day},
        "endTime": {"year": end.year, "month": end.month, "day": end.day},
    }

    print("== Crash rate (daily, last %d days) ==" % args.days)
    try:
        resp = svc.vitals().crashrate().query(
            name="%s/crashRateMetricSet" % app,
            body={
                "timelineSpec": timeline,
                "metrics": ["crashRate", "distinctUsers"],
                "dimensions": ["versionCode"],
            },
        ).execute()
        rows = resp.get("rows", [])
        if not rows:
            print("  (no data yet)")
        for r in rows:
            day = r.get("startTime", {})
            dims = {d["dimension"]: d.get("int64Value") or d.get("stringValue")
                    for d in r.get("dimensions", [])}
            mets = {m["metric"]: (m.get("decimalValue", {}).get("value")
                                  or m.get("int64Value"))
                    for m in r.get("metrics", [])}
            print("  %04d-%02d-%02d  vc=%s  crashRate=%s  users=%s" % (
                day.get("year", 0), day.get("month", 0), day.get("day", 0),
                dims.get("versionCode"), mets.get("crashRate"),
                mets.get("distinctUsers")))
    except Exception as e:
        print("  ERROR:", e)

    print("\n== Top crash issues (last %d days) ==" % args.days)
    try:
        resp = svc.vitals().errors().issues().search(
            parent=app,
            filter='errorIssueType = CRASH',
            interval_startTime_year=start.year,
            interval_startTime_month=start.month,
            interval_startTime_day=start.day,
            interval_endTime_year=today.year,
            interval_endTime_month=today.month,
            interval_endTime_day=today.day,
            pageSize=10,
        ).execute()
        issues = resp.get("errorIssues", [])
        if not issues:
            print("  (none)")
        for i in issues:
            counts = i.get("errorReportCounts") or i.get("distinctUsers")
            print("  cause: %s" % i.get("cause"))
            print("    location: %s" % i.get("location"))
            print("    users: %s  reports: %s  last seen: %s"
                  % (i.get("distinctUsers"), counts,
                     i.get("lastErrorReportTime")))
            print("    firstOsVersion: %s  lastOsVersion: %s  appVersions: %s"
                  % (i.get("firstOsVersion", {}).get("apiLevel"),
                     i.get("lastOsVersion", {}).get("apiLevel"),
                     [v.get("versionCode") for v in
                      (i.get("firstAppVersion"), i.get("lastAppVersion"))
                      if v]))
    except Exception as e:
        print("  ERROR:", e)


if __name__ == "__main__":
    main()
