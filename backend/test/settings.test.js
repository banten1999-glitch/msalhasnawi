'use strict';
/**
 * settings.get / settings.update and item types (docs/API.md section 6).
 */
const test = require('node:test');
const { assert, ok, failField, adminEnv, auditRows, idNum, dataSnapshot, assertNothingWritten } = require('./helpers');

function settingValue(env, key) {
  const row = env.readSheet('settings').find((r) => r['المفتاح'] === key);
  return row ? row['القيمة'] : undefined;
}

test('settings.get returns the values of the الإعدادات sheet', () => {
  const { env, admin } = adminEnv();
  const s = ok(env.call(admin, 'settings.get', {}));
  ['businessName', 'currency', 'currencySymbol', 'timezone', 'moneyDecimals', 'weightDecimals', 'emptyBoxGrams',
    'seasonStart'].forEach((k) => assert.ok(k in s, `settings.${k}`));
  assert.equal(s.businessName, 'حاسبة الحسناوي');
  assert.equal(s.currencySymbol, 'ج.م');
  assert.equal(s.timezone, 'Africa/Cairo');
  assert.equal(s.moneyDecimals, 2);
  assert.equal(s.weightDecimals, 1);
  assert.equal(s.emptyBoxGrams, 1900);
  assert.match(String(s.seasonStart), /^2026-08-01/);
});

test('settings.update writes human units to the sheet and is audited', () => {
  const { env, admin } = adminEnv();
  const auditBefore = auditRows(env).length;
  const s = ok(env.call(admin, 'settings.update', { businessName: 'رمان الصعيد', emptyBoxGrams: 2150,
    currencySymbol: 'جنيه' }));
  assert.equal(s.businessName, 'رمان الصعيد');
  assert.equal(s.emptyBoxGrams, 2150);
  assert.equal(s.currencySymbol, 'جنيه');
  assert.equal(s.timezone, 'Africa/Cairo', 'unspecified settings unchanged');
  assert.equal(settingValue(env, 'اسم النشاط'), 'رمان الصعيد');
  assert.equal(Math.round(Number(settingValue(env, 'وزن الصندوق الفارغ (كغ)')) * 1000), 2150, 'stored in kg');
  const again = ok(env.call(admin, 'settings.get', {}));
  assert.equal(again.emptyBoxGrams, 2150);
  const a = auditRows(env).slice(auditBefore);
  assert.ok(a.some((r) => r['نوع السجل'] === 'إعدادات' && r['الإجراء'] === 'تعديل'), 'audit تعديل إعدادات');
  assert.equal(env.readSheet('settings').length, 11, 'no settings rows added or removed');
});

test('itemTypes.list returns the base item types; itemTypes.save adds (id max+1) and updates', () => {
  const { env, admin } = adminEnv();
  const list = ok(env.call(admin, 'itemTypes.list', {})).itemTypes;
  assert.equal(list.length, 9);
  assert.deepEqual(list[0], { id: 'IT-01', name: 'الصناديق', unit: 'قطعة', order: 1, active: true });
  const added = ok(env.call(admin, 'itemTypes.save', { name: 'شريط لاصق', unit: 'رول', order: 10 })).itemType;
  assert.match(added.id, /^IT-\d+$/);
  assert.equal(idNum(added.id), 10);
  assert.equal(added.name, 'شريط لاصق');
  assert.equal(added.unit, 'رول');
  const row = env.findRow('item_types', added.id);
  assert.equal(row['الصنف'], 'شريط لاصق');
  assert.equal(row['الوحدة الافتراضية'], 'رول');
  const upd = ok(env.call(admin, 'itemTypes.save', { id: 'IT-02', name: 'الباليتات', unit: 'قطعة', active: false })).itemType;
  assert.equal(upd.active, false);
  assert.equal(env.findRow('item_types', 'IT-02')['نشط'], 'لا');
  const after = ok(env.call(admin, 'itemTypes.list', {})).itemTypes;
  assert.equal(after.length, 10);
  assert.equal(after.find((t) => t.id === 'IT-02').active, false);
});

test('settings.update timezone: unknown zones are rejected (formatDate would silently use GMT); real zones accepted', () => {
  const { env, admin } = adminEnv();
  const before = dataSnapshot(env);
  for (const tz of ['Africa/Cairoo', 'Mars/Olympus_Mons', 'Cairo', 'Africa/Cairo; DROP', '']) {
    failField(env.call(admin, 'settings.update', { timezone: tz }), 'timezone', /المنطقة الزمنية/, `timezone ${JSON.stringify(tz)}`);
  }
  assertNothingWritten(env, before, 'invalid time zones');
  assert.equal(ok(env.call(admin, 'settings.update', { timezone: 'Africa/Abidjan' })).timezone, 'Africa/Abidjan',
    'a real zone whose offset is always zero is accepted');
  assert.equal(ok(env.call(admin, 'settings.update', { timezone: 'Asia/Riyadh' })).timezone, 'Asia/Riyadh');
  assert.equal(ok(env.call(admin, 'settings.update', { timezone: 'UTC' })).timezone, 'UTC');
});

test('an unknown time zone typed directly into the settings sheet falls back to Africa/Cairo', () => {
  const { env, admin } = adminEnv();
  const row = env.readSheet('settings').find((r) => r['المفتاح'] === 'المنطقة الزمنية');
  env.setCell('settings', row._row, env.column('settings', 'القيمة'), 'Africa/Kairo');
  const s = ok(env.call(admin, 'settings.get', {}));
  assert.equal(s.timezone, 'Africa/Cairo');
});
