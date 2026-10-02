/**
 * حاسبة الرمان — إعداد ملف Google Sheets المركزي
 *
 * الاستخدام:
 *   1. أنشئ ملف Google Sheets جديدًا (sheets.new).
 *   2. من القائمة: الإضافات ← Apps Script، والصق هذا الملف كاملًا مكان المحتوى، ثم احفظ.
 *   3. اختر الدالة setupRummanSheet واضغط «تشغيل»، ووافق على الصلاحيات.
 *
 * التشغيل آمن للتكرار: يُنشئ الصفحات والأعمدة الناقصة فقط، ويعيد التنسيق،
 * ولا يمسح أي بيانات موجودة في صفحات البيانات.
 *
 * هذا الملف مولَّد من sheets/build_sheet.py — عدّل المصدر هناك ثم أعد التوليد.
 */

const SCHEMA = __SCHEMA__;

const BASE_ROWS = __BASE_ROWS__;

const VALUE_STYLES = __VALUE_STYLES__;

const SUMMARY = __SUMMARY__;

const FONT = 'Cairo';
const SUMMARY_TITLE = 'لوحة الملخص';
const MIN_ROWS = 1000;
const C = {
  red: '#A00B1E', redL: '#FBE9EC', green: '#1F6B2C', greenL: '#E5F1E9', ivory: '#FAF6EE',
  white: '#FFFFFF', ink: '#1C1714', ink2: '#5E554E', muted: '#6F655D', amber: '#8A4B00',
  amberL: '#FDF0D5', grayL: '#EEE9E2', line: '#E3DACC', idHead: '#3B4A3F',
};

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('حاسبة الرمان')
    .addItem('إعداد الصفحات والتنسيق', 'setupRummanSheet')
    .addToUi();
}

function setupRummanSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  ss.setSpreadsheetTimeZone('Africa/Cairo');
  SCHEMA.sheets.forEach((def, i) => buildDataSheet_(ss, def, i + 2));
  buildSummary_(ss);
  removeEmptyDefaultSheets_(ss);
  ss.setActiveSheet(ss.getSheetByName(SUMMARY_TITLE));
  ss.toast('تم إعداد الصفحات والتنسيق دون مسح أي بيانات.', 'حاسبة الرمان', 6);
}

