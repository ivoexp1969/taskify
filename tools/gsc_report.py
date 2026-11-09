#!/usr/bin/env python3
"""Google Search Console report for taskify1969.com via the Search Console API.

Uses the ga4-reader service account (granted RESTRICTED access to the property in
Search Console). Needs the Search Console API enabled in project taskify-1969
(929046134968) — enabled 2026-11-09.

Reports, for the last N days (default 28):
  • Total clicks / impressions (whole site)
  • Clicks / impressions for pages under /imen-den/
  • Top 10 pages (by clicks)
  • Top 10 queries (by clicks)

Usage:
  python tools/gsc_report.py                 # last 28 days, auto-detect property
  python tools/gsc_report.py --days 28
  python tools/gsc_report.py --site "sc-domain:taskify1969.com"
"""
import argparse
import datetime as dt
import json
import urllib.parse
import urllib.request

from google.oauth2 import service_account
import google.auth.transport.requests as gtr

SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]
API = "https://searchconsole.googleapis.com/webmasters/v3"


def token(key_path):
    creds = service_account.Credentials.from_service_account_file(key_path, scopes=SCOPES)
    creds.refresh(gtr.Request())
    return creds.token


def api_get(url, tok):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def api_post(url, tok, body):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url, data=data,
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def list_sites(tok):
    d = api_get(f"{API}/sites", tok)
    return [s.get("siteUrl") for s in d.get("siteEntry", [])]


def pick_site(sites, domain="taskify1969.com"):
    # Prefer a domain property, then https url-prefix, then any match.
    dom = [s for s in sites if s == f"sc-domain:{domain}"]
    if dom:
        return dom[0]
    https = [s for s in sites if s.rstrip("/") == f"https://{domain}"]
    if https:
        return https[0]
    anym = [s for s in sites if domain in s]
    return anym[0] if anym else None


def query(tok, site, start, end, dimensions=None, row_limit=25, page_filter=None):
    body = {
        "startDate": start, "endDate": end,
        "rowLimit": row_limit, "dataState": "final",
    }
    if dimensions:
        body["dimensions"] = dimensions
    if page_filter:
        body["dimensionFilterGroups"] = [{
            "filters": [{"dimension": "page", "operator": "contains",
                         "expression": page_filter}]
        }]
    enc = urllib.parse.quote(site, safe="")
    return api_post(f"{API}/sites/{enc}/searchAnalytics/query", tok, body)


def totals(resp):
    rows = resp.get("rows", [])
    if not rows:
        return 0, 0, 0.0, 0.0
    r = rows[0]
    return (int(round(r.get("clicks", 0))), int(round(r.get("impressions", 0))),
            r.get("ctr", 0.0), r.get("position", 0.0))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", default=r"C:/Users/Admin/keys/ga4-reader.json")
    p.add_argument("--days", type=int, default=28)
    p.add_argument("--site", default=None, help="Override property, e.g. sc-domain:taskify1969.com")
    args = p.parse_args()

    tok = token(args.key)

    sites = list_sites(tok)
    site = args.site or pick_site(sites)
    if not site:
        print("Няма достъп до property за taskify1969.com.")
        print("Видими properties за ga4-reader:", sites)
        return

    # GSC data finalizes ~2 days; use a clean finalized 28-day window ending 2 days ago.
    end = dt.date.today() - dt.timedelta(days=2)
    start = end - dt.timedelta(days=args.days - 1)
    s, e = start.isoformat(), end.isoformat()

    print(f"Property: {site}")
    print(f"Прозорец: {s} → {e}  ({args.days} дни, финализирани данни)")
    print("=" * 64)

    # 1) Totals whole site
    tc, ti, tctr, tpos = totals(query(tok, site, s, e, dimensions=None, row_limit=1))
    print(f"\n[ОБЩО сайт]")
    print(f"  Кликове:     {tc}")
    print(f"  Показвания:  {ti}")
    print(f"  CTR:         {tctr*100:.2f}%   Ср. позиция: {tpos:.1f}")

    # 2) Totals /imen-den/
    ic, ii, ictr, ipos = totals(
        query(tok, site, s, e, dimensions=None, row_limit=1, page_filter="/imen-den/"))
    sh_c = (ic / tc * 100) if tc else 0
    sh_i = (ii / ti * 100) if ti else 0
    print(f"\n[/imen-den/]")
    print(f"  Кликове:     {ic}  ({sh_c:.1f}% от сайта)")
    print(f"  Показвания:  {ii}  ({sh_i:.1f}% от сайта)")
    print(f"  CTR:         {ictr*100:.2f}%   Ср. позиция: {ipos:.1f}")

    # 3) Top 10 pages
    print(f"\n[ТОП 10 СТРАНИЦИ (по кликове)]")
    resp = query(tok, site, s, e, dimensions=["page"], row_limit=10)
    rows = resp.get("rows", [])
    if not rows:
        print("  (няма данни)")
    for i, r in enumerate(rows, 1):
        print(f"  {i:2}. {int(round(r['clicks'])):>5} клик · {int(round(r['impressions'])):>6} показв · "
              f"CTR {r['ctr']*100:4.1f}% · поз {r['position']:4.1f}  {r['keys'][0]}")

    # 4) Top 10 queries
    print(f"\n[ТОП 10 ЗАЯВКИ (по кликове)]")
    resp = query(tok, site, s, e, dimensions=["query"], row_limit=10)
    rows = resp.get("rows", [])
    if not rows:
        print("  (няма данни)")
    for i, r in enumerate(rows, 1):
        print(f"  {i:2}. {int(round(r['clicks'])):>5} клик · {int(round(r['impressions'])):>6} показв · "
              f"CTR {r['ctr']*100:4.1f}% · поз {r['position']:4.1f}  {r['keys'][0]}")


if __name__ == "__main__":
    main()
