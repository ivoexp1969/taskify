#!/usr/bin/env node
/**
 * Миграция (1.0.70 restore redesign): за всеки НЕанонимен uid, който е изкупил
 * промо код (присъства в `promo_codes/*.usedBy`), записва огледален документ
 * `users/{uid}/promo/current` = { code, type, activatedAt, expiresAt? }, за да
 * може новият `_restoreAccountPromo` да възстанови Pro БЕЗ да чете цялата
 * колекция `promo_codes`.
 *
 * ПРАВИЛА:
 *   • Dry-run по подразбиране — НИЩО не се пише. Добави `--execute`, за да пише.
 *   • Lifetime има приоритет; иначе days-промото с НАЙ-ДАЛЕЧНАТА валидна дата
 *     (от `redemptions[uid]`). Анонимните uid се ПРОПУСКАТ (нямат акаунт).
 *   • Справка (само четене): колко записа в usedBy са към анонимни uid.
 *
 * Употреба:
 *   node tools/promo_mirror_migrate.cjs            # dry-run + справка
 *   node tools/promo_mirror_migrate.cjs --execute  # реален запис (след „ок")
 *   (ключ по подразбиране: ./serviceAccountKey.json; смени с --key <path>)
 */
'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

function arg(name, def) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? (process.argv[i + 1] || true) : def;
}

const EXECUTE = process.argv.includes('--execute');
const KEY = arg('--key', path.join(process.cwd(), 'serviceAccountKey.json'));

initializeApp({ credential: cert(require(KEY)) });
const db = getFirestore();
const auth = getAuth();

/** Класифицира uid-ите на партиди (anonymous / real / unknown / invalid). */
async function classify(uids) {
  const map = new Map(); // uid -> 'anon' | 'real' | 'unknown' | 'invalid'
  // Валиден Firebase uid = непразен низ, ≤128 знака. Невалидните (празни/счупени
  // записи в usedBy) се броят отделно, за да не чупят цялата партида на getUsers.
  const valid = [];
  for (const uid of uids) {
    if (typeof uid === 'string' && uid.length > 0 && uid.length <= 128) {
      valid.push(uid);
    } else {
      map.set(uid, 'invalid');
    }
  }
  for (let i = 0; i < valid.length; i += 100) {
    const chunk = valid.slice(i, i + 100).map((uid) => ({ uid }));
    const res = await auth.getUsers(chunk);
    for (const u of res.users) {
      // Анонимен = без нито един доставчик (providerData е празен).
      const anon = (u.providerData || []).length === 0;
      map.set(u.uid, anon ? 'anon' : 'real');
    }
    for (const nf of res.notFound) map.set(nf.uid, 'unknown');
  }
  return map;
}

(async () => {
  console.log(`\n=== Promo mirror migration (${EXECUTE ? 'EXECUTE' : 'DRY-RUN'}) ===`);
  const snap = await db.collection('promo_codes').get();
  console.log(`Промо кодове: ${snap.size}`);

  // uid -> { code, type, end? } (най-доброто промо за потребителя)
  const best = new Map();
  let usedByEntries = 0;
  const allUids = new Set();

  for (const d of snap.docs) {
    const data = d.data();
    if (data.isActive !== true) continue;
    const type = data.type;
    const usedBy = Array.isArray(data.usedBy) ? data.usedBy : [];
    const reds = data.redemptions || {};
    for (const uid of usedBy) {
      usedByEntries++;
      allUids.add(uid);
      if (type === 'lifetime') {
        best.set(uid, { code: d.id, type: 'lifetime', end: null });
      } else if (type === 'days') {
        const ts = reds[uid];
        const end = ts && ts.toDate ? ts.toDate() : null;
        if (!end || end <= new Date()) continue; // изтекло/без дата
        const cur = best.get(uid);
        if (!cur) { best.set(uid, { code: d.id, type: 'days', end }); }
        else if (cur.type === 'days' && cur.end && end > cur.end) {
          best.set(uid, { code: d.id, type: 'days', end });
        }
      }
    }
  }

  const cls = await classify([...allUids]);
  let anon = 0, real = 0, unknown = 0, invalid = 0;
  for (const uid of allUids) {
    const c = cls.get(uid);
    if (c === 'anon') anon++;
    else if (c === 'real') real++;
    else if (c === 'invalid') invalid++;
    else unknown++;
  }

  // Справка (само четене).
  console.log('\n--- Справка usedBy ---');
  console.log(`Записи в usedBy (общо, с повторения):      ${usedByEntries}`);
  console.log(`Уникални uid:                              ${allUids.size}`);
  console.log(`  • анонимни (ПРОПУСКАТ се):               ${anon}`);
  console.log(`  • реални акаунти:                        ${real}`);
  console.log(`  • непознати/изтрити:                     ${unknown}`);
  console.log(`  • невалидни записи (празни/счупени):     ${invalid}`);

  // Кандидати за миграция = реални uid с валидно промо.
  const candidates = [];
  for (const [uid, promo] of best) {
    if (cls.get(uid) !== 'real') continue;
    candidates.push({ uid, ...promo });
  }

  // Колко вече имат огледало?
  let already = 0;
  for (const c of candidates) {
    const ex = await db.doc(`users/${c.uid}/promo/current`).get();
    if (ex.exists) { already++; c.exists = true; }
  }
  const toWrite = candidates.filter((c) => !c.exists);

  console.log('\n--- Миграция ---');
  console.log(`Реални uid с валидно промо:                ${candidates.length}`);
  console.log(`  • вече имат огледало:                    ${already}`);
  console.log(`  • ще бъдат записани:                     ${toWrite.length}`);

  if (!EXECUTE) {
    console.log('\nDRY-RUN — нищо не е записано. Пусни с --execute след „ок".');
    process.exit(0);
  }

  let written = 0;
  let batch = db.batch();
  let n = 0;
  for (const c of toWrite) {
    batch.set(db.doc(`users/${c.uid}/promo/current`), {
      code: c.code,
      type: c.type,
      activatedAt: FieldValue.serverTimestamp(),
      ...(c.end ? { expiresAt: Timestamp.fromDate(c.end) } : {}),
    });
    written++;
    if (++n >= 400) { await batch.commit(); batch = db.batch(); n = 0; }
  }
  if (n > 0) await batch.commit();
  console.log(`\n✓ Записани огледални документи: ${written}`);
  process.exit(0);
})().catch((e) => {
  console.error('ГРЕШКА:', e);
  process.exit(1);
});