function buildDataSheet_(ss, def, position) {
  const headerRow = SCHEMA.headerRow;
  const firstRow = SCHEMA.firstDataRow;
  let sh = ss.getSheetByName(def.title);
  const isNew = !sh;
  if (isNew) sh = ss.insertSheet(def.title, position - 1);
  sh.setRightToLeft(true);
  sh.setTabColor(def.tabColor);

  // ربط كل عمود في المخطط بموقعه الفعلي، وإضافة الناقص في النهاية فقط.
  const lastCol = Math.max(sh.getLastColumn(), 1);
  const existing = isNew ? [] : sh.getRange(headerRow, 1, 1, lastCol).getValues()[0].map(String);
  let next = existing.filter(String).length ? existing.length + 1 : 1;
  const positions = def.columns.map(col => {
    const found = existing.indexOf(col.name);
    return found >= 0 ? found + 1 : next++;
  });
  const width = Math.max(next - 1, ...positions);
  if (sh.getMaxColumns() < width) sh.insertColumnsAfter(sh.getMaxColumns(), width - sh.getMaxColumns());
  if (sh.getMaxRows() < MIN_ROWS) sh.insertRowsAfter(sh.getMaxRows(), MIN_ROWS - sh.getMaxRows());
  const maxRows = sh.getMaxRows();
  const dataRows = maxRows - firstRow + 1;

  // العنوان والوصف دون دمج خلايا، حتى يمكن تثبيت الأعمدة الأولى.
  const band = sh.getRange(1, 1, 2, width);
  band.breakApart().clearContent();
  sh.getRange(1, 1, 1, width).setBackground(def.tabColor);
  sh.getRange(2, 1, 1, width).setBackground(C.ivory);
  sh.getRange(1, 1).setValue(def.title)
    .setFontFamily(FONT).setFontSize(20).setFontWeight('bold').setFontColor(C.white)
    .setHorizontalAlignment('right').setVerticalAlignment('middle').setWrap(false);
  sh.getRange(2, 1).setValue(def.description)
    .setFontFamily(FONT).setFontSize(12).setFontColor(C.ink2)
    .setHorizontalAlignment('right').setVerticalAlignment('middle').setWrap(false);
  sh.setRowHeight(1, 44);
  sh.setRowHeight(2, 30);

  const rules = [];
  def.columns.forEach((col, i) => {
    const c = positions[i];
    sh.getRange(headerRow, c).setValue(col.name)
      .setFontFamily(FONT).setFontSize(13).setFontWeight('bold').setFontColor(C.white)
      .setBackground(col.kind === 'id' ? C.idHead : C.green)
      .setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true);
    sh.setColumnWidth(c, Math.round(col.width * 7.5 + 10));
    const body = sh.getRange(firstRow, c, dataRows, 1);
    let color = C.ink;
    if (col.kind === 'id') color = C.muted;
    if (col.emphasis === 'paid') color = C.green;
    if (col.emphasis === 'due') color = C.amber;
    body.setFontFamily(FONT).setFontSize(col.kind === 'id' ? 10 : 13).setFontColor(color)
      .setFontWeight(['bold', 'paid', 'due'].indexOf(col.emphasis) >= 0 ? 'bold' : 'normal')
      .setNumberFormat(col.numberFormat).setHorizontalAlignment(col.align)
      .setVerticalAlignment('middle').setWrap(col.kind === 'long');
    if (col.hidden) sh.hideColumns(c); else sh.showColumns(c);
    if (col.options) {
      body.setDataValidation(SpreadsheetApp.newDataValidation()
        .requireValueInList(col.options, true).setAllowInvalid(false)
        .setHelpText('اختر قيمة من القائمة.').build());
      col.options.forEach(opt => {
        const st = VALUE_STYLES[opt];
        if (!st) return;
        const rule = SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo(opt)
          .setBackground('#' + st[0]).setFontColor('#' + st[1]).setBold(true);
        if (st[2]) rule.setStrikethrough(true);
        rules.push(rule.setRanges([body]).build());
      });
    }
  });
  sh.setRowHeight(headerRow, 48);
  sh.setRowHeights(firstRow, dataRows, 28);
  sh.getRange(firstRow, 1, dataRows, width)
    .setBorder(null, true, true, true, true, true, C.line, SpreadsheetApp.BorderStyle.SOLID);

  const idCol = columnLetter_(positions[0]);
  rules.push(SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied(`=AND(ISODD(ROW()),$${idCol}${firstRow}<>"")`)
    .setBackground(C.ivory).setRanges([sh.getRange(firstRow, 1, dataRows, width)]).build());
  sh.setConditionalFormatRules(rules);

  sh.setFrozenRows(headerRow);
  sh.setFrozenColumns(def.freezeColumns);
  if (!sh.getFilter()) sh.getRange(headerRow, 1, maxRows - headerRow + 1, width).createFilter();

  // صفوف أولية (الإعدادات وأصناف التعبئة) تُكتب فقط إن كانت الصفحة فارغة.
  const base = BASE_ROWS[def.key];
  if (base && sh.getLastRow() < firstRow) {
    const values = base.map(r => r.map(v => (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) ? new Date(v) : v));
    const out = values.map(r => {
      const row = new Array(width).fill('');
      r.forEach((v, i) => { row[positions[i] - 1] = v === null ? '' : v; });
      return row;
    });
    sh.getRange(firstRow, 1, out.length, width).setValues(out);
  }
}

