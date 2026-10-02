'use strict';
/**
 * Self-test of the harness and of sheets/setup.gs running inside it. Does not need backend/src.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { createEnv, SCHEMA, SUMMARY_TITLE, REPO_ROOT } = require('./harness');

const noBackend = { bootstrapAdmin: 'owner.admin@gmail.com' };

test('setup.gs builds every schema sheet with title on row 1, description on row 2 and headers on row 3', () => {
  const env = createEnv(noBackend);
  assert.deepEqual(env.sheetNames(), [SUMMARY_TITLE, ...SCHEMA.sheets.map((s) => s.title)],
    'sheet order: summary first, then schema order; the default Sheet1 is removed');
  for (const def of SCHEMA.sheets) {
    const v = env.values(def.title);
    assert.equal(v[0][0], def.title, `${def.title}: row 1 title`);
    assert.equal(v[1][0], def.description, `${def.title}: row 2 description`);
    assert.equal(SCHEMA.headerRow, 3);
    assert.deepEqual(env.headers(def.title), def.columns.map((c) => c.name), `${def.title}: header row 3`);
    const st = env.sheetState(def.title);
    assert.ok(st.maxRows >= 1000, `${def.title}: at least 1000 rows`);
    assert.ok(st.filter, `${def.title}: filter created`);
  }
  assert.equal(env.spreadsheetState().tz, 'Africa/Cairo');
  assert.equal(env.world.log.toasts.length, 1);
});

test('setup.gs writes the base rows (settings, item types) only into empty sheets', () => {
  const env = createEnv(noBackend);
  const settings = env.readSheet('settings');
  const byKey = Object.fromEntries(settings.map((r) => [r['المفتاح'], r['القيمة']]));
  assert.equal(byKey['المنطقة الزمنية'], 'Africa/Cairo');
  assert.equal(byKey['وزن الصندوق الفارغ (كغ)'], 1.9);
  assert.equal(byKey['منازل المبالغ'], 2);
  assert.ok(byKey['بداية الموسم'] instanceof Date, 'season start stored as a date');
  const items = env.readSheet('item_types');
  assert.equal(items.length, 9);
  assert.deepEqual(items[0], { 'المعرّف': 'IT-01', 'الصنف': 'الصناديق', 'الوحدة الافتراضية': 'قطعة', 'الترتيب': 1, 'نشط': 'نعم' });
  for (const def of SCHEMA.sheets.filter((d) => !['settings', 'item_types'].includes(d.key))) {
    assert.equal(env.readSheet(def.title).length, 0, `${def.title} starts empty`);
  }
});

test('SCHEMA inside setup.gs equals sheets/schema.json', () => {
  const env = createEnv(noBackend);
  const inScript = env.evaluate('JSON.stringify(SCHEMA)');
  assert.deepEqual(JSON.parse(inScript), JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'sheets', 'schema.json'), 'utf8')));
});

test('running setupRummanSheet again keeps data rows and does not duplicate base rows', () => {
  const env = createEnv(noBackend);
  env.appendRowObject('farmers', { 'المعرّف': 'FR-0001', 'رقم المزارع': 1, 'الاسم': 'حسن', 'الهاتف': '0100', 'الحالة': 'نشط', 'الإصدار': 1 });
  const before = SCHEMA.sheets.map((d) => env.values(d.title));
  env.run('setupRummanSheet', [], { withBackend: false });
  const after = SCHEMA.sheets.map((d) => env.values(d.title));
  assert.deepEqual(after, before);
  assert.equal(env.readSheet('farmers')[0]['الهاتف'], '0100', 'plain-text column keeps leading zeros');
});

test('setupRummanSheet restores a deleted header at the end of the sheet without touching data', () => {
  const env = createEnv(noBackend);
  env.appendRowObject('farmers', { 'المعرّف': 'FR-0001', 'رقم المزارع': 1, 'الاسم': 'حسن', 'الحالة': 'نشط', 'الإصدار': 1 });
  const col = env.column('farmers', 'ملاحظات');
  env.setCell('farmers', 3, col, '');
  assert.equal(env.headers('farmers').includes('ملاحظات'), false);
  env.run('setupRummanSheet', [], { withBackend: false });
  assert.equal(env.headers('farmers').includes('ملاحظات'), true);
  assert.equal(env.readSheet('farmers')[0]['الاسم'], 'حسن');
});

test('fake Range/Sheet behave like Apps Script', () => {
  const env = createEnv(noBackend);
  const r = env.evaluate(`(() => {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sh = ss.getSheetByName('المزارعون');
    const out = {};
    const tryIt = (f) => { try { f(); return 'no error'; } catch (e) { return e.message; } };
    out.zeroRows = tryIt(() => sh.getRange(4, 1, 0, 3));
    out.outside = tryIt(() => sh.getRange(1, 1, 1, sh.getMaxColumns() + 1));
    out.dims = tryIt(() => sh.getRange(4, 1, 1, 2).setValues([[1, 2, 3]]));
    out.lastRowEmpty = sh.getLastRow();
    out.lastColumn = sh.getLastColumn();
    sh.appendRow(['FR-0001', '7', 'حسن', '0100', '', '', 'نشط', '2026-10-02 10:30', 'x', 1]);
    const v = sh.getRange(4, 1, 1, 10).getValues()[0];
    out.idType = typeof v[0]; out.noType = typeof v[1]; out.phone = v[3];
    out.isDate = v[7] instanceof Date; out.dateIso = v[7].toISOString();
    out.invalidEnum = tryIt(() => sh.getRange(4, 7).setValue('active'));
    out.a1 = sh.getRange('B1:L1').getA1Notation();
    out.lastRow = sh.getLastRow();
    out.unsupported = tryIt(() => sh.getRange(4, 1).getDisplayValues());
    out.openByUrl = tryIt(() => SpreadsheetApp.openByUrl('x'));
    out.openById = tryIt(() => SpreadsheetApp.openById('nope'));
    out.chain = sh.getRange(4, 1).setFontWeight('bold').setBackground('#fff').getA1Notation();
    return out;
  })()`);
  assert.equal(r.zeroRows, 'The number of rows in the range must be at least 1.');
  assert.equal(r.outside, 'The coordinates of the range are outside the dimensions of the sheet.');
  assert.match(r.dims, /number of columns in the data does not match/);
  assert.equal(r.lastRowEmpty, 3);
  assert.equal(r.lastColumn, SCHEMA.sheets.find((s) => s.key === 'farmers').columns.length);
  assert.equal(r.idType, 'string');
  assert.equal(r.noType, 'number', 'numeric text typed into a number column becomes a number');
  assert.equal(r.phone, '0100', 'plain-text column keeps text');
  assert.equal(r.isDate, true, 'yyyy-MM-dd HH:mm text in a date column becomes a Date (realm-native)');
  assert.equal(r.dateIso, '2026-10-02T07:30:00.000Z', 'parsed in the spreadsheet time zone (Cairo, +03:00)');
  assert.match(r.invalidEnum, /violates the data validation rules/);
  assert.equal(r.a1, 'B1:L1');
  assert.equal(r.lastRow, 4);
  assert.match(r.unsupported, /not part of the Apps Script subset/);
  assert.match(r.openByUrl, /not part of the Apps Script subset/);
  assert.match(r.openById, /openById/);
  assert.equal(r.chain, 'A4');
});

test('fake Utilities match Apps Script semantics', () => {
  const env = createEnv(noBackend);
  const r = env.evaluate(`(() => {
    const out = {};
    out.sig = Utilities.computeHmacSha256Signature('payload.part', 'secret-key');
    out.b64 = Utilities.base64EncodeWebSafe('{"a":"ب"}');
    out.b64bytes = Utilities.base64EncodeWebSafe([-1, -2, 0]);
    out.decoded = Utilities.newBlob(Utilities.base64DecodeWebSafe(out.b64)).getDataAsString();
    out.decodedSigned = Utilities.base64DecodeWebSafe('__4A');
    try { Utilities.base64DecodeWebSafe('a*b'); out.badDecode = 'no error'; } catch (e) { out.badDecode = e.message; }
    out.uuid = Utilities.getUuid();
    const d = new Date(Date.UTC(2026, 9, 2, 3, 40, 5));
    out.f1 = Utilities.formatDate(d, 'Africa/Cairo', "yyyy-MM-dd'T'HH:mm:ssXXX");
    out.f2 = Utilities.formatDate(d, 'Africa/Cairo', 'yyyy-MM-dd HH:mm');
    out.f3 = Utilities.formatDate(d, 'Asia/Dubai', 'yyyy-MM-dd');
    out.f4 = Utilities.formatDate(d, 'Africa/Cairo', 'HH:mm');
    out.f5 = Utilities.formatDate(d, 'UTC', "yyyy-MM-dd'T'HH:mm:ssXXX");
    out.winter = Utilities.formatDate(new Date(Date.UTC(2026, 11, 2, 3, 40, 5)), 'Africa/Cairo', "yyyy-MM-dd'T'HH:mm:ssXXX");
    out.unknownTz = Utilities.formatDate(d, 'Africa/Cairoo', "yyyy-MM-dd'T'HH:mm:ssXXX");
    out.wrongCaseTz = Utilities.formatDate(d, 'africa/cairo', "yyyy-MM-dd'T'HH:mm:ssXXX");
    try { Utilities.formatDate(d, 'Africa/Cairo', 'dd/MM/yyyy'); out.badPattern = 'no error'; } catch (e) { out.badPattern = e.message; }
    out.ownerEmail = Session.getEffectiveUser().getEmail();
    out.scriptTz = Session.getScriptTimeZone();
    const t = ContentService.createTextOutput('{"ok":true}').setMimeType(ContentService.MimeType.JSON);
    out.content = t.getContent();
    return out;
  })()`);
  const expected = Array.from(crypto.createHmac('sha256', 'secret-key').update('payload.part').digest(), (b) => (b > 127 ? b - 256 : b));
  assert.deepEqual(r.sig, expected, 'HMAC bytes are signed like Java');
  assert.equal(r.b64, Buffer.from('{"a":"ب"}').toString('base64').replace(/\+/g, '-').replace(/\//g, '_'));
  assert.equal(r.b64bytes, '__4A');
  assert.equal(r.decoded, '{"a":"ب"}');
  assert.deepEqual(r.decodedSigned, [-1, -2, 0]);
  assert.equal(r.badDecode, 'Could not decode string.');
  assert.match(r.uuid, /^[0-9a-f-]{36}$/);
  assert.equal(r.f1, '2026-10-02T06:40:05+03:00');
  assert.equal(r.f2, '2026-10-02 06:40');
  assert.equal(r.f3, '2026-10-02');
  assert.equal(r.f4, '06:40');
  assert.equal(r.f5, '2026-10-02T03:40:05Z');
  assert.equal(r.winter, '2026-12-02T05:40:05+02:00');
  assert.equal(r.unknownTz, '2026-10-02T03:40:05Z', 'unknown zone id: silently GMT, like Java TimeZone.getTimeZone');
  assert.equal(r.wrongCaseTz, '2026-10-02T03:40:05Z', 'zone ids are case-sensitive');
  assert.match(r.badPattern, /not supported by the harness/);
  assert.equal(r.ownerEmail, 'owner@example.com');
  assert.equal(r.scriptTz, 'Africa/Cairo');
  assert.equal(r.content, '{"ok":true}');
});

test('fake base64EncodeWebSafe keeps "=" padding', () => {
  const env = createEnv(noBackend);
  assert.equal(env.evaluate("Utilities.base64EncodeWebSafe('ab')"), 'YWI=');
  assert.equal(env.evaluate("Utilities.newBlob(Utilities.base64DecodeWebSafe('YWI')).getDataAsString()"), 'ab');
});

test('fake LockService, CacheService, PropertiesService and the clock', () => {
  const env = createEnv(Object.assign({}, noBackend, { extraProps: { SESSION_DAYS: '3' } }));
  const lock = env.evaluate(`(() => {
    const l = LockService.getScriptLock();
    const ok = l.tryLock(100); l.releaseLock();
    return ok;
  })()`);
  assert.equal(lock, true);
  env.lock.setBusy(true);
  const busy = env.evaluate(`(() => {
    const l = LockService.getScriptLock();
    let msg = 'no error';
    try { l.waitLock(25000); } catch (e) { msg = e.message; }
    return { msg, tried: l.tryLock(10) };
  })()`);
  assert.equal(busy.msg, 'Lock timeout: another process was holding the lock for too long.');
  assert.equal(busy.tried, false);
  env.lock.setBusy(false);

  env.evaluate("CacheService.getScriptCache().put('k', 'v', 60)");
  assert.equal(env.evaluate("CacheService.getScriptCache().get('k')"), 'v');
  env.clock.advance(61000);
  assert.equal(env.evaluate("CacheService.getScriptCache().get('k')"), null, 'expired after its TTL');
  assert.match(env.evaluate("(() => { try { CacheService.getScriptCache().put('o', {a:1}); return 'no error'; } catch (e) { return e.message; } })()"), /must be a string/);
  const now = env.evaluate('Date.now()');
  assert.ok(Math.abs(now - (Date.now() + 61000)) < 2000, 'Date.now() inside the realm follows the fake clock');
  assert.ok(env.evaluate('new Date() instanceof Date'));

  assert.equal(env.evaluate("PropertiesService.getScriptProperties().getProperty('SESSION_DAYS')"), '3');
  assert.equal(env.evaluate("PropertiesService.getScriptProperties().getProperty('MISSING')"), null);
  env.evaluate("PropertiesService.getScriptProperties().setProperty('N', 5)");
  assert.equal(env.props.get('N'), '5');
});

test('fake tokeninfo endpoint', () => {
  const env = createEnv(noBackend);
  const token = env.registerGoogleUser('a@gmail.com', { name: 'أ' });
  const r = env.evaluate(`(() => {
    const u = 'https://oauth2.googleapis.com/tokeninfo?id_token=';
    const good = UrlFetchApp.fetch(u + encodeURIComponent(${JSON.stringify(token)}), { muteHttpExceptions: true });
    const bad = UrlFetchApp.fetch(u + 'nope', { muteHttpExceptions: true });
    let thrown = 'no error';
    try { UrlFetchApp.fetch(u + 'nope'); } catch (e) { thrown = e.message; }
    return { code: good.getResponseCode(), body: JSON.parse(good.getContentText()),
      badCode: bad.getResponseCode(), badBody: bad.getContentText(), thrown };
  })()`);
  assert.equal(r.code, 200);
  assert.equal(r.body.email, 'a@gmail.com');
  assert.equal(r.body.email_verified, 'true');
  assert.equal(r.body.aud, env.clientIds.web);
  assert.equal(typeof r.body.exp, 'string');
  assert.equal(r.badCode, 400);
  assert.deepEqual(JSON.parse(r.badBody), { error: 'invalid_token' });
  assert.match(r.thrown, /returned code 400/);
});

test('every execution starts with fresh globals (like a new Apps Script execution)', () => {
  const env = createEnv(noBackend);
  env.evaluate('globalThis.leftover = 1');
  assert.equal(env.evaluate('typeof leftover'), 'undefined');
});

test('backend sources, when present, load without errors in the documented order', (t) => {
  const { backendFiles, BACKEND_DIST } = require('./harness');
  const files = backendFiles().map((f) => path.basename(f));
  if (files.length === 0 && !BACKEND_DIST) {
    t.skip('backend/src has no .gs files yet');
    return;
  }
  const env = createEnv(noBackend);
  const loaded = env.loadedFiles;
  if (BACKEND_DIST) {
    // Dist mode: the single deployable bundle is the only file loaded; its sections follow the same order.
    assert.deepEqual(loaded, [path.relative(REPO_ROOT, BACKEND_DIST)]);
    const sections = Array.from(fs.readFileSync(BACKEND_DIST, 'utf8').matchAll(/^\/\/ المصدر: (.+)$/gm), (m) => m[1]);
    assert.equal(sections[0], 'sheets/setup.gs', 'bundle starts with setup.gs');
    const names = sections.slice(1).map((f) => path.basename(f));
    assert.deepEqual(names.slice(0, 2), ['Config.gs', 'Util.gs'], 'then Config.gs and Util.gs');
    assert.deepEqual(names.slice(2), names.slice(2).slice().sort(), 'then the other sources by name');
  } else {
    assert.equal(loaded[0], path.join('sheets', 'setup.gs'));
    const names = loaded.slice(1).map((f) => path.basename(f));
    const expectedHead = ['Config.gs', 'Util.gs'].filter((f) => files.includes(f));
    assert.deepEqual(names.slice(0, expectedHead.length), expectedHead);
  }
  assert.equal(env.evaluate('typeof doPost', { withBackend: true }), 'function', 'doPost is defined');
  assert.equal(env.evaluate('typeof doGet', { withBackend: true }), 'function', 'doGet is defined');
  assert.equal(env.evaluate('typeof setupRummanSheet', { withBackend: true }), 'function', 'setupRummanSheet is defined');
});

test('formatting calls found in setup.gs are chainable no-ops; data methods are never turned into no-ops', () => {
  const { SETUP_FORMATTING } = require('./harness');
  ['setFontFamily', 'setTabColor', 'setRightToLeft', 'setBorder', 'hideColumns', 'merge', 'breakApart',
    'setConditionalFormatRules', 'setFrozenRows'].forEach((m) => assert.ok(SETUP_FORMATTING.includes(m), m));
  ['setValue', 'setValues', 'setFormula', 'clearContent', 'clear', 'setNumberFormat', 'setDataValidation']
    .forEach((m) => assert.equal(SETUP_FORMATTING.includes(m), false, `${m} is a data method`));
  const env = createEnv(noBackend);
  const r = env.evaluate(`(() => {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sh = ss.getSheetByName('البرادات');
    const tryIt = (f) => { try { f(); return 'no error'; } catch (e) { return e.message; } };
    return {
      sheetChain: sh.setTabColor('#fff').setRightToLeft(true).getName(),
      sheetSetValue: tryIt(() => sh.setValue('x')),
      rangeDisplay: tryIt(() => sh.getRange(1, 1).getDisplayValue()),
      dataRange: tryIt(() => sh.getDataRange()),
      deleteRow: tryIt(() => sh.deleteRow(4)),
      builder: typeof SpreadsheetApp.newDataValidation().requireValueInList(['a'], true).setAllowInvalid(false).build(),
      border: SpreadsheetApp.BorderStyle.SOLID,
    };
  })()`);
  assert.equal(r.sheetChain, 'البرادات');
  assert.match(r.sheetSetValue, /not part of the Apps Script subset/);
  assert.match(r.rangeDisplay, /not part of the Apps Script subset/);
  assert.match(r.dataRange, /not part of the Apps Script subset/);
  assert.match(r.deleteRow, /not part of the Apps Script subset/, 'rows can never be deleted through the fake');
  assert.equal(r.builder, 'object');
  assert.equal(r.border, 'SOLID');
});

test('the realm runs in the script time zone like Apps Script (local dates are Africa/Cairo)', () => {
  const env = createEnv(noBackend);
  assert.equal(env.evaluate('new Date(2026, 9, 2).toISOString()'), '2026-10-01T21:00:00.000Z');
  assert.equal(env.evaluate('new Date(2026, 11, 2).toISOString()'), '2026-12-01T22:00:00.000Z');
});

test('fake lock can be busy for a number of attempts only', () => {
  const env = createEnv(noBackend);
  env.lock.setBusy(2);
  const r = env.evaluate(`(() => {
    const l = LockService.getScriptLock();
    const out = [];
    for (let i = 0; i < 3; i++) { try { l.waitLock(25000); out.push('ok'); l.releaseLock(); } catch (e) { out.push('busy'); } }
    return out;
  })()`);
  assert.deepEqual(r, ['busy', 'busy', 'ok']);
  assert.equal(env.lock.isBusy(), false);
  assert.ok(env.lock.ops().some((o) => o.op === 'waitLock' && o.ms === 25000));
});

test('fake spreadsheet structure: insertSheet/getSheets/deleteSheet, getLastRow ignores blank rows, formulas count', () => {
  const env = createEnv(noBackend);
  const r = env.evaluate(`(() => {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const tryIt = (f) => { try { f(); return 'no error'; } catch (e) { return e.message; } };
    const out = {};
    out.dup = tryIt(() => ss.insertSheet('البرادات'));
    const t = ss.insertSheet('مؤقت', 1);
    out.position = ss.getSheets()[1].getName();
    t.getRange(5, 2).setValue('x');
    t.getRange(7, 1).setValue('');
    out.lastRow = t.getLastRow();
    out.lastCol = t.getLastColumn();
    t.getRange(9, 3).setFormula('=1+1');
    out.lastRowFormula = t.getLastRow();
    t.getRange(5, 2).clearContent();
    t.getRange(9, 3).clear();
    out.cleared = t.getLastRow();
    t.appendRow(['a', 'b']);
    out.appended = t.getRange(1, 1, 1, 2).getValues()[0];
    t.insertRowsAfter(t.getMaxRows(), 10);
    out.maxRows = t.getMaxRows();
    ss.deleteSheet(t);
    out.gone = ss.getSheetByName('مؤقت') === null;
    out.id = ss.getId() === ${JSON.stringify(env.spreadsheetId)};
    out.url = ss.getUrl();
    out.tz = ss.getSpreadsheetTimeZone();
    return out;
  })()`);
  assert.match(r.dup, /already exists/);
  assert.equal(r.position, 'مؤقت');
  assert.equal(r.lastRow, 5);
  assert.equal(r.lastCol, 2);
  assert.equal(r.lastRowFormula, 9);
  assert.equal(r.cleared, 0);
  assert.deepEqual(r.appended, ['a', 'b']);
  assert.equal(r.maxRows, 1010);
  assert.equal(r.gone, true);
  assert.equal(r.id, true);
  assert.match(r.url, /^https:\/\/docs\.google\.com\/spreadsheets\/d\//);
  assert.equal(r.tz, 'Africa/Cairo');
});

test('fake CacheService: string values only, TTL capped at 6 h, remove / removeAll', () => {
  const env = createEnv(noBackend);
  env.evaluate(`(() => { const c = CacheService.getScriptCache(); c.put('a', '1', 999999); c.put('b', '2'); c.put('c', '3', 5);
    c.removeAll(['b']); c.remove('c'); })()`);
  assert.equal(env.cache.entry('a').ttl, 21600);
  assert.equal(env.cache.get('b'), null);
  assert.equal(env.cache.get('c'), null);
  env.clock.advance(21600 * 1000 + 1);
  assert.equal(env.cache.get('a'), null);
});

test('createEnv exposes readSheet rows keyed by the row-3 headers, props, cache and lock controls', () => {
  const env = createEnv({ bootstrapAdmin: 'boss@gmail.com', extraProps: { SESSION_DAYS: '2' } });
  assert.equal(env.props.get('BOOTSTRAP_ADMIN_EMAIL'), 'boss@gmail.com');
  assert.equal(env.props.get('SESSION_DAYS'), '2');
  const rows = env.readSheet('item_types');
  assert.equal(rows[0]._row, SCHEMA.firstDataRow);
  assert.equal(rows[0]['الصنف'], 'الصناديق');
  assert.deepEqual(env.readSheet('أصناف التعبئة'), rows, 'by key or by title');
  assert.equal(typeof env.post, 'function');
  assert.equal(typeof env.call, 'function');
  assert.equal(typeof env.loginAs, 'function');
  assert.equal(typeof env.registerGoogleUser('x@gmail.com', { aud: 'a', verified: false, exp: 1, name: 'س' }), 'string');
});
