'use strict';
/**
 * Spreadsheet management: sheet.status / sheet.repair / sheet.connect, schema checks, columns located by
 * header name (docs/API.md sections 1, 4, 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, adminEnv, createEnv, newCooler, newFarmer, buy, pay, snapshotIds, assertNoRowsLost, assertIsoInZone,
  approvedPackaging, saveDraft, userSession, uuid, ADMIN, SCHEMA, BUSINESS_TZ, ENTRY_ALL,
} = require('./helpers');

function sheetEntry(status, key) {
  const e = status.sheets.find((s) => s.key === key);
  assert.ok(e, `SheetStatus.sheets has ${key}`);
  return e;
}

test('sheet.status on a freshly set-up spreadsheet', () => {
  const { env, admin } = adminEnv();
  const s = ok(env.call(admin, 'sheet.status', {}), 'sheet.status');
  ['configured', 'spreadsheetId', 'title', 'url', 'connectedAs', 'timezone', 'ok', 'sheets', 'lastWriteAt', 'lastError',
    'checkedAt'].forEach((k) => assert.ok(k in s, `SheetStatus.${k}`));
  assert.equal(s.configured, true);
  assert.equal(s.spreadsheetId, env.spreadsheetId);
  assert.equal(s.title, 'حاسبة الرمان');
  assert.match(String(s.url), new RegExp(env.spreadsheetId));
  assert.equal(s.connectedAs, 'owner@example.com');
  assert.equal(s.ok, true);
  assert.equal(s.lastError, null);
  assertIsoInZone(s.checkedAt, BUSINESS_TZ, 'checkedAt');
  assert.deepEqual(s.sheets.map((x) => x.key).sort(), SCHEMA.sheets.map((d) => d.key).sort());
  for (const e of s.sheets) {
    const def = SCHEMA.sheets.find((d) => d.key === e.key);
    assert.equal(e.title, def.title);
    assert.equal(e.exists, true, `${e.key} exists`);
    assert.ok(Number.isInteger(e.rows), `${e.key}.rows integer`);
    assert.deepEqual(e.missingColumns, [], `${e.key} has no missing columns`);
    assert.deepEqual(e.extraColumns, [], `${e.key} has no extra columns`);
  }
  assert.equal(env.lastRequest.writes.length, 0, 'sheet.status is read-only');
});

test('lastWriteAt / LAST_WRITE_AT are updated by mutations', () => {
  const { env, admin } = adminEnv();
  newCooler(env, admin);
  assert.ok(env.props.get('LAST_WRITE_AT'), 'LAST_WRITE_AT property written');
  const s = ok(env.call(admin, 'sheet.status', {}));
  assert.ok(s.lastWriteAt, 'lastWriteAt reported');
});

test('sheet.status lists a missing column after its header cell is deleted; sheet.repair restores it keeping data', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f1 = newFarmer(env, admin, 'حسن البدري', { notes: 'ملاحظة أولى', phone: '01001234567' });
  const f2 = newFarmer(env, admin, 'محمود');
  buy(env, admin, c, f1);
  const ids = snapshotIds(env);
  const farmersBefore = env.readSheet('farmers').map((r) => [r['المعرّف'], r['الاسم'], r['الهاتف']]);

  env.setCell('farmers', SCHEMA.headerRow, env.column('farmers', 'القرية / المنطقة'), '');
  env.ss.deleteSheet(env.ss.getSheetByName('أصناف التعبئة'));
  const broken = ok(env.call(admin, 'sheet.status', {}));
  assert.equal(broken.ok, false);
  assert.deepEqual(sheetEntry(broken, 'farmers').missingColumns, ['القرية / المنطقة']);
  assert.equal(sheetEntry(broken, 'item_types').exists, false);
  assert.deepEqual(sheetEntry(broken, 'purchases').missingColumns, []);

  const repaired = ok(env.call(admin, 'sheet.repair', {}), 'sheet.repair');
  assert.equal(repaired.ok, true, 'status after repair is ok');
  assert.deepEqual(sheetEntry(repaired, 'farmers').missingColumns, []);
  assert.equal(sheetEntry(repaired, 'item_types').exists, true);
  assert.ok(env.headers('farmers').includes('القرية / المنطقة'), 'header restored');
  assert.deepEqual(env.readSheet('farmers').map((r) => [r['المعرّف'], r['الاسم'], r['الهاتف']]), farmersBefore,
    'farmer rows kept');
  assertNoRowsLost(env, Object.fromEntries(Object.entries(ids).filter(([t]) => t !== 'أصناف التعبئة')), 'sheet.repair');
  assert.equal(env.readSheet('item_types').length, 9, 'recreated sheet gets its base rows');
  assert.equal(env.readSheet('purchases').length, 1);
  assert.equal(env.readSheet('coolers').length, 1);
  assert.ok(env.readSheet('users').length >= 1);
  const again = ok(env.call(admin, 'sheet.status', {}));
  assert.equal(again.ok, true);
  ok(env.call(admin, 'farmers.update', { id: f2.id, expectedVersion: f2.version, village: 'أسيوط' }),
    'the restored column is usable');
  assert.equal(env.findRow('farmers', f2.id)['القرية / المنطقة'], 'أسيوط');
});

test('a missing required column makes the affected action fail with SHEET_SCHEMA (details.missing), nothing written', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  env.setCell('purchases', SCHEMA.headerRow, env.column('purchases', 'عدد الصناديق'), '');
  const res = env.call(admin, 'purchases.create', { coolerId: c.id, farmerId: f.id, boxes: 5, avgWeightGrams: 10000,
    weightMethod: 'direct', pricePerKgPiasters: 1500, payment: { mode: 'none' } });
  const e = fail(res, 'SHEET_SCHEMA');
  assert.ok(Array.isArray(e.details && e.details.missing), 'details.missing is a list');
  const entry = e.details.missing.find((m) => m.sheet === 'purchases' || m.sheet === 'مشتريات الرمان');
  assert.ok(entry, `details.missing names the purchases sheet: ${JSON.stringify(e.details)}`);
  assert.ok(entry.columns.includes('عدد الصناديق'));
  assert.equal(env.readSheet('purchases').length, 0);
  ok(env.call(admin, 'sheet.status', {}), 'sheet.status still works while the schema is broken');
});

test('columns are located by header name, not by position; extra columns are reported', () => {
  const { env, admin } = adminEnv();
  const sh = env.ss.getSheetByName('مشتريات الرمان');
  sh.insertColumnsAfter(1, 1);
  sh.getRange(SCHEMA.headerRow, 2).setValue('عمود إضافي');
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  const row = env.findRow('purchases', p.id);
  assert.equal(row['عمود إضافي'], '', 'the extra column is left alone');
  assert.equal(row['معرّف البراد'], c.id);
  assert.equal(row['عدد الصناديق'], 50);
  assert.equal(row['إجمالي السعر (ج.م)'], 8250);
  assert.equal(row['الحالة'], 'فعّالة');
  const s = ok(env.call(admin, 'sheet.status', {}));
  assert.deepEqual(sheetEntry(s, 'purchases').extraColumns, ['عمود إضافي']);
  assert.deepEqual(sheetEntry(s, 'purchases').missingColumns, []);
  assert.equal(s.ok, true, 'extra columns do not break the schema');
});

test('sheet.connect to an unknown or inaccessible id -> SHEET_UNREACHABLE, nothing saved', () => {
  const { env, admin } = adminEnv();
  fail(env.call(admin, 'sheet.connect', { spreadsheet: '1NoSuchSpreadsheetIdAtAll000000000000000000' }), 'SHEET_UNREACHABLE');
  const locked = env.createSpreadsheet({ name: 'ملف بلا صلاحية', accessible: false, setup: false });
  fail(env.call(admin, 'sheet.connect', { spreadsheet: `https://docs.google.com/spreadsheets/d/${locked}/edit#gid=0` }),
    'SHEET_UNREACHABLE');
  assert.equal(env.props.get('SPREADSHEET_ID'), null, 'SPREADSHEET_ID unchanged');
  ok(env.call(admin, 'coolers.list', { status: 'all' }), 'the current spreadsheet still works');
});

test('sheet.connect by URL saves SPREADSHEET_ID, warns that old data is not moved, and later writes go there', () => {
  const { env, admin } = adminEnv();
  newCooler(env, admin, { name: 'في الملف القديم' });
  const other = env.createSpreadsheet({ name: 'ملف الموسم الجديد' });
  const res = ok(env.call(admin, 'sheet.connect', { spreadsheet: `https://docs.google.com/spreadsheets/d/${other}/edit#gid=0` }),
    'sheet.connect');
  assert.equal(res.spreadsheetId, other);
  assert.equal(res.title, 'ملف الموسم الجديد');
  assert.equal(typeof res.warning, 'string');
  assert.match(res.warning, /[؀-ۿ]/, 'Arabic warning');
  assert.equal(env.props.get('SPREADSHEET_ID'), other);
  const admin2 = env.loginAs(ADMIN);
  const c = newCooler(env, admin2, { name: 'في الملف الجديد' });
  assert.equal(c.no, 1, 'numbering restarts in the new file');
  assert.equal(env.readSheet('coolers', other).length, 1);
  assert.equal(env.readSheet('coolers', other)[0]['الاسم / الوصف'], 'في الملف الجديد');
  assert.equal(env.readSheet('coolers').length, 1, 'the bound file is untouched');
  assert.equal(env.readSheet('coolers')[0]['الاسم / الوصف'], 'في الملف القديم');
  const st = ok(env.call(admin2, 'sheet.status', {}));
  assert.equal(st.spreadsheetId, other);
  const plain = ok(env.call(admin2, 'sheet.connect', { spreadsheet: env.spreadsheetId }), 'connect back by plain id');
  assert.equal(plain.spreadsheetId, env.spreadsheetId);
});

test('SPREADSHEET_ID pointing to a missing file -> SHEET_UNREACHABLE', () => {
  const env = createEnv({ extraProps: { SPREADSHEET_ID: '1MissingSpreadsheet0000000000000000000000000' } });
  const res = env.post({ action: 'auth.login', session: null, requestId: uuid(),
    payload: { idToken: env.registerGoogleUser('karim@gmail.com') } });
  fail(res, 'SHEET_UNREACHABLE');
});

test('no bound spreadsheet and no SPREADSHEET_ID -> SHEET_NOT_CONFIGURED', () => {
  const env = createEnv({ bound: false });
  const res = env.post({ action: 'auth.login', session: null, requestId: uuid(),
    payload: { idToken: env.registerGoogleUser('karim@gmail.com') } });
  fail(res, 'SHEET_NOT_CONFIGURED');
});

test('sheet.repair on a full spreadsheet changes no cell of any data sheet and keeps extra sheets and columns', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin, { name: 'براد' });
  const f = newFarmer(env, admin, 'حسن البدري', { phone: '01001234567', village: 'أسيوط' });
  const d = buy(env, admin, c, f, { payment: { mode: 'partial', amountPiasters: 100000, method: 'bank' } });
  pay(env, admin, 'purchase', d.purchase.id, 5000);
  approvedPackaging(env, admin, c, [{ name: 'الصناديق', quantity: 10, unit: 'قطعة', unitPricePiasters: 1500 }]);
  saveDraft(env, admin, { supplier: 'مورد', items: [{ name: 'الشمبر', unit: 'رزمة' }] });
  userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(admin, 'settings.update', { businessName: 'رمان الصعيد' }));
  // The owner's own additions: an extra column with data, an extra sheet with notes, an empty extra sheet.
  const sh = env.ss.getSheetByName('مشتريات الرمان');
  const extraCol = sh.getLastColumn() + 1;
  if (extraCol > sh.getMaxColumns()) sh.insertColumnsAfter(sh.getMaxColumns(), extraCol - sh.getMaxColumns());
  sh.getRange(SCHEMA.headerRow, extraCol).setValue('ملاحظة المالك');
  sh.getRange(SCHEMA.firstDataRow, extraCol).setValue('راجعت الوزن');
  env.ss.insertSheet('ملاحظاتي').getRange(1, 1, 2, 2).setValues([['بند', 'قيمة'], ['إيجار', 500]]);
  env.ss.insertSheet('Sheet9');
  const titles = SCHEMA.sheets.map((def) => def.title).concat(['ملاحظاتي']);
  const before = Object.fromEntries(titles.map((t) => [t, env.values(t)]));
  const namesBefore = env.sheetNames();

  const st = ok(env.call(admin, 'sheet.repair', {}), 'sheet.repair');
  assert.equal(st.ok, true);
  for (const t of titles) {
    if (t === 'سجل التعديلات') continue;
    assert.deepEqual(env.values(t), before[t], `${t}: every cell kept`);
  }
  const audit = env.values('سجل التعديلات');
  assert.deepEqual(audit.slice(0, before['سجل التعديلات'].length), before['سجل التعديلات'], 'existing audit rows kept');
  assert.equal(audit.length, before['سجل التعديلات'].length + 1, 'the repair adds exactly its own audit row');
  assert.equal(env.readSheet('audit').pop()['نوع السجل'], 'ملف');
  namesBefore.forEach((n) => assert.ok(env.sheetNames().includes(n), `sheet «${n}» kept`));
  assert.ok(env.sheetNames().includes('Sheet9'), 'an empty extra sheet is not deleted by a request');
  assert.deepEqual(env.world.log.deletedSheets.filter((x) => x.phase === 'request'), [], 'no deleteSheet during the request');
  assert.deepEqual(sheetEntry(st, 'purchases').extraColumns, ['ملاحظة المالك']);
  ok(env.call(admin, 'dashboard.get', { period: 'all' }), 'the data still reads after repair');
});

test('sheet.repair sets the file time zone only while the file has no records (changing it later shifts stored times)', () => {
  const { env, admin } = adminEnv();
  newCooler(env, admin);
  env.ss.setSpreadsheetTimeZone('Etc/UTC');
  const st = ok(env.call(admin, 'sheet.repair', {}));
  assert.equal(env.spreadsheetState().tz, 'Etc/UTC', 'a file with records keeps its time zone');
  assert.equal(st.timezone, 'Etc/UTC', 'SheetStatus reports the file time zone');

  const empty = env.createSpreadsheet({ name: 'ملف فارغ', setup: false });
  assert.equal(env.spreadsheetState(empty).tz, 'Etc/UTC');
  const connected = ok(env.call(admin, 'sheet.connect', { spreadsheet: empty }), 'connect an empty file');
  assert.equal(connected.ok, false, 'the empty file still needs a repair');
  const repaired = ok(env.call(admin, 'sheet.repair', {}), 'repair the empty file');
  assert.equal(repaired.ok, true);
  assert.equal(env.spreadsheetState(empty).tz, BUSINESS_TZ, 'an empty file gets the business time zone');
  assert.equal(repaired.timezone, BUSINESS_TZ);
});
