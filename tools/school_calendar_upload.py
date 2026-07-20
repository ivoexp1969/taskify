#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Качва документ за учебна година в Firestore колекция `school_calendar`
(„Училищен режим"). Иво актуализира датите веднъж годишно по заповед на МОН —
без нов билд на приложението.

ИЗТОЧНИК на данните: JSON файл със структура
    { "docId": "bg_2026_2027", "data": { ...полетата на учебната година... } }
(виж `school_calendar_bg_2026_2027.template.json`). Датите са ISO низове
'YYYY-MM-DD' — приложението ги парсва директно (моделът приема ISO низове),
затова НЕ ги превръщаме в Firestore Timestamp тук.

УПОТРЕБА:
    python tools/school_calendar_upload.py tools/school_calendar_bg_2026_2027.template.json

КРЕДЕНШЪЛИ (service account, проект taskify-1969):
    По подразбиране ~/keys/play-service-account.json (същия проект). Ако този
    акаунт НЯМА достъп до Firestore, дай му роля „Cloud Datastore User" в
    IAM на проекта, ИЛИ подай друг ключ през FIREBASE_SA=<път>.

ЗАВИСИМОСТ:
    pip install google-cloud-firestore

★ВАЖНО★: НЕ измисляй дати. Ако заповедта на МОН още не е издадена — НЕ качвай
документа. Приложението показва честно празно състояние, вместо да гадае.
"""

import json
import os
import sys


def _load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _strip_underscore_keys(obj):
    """Маха служебните ключове (започващи с '_', напр. _INSTRUCTIONS)."""
    if isinstance(obj, dict):
        return {k: _strip_underscore_keys(v) for k, v in obj.items()
                if not k.startswith("_")}
    if isinstance(obj, list):
        return [_strip_underscore_keys(v) for v in obj]
    return obj


def _validate(data):
    """Леки проверки да хванем празни/забравени дати преди качване."""
    problems = []
    if not data.get("year"):
        problems.append("липсва 'year'")
    if not data.get("startOfYear"):
        problems.append("празно 'startOfYear'")
    for v in data.get("vacations", []):
        if not v.get("start") or not v.get("end"):
            problems.append(f"ваканция '{v.get('key', '?')}' с празна дата")
    for e in data.get("endOfYear", []):
        if not e.get("date"):
            problems.append(f"endOfYear за класове '{e.get('grades','?')}' без дата")
    return problems


def main():
    if len(sys.argv) < 2:
        print("Употреба: python tools/school_calendar_upload.py <path-to-json>")
        sys.exit(1)

    src = sys.argv[1]
    if not os.path.exists(src):
        print(f"Файлът не съществува: {src}")
        sys.exit(1)

    payload = _load(src)
    doc_id = payload.get("docId")
    data = _strip_underscore_keys(payload.get("data", {}))
    if not doc_id or not data:
        print("JSON-ът трябва да има 'docId' и 'data'. Виж шаблона.")
        sys.exit(1)

    problems = _validate(data)
    if problems:
        print("⚠️  Внимание — вероятно непопълнени данни:")
        for p in problems:
            print(f"   - {p}")
        if data.get("official"):
            print("   ('official:true' при празни дати е ГРЕШКА — прекратявам.)")
            sys.exit(2)
        ans = input("Все пак да качвам? [y/N] ").strip().lower()
        if ans != "y":
            print("Отказано.")
            sys.exit(0)

    try:
        from google.cloud import firestore
    except ImportError:
        print("Липсва google-cloud-firestore. Инсталирай:")
        print("   pip install google-cloud-firestore")
        sys.exit(1)

    sa = os.environ.get(
        "FIREBASE_SA",
        os.path.expanduser("~/keys/play-service-account.json"),
    )
    if not os.path.exists(sa):
        print(f"Service account ключ не е намерен: {sa}")
        print("Подай друг път през FIREBASE_SA=<път>.")
        sys.exit(1)

    client = firestore.Client.from_service_account_json(sa, project="taskify-1969")
    client.collection("school_calendar").document(doc_id).set(data)
    print(f"✅ Качено: school_calendar/{doc_id}  (official={data.get('official')})")
    print("   Приложението ще го изтегли фоново (24ч кеш; чист старт го взима веднага).")


if __name__ == "__main__":
    main()