function buildSummary_(ss) {
  let sh = ss.getSheetByName(SUMMARY_TITLE);
  if (!sh) sh = ss.insertSheet(SUMMARY_TITLE, 0);
  // صفحة الملخص محسوبة بالكامل، فإعادة بنائها لا تمس أي بيانات.
  sh.clear();
  sh.getRange(1, 1, sh.getMaxRows(), sh.getMaxColumns()).breakApart();
  sh.clearConditionalFormatRules();
  ss.setActiveSheet(sh);
  ss.moveActiveSheet(1);
  sh.setRightToLeft(true);
  sh.setHiddenGridlines(true);
  sh.setTabColor(C.red);
  sh.setColumnWidth(1, 24);
  for (let c = 2; c <= 13; c++) sh.setColumnWidth(c, 130);

  sh.getRange('B1:L1').merge().setValue('حاسبة الرمان — ملخص الموسم')
    .setFontFamily(FONT).setFontSize(24).setFontWeight('bold').setFontColor(C.white).setBackground(C.red)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(1, 56);
  sh.getRange('B2:L2').merge().setValue('تتحدث هذه الأرقام تلقائيًا من الصفحات الأخرى. لا تكتب في هذه الصفحة.')
    .setFontFamily(FONT).setFontSize(12).setFontColor(C.ink2).setBackground(C.ivory)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(2, 30);

  const palette = {
    plain: [C.grayL, C.white, C.ink, C.ink2], value: [C.redL, C.white, C.red, C.red],
    paid: [C.greenL, C.greenL, C.green, C.green], due: [C.amberL, C.amberL, C.amber, C.amber],
  };
  let row = SUMMARY.cardRow;
  SUMMARY.cards.forEach(line => {
    line.forEach((card, k) => {
      const [label, formula, fmt, kind] = card;
      const [labBg, valBg, valFg, labFg] = palette[kind];
      const lab = sh.getRange(row, 2 + 2 * k, 1, 2).merge();
      lab.setValue(label).setFontFamily(FONT).setFontSize(12).setFontWeight('bold').setFontColor(labFg)
        .setBackground(labBg).setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true);
      const val = sh.getRange(row + 1, 2 + 2 * k, 1, 2).merge();
      val.setFormula(formula).setNumberFormat(fmt).setFontFamily(FONT).setFontSize(22).setFontWeight('bold')
        .setFontColor(valFg).setBackground(valBg).setHorizontalAlignment('center').setVerticalAlignment('middle');
      sh.getRange(row, 2 + 2 * k, 2, 2)
        .setBorder(true, true, true, true, null, null, C.white, SpreadsheetApp.BorderStyle.SOLID_MEDIUM);
    });
    sh.setRowHeight(row, 32);
    sh.setRowHeight(row + 1, 48);
    sh.setRowHeight(row + 2, 12);
    row += 3;
  });

  const top = SUMMARY.tableTitleRow;
  sh.getRange(top, 2, 1, 11).merge().setValue('ملخص البرادات')
    .setFontFamily(FONT).setFontSize(18).setFontWeight('bold').setFontColor(C.white).setBackground(C.green)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(top, 40);
  sh.getRange(top + 1, 2, 1, 11).setValues([SUMMARY.tableHeads])
    .setFontFamily(FONT).setFontSize(12).setFontWeight('bold').setFontColor(C.ink).setBackground(C.greenL)
    .setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true)
    .setBorder(null, null, true, null, null, null, C.green, SpreadsheetApp.BorderStyle.SOLID_MEDIUM);
  sh.setRowHeight(top + 1, 44);

  const first = SUMMARY.tableFirstRow;
  const n = SUMMARY.tableRows.length;
  const table = sh.getRange(first, 2, n, 11);
  table.setFormulas(SUMMARY.tableRows).setFontFamily(FONT).setFontSize(13)
    .setHorizontalAlignment('center').setVerticalAlignment('middle')
    .setBorder(null, null, true, null, null, true, C.line, SpreadsheetApp.BorderStyle.SOLID);
  SUMMARY.tableFormats.forEach((fmt, j) => sh.getRange(first, 2 + j, n, 1).setNumberFormat(fmt));
  sh.getRange(first, 3, n, 1).setHorizontalAlignment('right');
  [0, 6, 7, 8, 10].forEach(j => sh.getRange(first, 2 + j, n, 1).setFontWeight('bold'));
  sh.getRange(first, 9, n, 1).setFontColor(C.green);
  sh.getRange(first, 10, n, 1).setFontColor(C.amber);
  sh.setRowHeights(first, n, 28);

  const status = sh.getRange(first, 4, n, 1);
  sh.setConditionalFormatRules([
    SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo('مفتوح')
      .setBackground(C.greenL).setFontColor(C.green).setBold(true).setRanges([status]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo('مقفّل')
      .setBackground(C.grayL).setFontColor('#4A423C').setBold(true).setRanges([status]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenFormulaSatisfied(`=AND(ISODD(ROW()),$B${first}<>"")`)
      .setBackground(C.ivory).setRanges([table]).build(),
  ]);
  sh.setFrozenRows(2);
}

function removeEmptyDefaultSheets_(ss) {
  const keep = new Set([SUMMARY_TITLE, ...SCHEMA.sheets.map(s => s.title)]);
  ss.getSheets().forEach(sh => {
    if (!keep.has(sh.getName()) && sh.getLastRow() === 0 && sh.getLastColumn() === 0) ss.deleteSheet(sh);
  });
}

function columnLetter_(n) {
  let s = '';
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}
