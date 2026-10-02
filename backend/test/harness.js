'use strict';
/**
 * Node test harness for the Apps Script backend (docs/API.md section 8).
 *
 * Every request runs in a FRESH node:vm context, exactly like a new Apps Script execution:
 * top-level code of sheets/setup.gs and backend/src/*.gs is evaluated again and global
 * variables do not survive between requests. Persistent state (spreadsheets, script
 * properties, cache, lock, Google tokens, clock) lives in a host-side "world" object that
 * the fake services read and write.
 *
 * The fake services are evaluated INSIDE each vm context so that every array, Date, Error and
 * object handed to the backend belongs to the backend's own realm (instanceof Date / Array /
 * Error behave like in Apps Script).
 *
 * Only Node built-ins are used.
 */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETUP_GS = path.join(REPO_ROOT, 'sheets', 'setup.gs');
const SCHEMA_JSON = path.join(REPO_ROOT, 'sheets', 'schema.json');
const BACKEND_SRC = process.env.RUMMAN_BACKEND_SRC
  ? path.resolve(process.env.RUMMAN_BACKEND_SRC)
  : path.join(REPO_ROOT, 'backend', 'src');

const SCHEMA = JSON.parse(fs.readFileSync(SCHEMA_JSON, 'utf8'));
const SUMMARY_TITLE = 'لوحة الملخص';
const OWNER_EMAIL = 'owner@example.com';
const SCRIPT_TIME_ZONE = 'Africa/Cairo';
const EXEC_TIMEOUT_MS = 20000;

const CLIENT_IDS = Object.freeze({
  web: '833981951758-668sjormn0kp8lm4e8c0ioltdr0ctip8.apps.googleusercontent.com',
  ios: '833981951758-pb57t33tr66q4b8c3r9tsd3gnbs4doi5.apps.googleusercontent.com',
  android: '833981951758-c4f37gpodur13gg933ka3hi14359alg1.apps.googleusercontent.com',
});

// ---------------------------------------------------------------------------------------------
// Host bridge: the only host functions the in-realm fake may call. Inputs/outputs are primitives
// or arrays of numbers, so nothing host-realm leaks into the backend.
// ---------------------------------------------------------------------------------------------
const hostBridge = Object.freeze({
  hmacSha256(valueBytes, keyBytes) {
    const value = Buffer.from(Uint8Array.from(valueBytes, (b) => b & 0xff));
    const key = Buffer.from(Uint8Array.from(keyBytes, (b) => b & 0xff));
    return Array.from(crypto.createHmac('sha256', key).update(value).digest());
  },
  utf8Encode(str) {
    return Array.from(Buffer.from(String(str), 'utf8'));
  },
  utf8Decode(bytes) {
    return Buffer.from(Uint8Array.from(bytes, (b) => b & 0xff)).toString('utf8');
  },
  base64Encode(bytes) {
    return Buffer.from(Uint8Array.from(bytes, (b) => b & 0xff)).toString('base64');
  },
  base64Decode(str) {
    const s = String(str);
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(s)) return null;
    const bare = s.replace(/=+$/, '');
    if (bare.length % 4 === 1) return null;
    if (s.length !== bare.length && s.length % 4 !== 0) return null;
    return Array.from(Buffer.from(bare, 'base64'));
  },
  uuid() {
    return crypto.randomUUID();
  },
  randomId(len) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    const bytes = crypto.randomBytes(len);
    let out = '';
    for (let i = 0; i < len; i++) out += alphabet[bytes[i] % alphabet.length];
    return out;
  },
});

// ---------------------------------------------------------------------------------------------
// The fake Apps Script services. This function is serialised with toString() and evaluated
// inside every vm context, so it must not reference anything from this module's scope.
// ---------------------------------------------------------------------------------------------
function installFakeAppsScript(world, host) {
  'use strict';
  const G = globalThis;
  const RealDate = G.Date;
  const toStr = Object.prototype.toString;

  // ----- clock -------------------------------------------------------------------------------
  function nowMs() { return RealDate.now() + world.clock.offsetMs; }
  function FakeDate(...args) {
    if (!new.target) return new RealDate(nowMs()).toString();
    return Reflect.construct(RealDate, args.length ? args : [nowMs()], new.target);
  }
  Object.setPrototypeOf(FakeDate, RealDate);
  FakeDate.prototype = RealDate.prototype;
  FakeDate.now = function now() { return nowMs(); };
  Object.defineProperty(FakeDate, 'name', { value: 'Date' });
  G.Date = FakeDate;

  // ----- helpers -----------------------------------------------------------------------------
  function gasError(message) {
    const e = new Error(message);
    e.name = 'Exception';
    return e;
  }
  function subsetError(type, prop) {
    return gasError(`Fake Apps Script: ${type}.${String(prop)} is not part of the Apps Script subset ` +
      'listed in docs/API.md section 8 (and is not a formatting call used by sheets/setup.gs).');
  }
  function isDate(v) { return toStr.call(v) === '[object Date]'; }
  function nextSeq() { world.seq += 1; return world.seq; }
  function colLetter(n) {
    let s = '';
    while (n > 0) { const m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = Math.floor((n - 1) / 26); }
    return s;
  }
  function isInt(n) { return typeof n === 'number' && Number.isInteger(n); }

  const PASSIVE = new Set(['then', 'toJSON', 'inspect', 'constructor', 'nodeType', 'asymmetricMatch',
    '$$typeof', '@@__IMMUTABLE_ITERABLE__@@', '_isMockFunction']);

  // Strict wrapper: unknown members throw a clear error when called. `formatting` lists the
  // chainable no-op methods (formatting calls from setup.gs and their close relatives).
  function strict(target, typeName, formatting) {
    let proxy = null;
    proxy = new Proxy(target, {
      get(t, prop, recv) {
        if (typeof prop === 'symbol' || prop in t) return Reflect.get(t, prop, recv);
        if (PASSIVE.has(prop)) return undefined;
        if (formatting && formatting.has(prop)) {
          return function formattingNoOp() {
            world.log.formatting += 1;
            return proxy;
          };
        }
        return function unsupported() { throw subsetError(typeName, prop); };
      },
    });
    return proxy;
  }

  const RANGE_FORMATTING = new Set([
    'breakApart', 'merge', 'mergeAcross', 'mergeVertically', 'setBackground', 'setBackgrounds',
    'setFontFamily', 'setFontFamilies', 'setFontSize', 'setFontSizes', 'setFontWeight', 'setFontWeights',
    'setFontColor', 'setFontColors', 'setFontStyle', 'setFontStyles', 'setFontLine', 'setFontLines',
    'setHorizontalAlignment', 'setHorizontalAlignments', 'setVerticalAlignment', 'setVerticalAlignments',
    'setWrap', 'setWraps', 'setWrapStrategy', 'setWrapStrategies', 'setBorder', 'setTextDirection',
    'setTextRotation', 'setNumberFormats', 'clearFormat', 'clearDataValidations', 'clearNote',
    'setNote', 'setShowHyperlink', 'setVerticalText', 'activate',
  ]);
  const SHEET_FORMATTING = new Set([
    'setRightToLeft', 'setTabColor', 'setRowHeight', 'setRowHeights', 'setRowHeightsForced',
    'setColumnWidth', 'setColumnWidths', 'hideColumns', 'showColumns', 'hideRows', 'showRows',
    'unhideColumn', 'unhideRow', 'hideColumn', 'hideRow', 'setConditionalFormatRules',
    'clearConditionalFormatRules', 'setFrozenRows', 'setFrozenColumns', 'setHiddenGridlines',
    'autoResizeColumn', 'autoResizeColumns', 'autoResizeRows', 'clearFormats', 'activate',
  ]);

  // ----- cell storage ------------------------------------------------------------------------
  function findRect(list, r, c) {
    for (let i = list.length - 1; i >= 0; i--) {
      const x = list[i];
      if (r >= x[0] && r <= x[2] && c >= x[1] && c <= x[3]) return x;
    }
    return null;
  }
  function getCell(sh, r, c) {
    const row = sh.rows[r - 1];
    if (!row) return '';
    const v = row[c - 1];
    return v === undefined ? '' : v;
  }
  function putCell(sh, r, c, v) {
    let row = sh.rows[r - 1];
    if (!row) { row = []; sh.rows[r - 1] = row; }
    row[c - 1] = v;
    delete sh.formulas[r + ':' + c];
  }
  function cloneOut(v) { return isDate(v) ? new RealDate(v.getTime()) : v; }
  function sheetTz(ssState) { return ssState.tz || 'Etc/UTC'; }

  // A string written with setValue(s) is parsed like typed input unless the cell is plain text.
  function coerceString(s, ssState) {
    if (/^\s*[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?\s*$/.test(s)) return Number(s);
    const m = /^(\d{4})-(\d{2})-(\d{2})(?: (\d{1,2}):(\d{2})(?::(\d{2}))?)?$/.exec(s);
    if (m) return wallTimeToDate(+m[1], +m[2], +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0), sheetTz(ssState));
    return s;
  }
  function normalizeIn(v, sh, ssState, r, c) {
    if (v === null || v === undefined) return '';
    if (typeof v === 'number' || typeof v === 'boolean') return v;
    if (isDate(v)) return new RealDate(v.getTime());
    if (typeof v === 'string') {
      const fmt = findRect(sh.formats, r, c);
      if (fmt && fmt[4] === '@') return v;
      return coerceString(v, ssState);
    }
    world.log.anomalies.push({ sheet: sh.name, row: r, col: c, type: typeof v, value: String(v) });
    return String(v);
  }
  function checkValidation(sh, r, c, v) {
    if (v === '') return;
    const rect = findRect(sh.validations, r, c);
    if (!rect || !rect[4]) return;
    const rule = rect[4];
    if (rule.allowInvalid || !rule.list) return;
    const ok = rule.list.some((x) => x === v || String(x) === String(v) && typeof v === 'string');
    if (!ok) {
      throw gasError(`The data you entered in cell ${colLetter(c)}${r} violates the data validation rules ` +
        `set on this cell. Please enter one of the following values: ${rule.list.join(', ')}.`);
    }
  }
  function beforeWrite(sh, op, r, c, nr, nc) {
    const seq = nextSeq();
    world.log.writes.push({ seq, phase: world.phase, op, sheet: sh.name, row: r, col: c, numRows: nr,
      numCols: nc, lockHeld: !!world.lock.held });
    if (world.phase !== 'request') return;
    for (const f of world.faults) {
      if (f.remaining > 0 && f.sheet === sh.name && (!f.ops || f.ops.indexOf(op) >= 0)) {
        f.remaining -= 1;
        f.fired += 1;
        throw gasError(f.message);
      }
    }
  }
  function logRead(sh, op, r, c, nr, nc) {
    world.log.reads.push({ seq: nextSeq(), phase: world.phase, op, sheet: sh.name, row: r, col: c,
      numRows: nr, numCols: nc });
  }
  function lastRowOf(sh) {
    let last = 0;
    for (let i = sh.rows.length - 1; i >= 0; i--) {
      const row = sh.rows[i];
      if (row && row.some((v) => v !== '' && v !== undefined)) { last = i + 1; break; }
    }
    for (const k of Object.keys(sh.formulas)) { const r = +k.split(':')[0]; if (r > last) last = r; }
    return last;
  }
  function lastColOf(sh) {
    let last = 0;
    for (const row of sh.rows) {
      if (!row) continue;
      for (let j = row.length - 1; j >= last; j--) {
        if (row[j] !== '' && row[j] !== undefined) { last = j + 1; break; }
      }
    }
    for (const k of Object.keys(sh.formulas)) { const c = +k.split(':')[1]; if (c > last) last = c; }
    return last;
  }

  // ----- time zones --------------------------------------------------------------------------
  const dtfCache = {};
  function safeTz(tz) {
    const key = String(tz);
    if (dtfCache[key]) return key;
    try {
      dtfCache[key] = new Intl.DateTimeFormat('en-US', { timeZone: key, hourCycle: 'h23', year: 'numeric',
        month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
      return key;
    } catch (e) {
      return 'Etc/UTC'; // Java's TimeZone.getTimeZone falls back to GMT for unknown ids.
    }
  }
  function partsIn(ms, tz) {
    const f = dtfCache[safeTz(tz)];
    const p = {};
    f.formatToParts(new RealDate(ms)).forEach((x) => { p[x.type] = x.value; });
    return { y: +p.year, M: +p.month, d: +p.day, H: (+p.hour) % 24, m: +p.minute, s: +p.second };
  }
  function offsetMinutes(ms, tz) {
    const t = Math.floor(ms / 1000) * 1000;
    const p = partsIn(t, tz);
    return Math.round((RealDate.UTC(p.y, p.M - 1, p.d, p.H, p.m, p.s) - t) / 60000);
  }
  function wallTimeToDate(y, M, d, H, m, s, tz) {
    const guess = RealDate.UTC(y, M - 1, d, H, m, s);
    let ms = guess - offsetMinutes(guess, tz) * 60000;
    ms = guess - offsetMinutes(ms, tz) * 60000;
    return new RealDate(ms);
  }
  const pad = (n, w) => String(n).padStart(w || 2, '0');
  const DATE_PATTERNS = ["yyyy-MM-dd'T'HH:mm:ssXXX", 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd', 'HH:mm'];
  function formatDate(date, tz, pattern) {
    if (!isDate(date) || isNaN(date.getTime())) {
      throw gasError('Fake Utilities.formatDate: the first argument must be a valid Date, got ' + String(date));
    }
    if (typeof tz !== 'string' || !tz) throw gasError('Fake Utilities.formatDate: time zone must be a non-empty string.');
    if (DATE_PATTERNS.indexOf(pattern) < 0) {
      throw gasError(`Fake Utilities.formatDate: pattern "${pattern}" is not supported by the harness. ` +
        `Allowed: ${DATE_PATTERNS.join(' | ')}`);
    }
    const ms = date.getTime();
    const p = partsIn(ms, tz);
    const ymd = `${pad(p.y, 4)}-${pad(p.M)}-${pad(p.d)}`;
    const hm = `${pad(p.H)}:${pad(p.m)}`;
    if (pattern === 'yyyy-MM-dd') return ymd;
    if (pattern === 'HH:mm') return hm;
    if (pattern === 'yyyy-MM-dd HH:mm') return `${ymd} ${hm}`;
    const off = offsetMinutes(ms, tz);
    const xxx = off === 0 ? 'Z' : `${off < 0 ? '-' : '+'}${pad(Math.floor(Math.abs(off) / 60))}:${pad(Math.abs(off) % 60)}`;
    return `${ymd}T${hm}:${pad(p.s)}${xxx}`;
  }

  // ----- Range -------------------------------------------------------------------------------
  const sheetStateOf = new WeakMap();

  function makeRange(ssState, sh, r, c, nr, nc) {
    if (!isInt(r) || !isInt(c) || !isInt(nr) || !isInt(nc)) {
      throw gasError(`Fake Range: getRange arguments must be integers (got ${r}, ${c}, ${nr}, ${nc}).`);
    }
    if (r < 1) throw gasError('The starting row of the range is too small.');
    if (c < 1) throw gasError('The starting column of the range is too small.');
    if (nr < 1) throw gasError('The number of rows in the range must be at least 1.');
    if (nc < 1) throw gasError('The number of columns in the range must be at least 1.');
    if (r + nr - 1 > sh.maxRows || c + nc - 1 > sh.maxCols) {
      throw gasError('The coordinates of the range are outside the dimensions of the sheet.');
    }
    let self = null;
    function prepare(values) {
      const out = [];
      for (let i = 0; i < nr; i++) {
        const row = [];
        for (let j = 0; j < nc; j++) {
          const v = normalizeIn(values[i][j], sh, ssState, r + i, c + j);
          checkValidation(sh, r + i, c + j, v);
          row.push(v);
        }
        out.push(row);
      }
      return out;
    }
    function checkDims(values, what) {
      if (!Array.isArray(values)) throw gasError(`Fake Range.${what}: expected a 2-D array.`);
      if (values.length !== nr) {
        throw gasError(`The number of rows in the data does not match the number of rows in the range. ` +
          `The data has ${values.length} but the range has ${nr}.`);
      }
      values.forEach((row) => {
        if (!Array.isArray(row)) throw gasError(`Fake Range.${what}: every row must be an array.`);
        if (row.length !== nc) {
          throw gasError(`The number of columns in the data does not match the number of columns in the range. ` +
            `The data has ${row.length} but the range has ${nc}.`);
        }
      });
    }
    const obj = {
      getValues() {
        logRead(sh, 'getValues', r, c, nr, nc);
        const out = [];
        for (let i = 0; i < nr; i++) {
          const row = [];
          for (let j = 0; j < nc; j++) row.push(cloneOut(getCell(sh, r + i, c + j)));
          out.push(row);
        }
        return out;
      },
      getValue() {
        logRead(sh, 'getValue', r, c, 1, 1);
        return cloneOut(getCell(sh, r, c));
      },
      setValues(values) {
        checkDims(values, 'setValues');
        const prepared = prepare(values);
        beforeWrite(sh, 'setValues', r, c, nr, nc);
        for (let i = 0; i < nr; i++) for (let j = 0; j < nc; j++) putCell(sh, r + i, c + j, prepared[i][j]);
        return self;
      },
      setValue(value) {
        const grid = [];
        for (let i = 0; i < nr; i++) { const row = []; for (let j = 0; j < nc; j++) row.push(value); grid.push(row); }
        const prepared = prepare(grid);
        beforeWrite(sh, 'setValue', r, c, nr, nc);
        for (let i = 0; i < nr; i++) for (let j = 0; j < nc; j++) putCell(sh, r + i, c + j, prepared[i][j]);
        return self;
      },
      setFormula(formula) {
        beforeWrite(sh, 'setFormula', r, c, nr, nc);
        for (let i = 0; i < nr; i++) {
          for (let j = 0; j < nc; j++) { putCell(sh, r + i, c + j, ''); sh.formulas[(r + i) + ':' + (c + j)] = String(formula); }
        }
        return self;
      },
      setFormulas(formulas) {
        checkDims(formulas, 'setFormulas');
        beforeWrite(sh, 'setFormulas', r, c, nr, nc);
        for (let i = 0; i < nr; i++) {
          for (let j = 0; j < nc; j++) {
            putCell(sh, r + i, c + j, '');
            if (formulas[i][j] !== '' && formulas[i][j] != null) sh.formulas[(r + i) + ':' + (c + j)] = String(formulas[i][j]);
          }
        }
        return self;
      },
      clearContent() {
        beforeWrite(sh, 'clearContent', r, c, nr, nc);
        for (let i = 0; i < nr; i++) {
          const row = sh.rows[r + i - 1];
          for (let j = 0; j < nc; j++) {
            if (row) row[c + j - 1] = '';
            delete sh.formulas[(r + i) + ':' + (c + j)];
          }
        }
        return self;
      },
      clear() { return obj.clearContent.call(self); },
      setNumberFormat(fmt) {
        sh.formats.push([r, c, r + nr - 1, c + nc - 1, String(fmt)]);
        return self;
      },
      setDataValidation(rule) {
        sh.validations.push([r, c, r + nr - 1, c + nc - 1, rule || null]);
        return self;
      },
      createFilter() {
        if (sh.filter) throw gasError("You can't create a filter in a sheet that already has a filter.");
        sh.filter = { range: [r, c, nr, nc] };
        return makeFilter(ssState, sh);
      },
      getRow() { return r; },
      getColumn() { return c; },
      getNumRows() { return nr; },
      getNumColumns() { return nc; },
      getA1Notation() {
        const a = colLetter(c) + r;
        return nr === 1 && nc === 1 ? a : `${a}:${colLetter(c + nc - 1)}${r + nr - 1}`;
      },
      getSheet() { return makeSheet(ssState, sh); },
    };
    self = strict(obj, 'Range', RANGE_FORMATTING);
    return self;
  }

  function makeFilter(ssState, sh) {
    return strict({
      getRange() { const f = sh.filter.range; return makeRange(ssState, sh, f[0], f[1], f[2], f[3]); },
      remove() { sh.filter = null; },
    }, 'Filter', new Set(['setColumnFilterCriteria', 'removeColumnFilterCriteria', 'sort']));
  }

  // ----- Sheet -------------------------------------------------------------------------------
  function parseA1(a1) {
    const m = /^\s*([A-Z]+)(\d+)(?::([A-Z]+)(\d+))?\s*$/.exec(String(a1).toUpperCase());
    if (!m) throw gasError(`Fake Sheet.getRange: unsupported A1 notation "${a1}" (use e.g. "B1" or "B1:L1").`);
    const col = (s) => s.split('').reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0);
    const r1 = +m[2]; const c1 = col(m[1]);
    const r2 = m[3] ? +m[4] : r1; const c2 = m[3] ? col(m[3]) : c1;
    return [Math.min(r1, r2), Math.min(c1, c2), Math.abs(r2 - r1) + 1, Math.abs(c2 - c1) + 1];
  }
  function shiftRects(list, axis, after, n) {
    list.forEach((x) => {
      if (axis === 'col') { if (x[1] > after) x[1] += n; if (x[3] > after) x[3] += n; }
      else { if (x[0] > after) x[0] += n; if (x[2] > after) x[2] += n; }
    });
  }

  function makeSheet(ssState, sh) {
    let self = null;
    const obj = {
      getName() { return sh.name; },
      getLastRow() { return lastRowOf(sh); },
      getLastColumn() { return lastColOf(sh); },
      getMaxRows() { return sh.maxRows; },
      getMaxColumns() { return sh.maxCols; },
      getRange(a, b, c, d) {
        if (typeof a === 'string' && b === undefined) {
          const p = parseA1(a);
          return makeRange(ssState, sh, p[0], p[1], p[2], p[3]);
        }
        return makeRange(ssState, sh, a, b, c === undefined ? 1 : c, d === undefined ? 1 : d);
      },
      appendRow(values) {
        if (!Array.isArray(values)) throw gasError('Fake Sheet.appendRow: expected an array.');
        const r = lastRowOf(sh) + 1;
        const prepared = values.map((v, j) => normalizeIn(v, sh, ssState, r, j + 1));
        prepared.forEach((v, j) => checkValidation(sh, r, j + 1, v));
        beforeWrite(sh, 'appendRow', r, 1, 1, Math.max(values.length, 1));
        if (r > sh.maxRows) sh.maxRows = r;
        if (values.length > sh.maxCols) sh.maxCols = values.length;
        prepared.forEach((v, j) => putCell(sh, r, j + 1, v));
        return self;
      },
      insertColumnsAfter(after, n) {
        if (!isInt(after) || !isInt(n) || n < 1 || after < 1 || after > sh.maxCols) {
          throw gasError('Fake Sheet.insertColumnsAfter: invalid arguments.');
        }
        beforeWrite(sh, 'insertColumnsAfter', 1, after, sh.maxRows, n);
        sh.rows.forEach((row) => { if (row && row.length > after) row.splice(after, 0, ...new Array(n).fill('')); });
        const f = {};
        Object.keys(sh.formulas).forEach((k) => {
          const [rr, cc] = k.split(':').map(Number);
          f[rr + ':' + (cc > after ? cc + n : cc)] = sh.formulas[k];
        });
        sh.formulas = f;
        shiftRects(sh.formats, 'col', after, n);
        shiftRects(sh.validations, 'col', after, n);
        sh.maxCols += n;
        return self;
      },
      insertRowsAfter(after, n) {
        if (!isInt(after) || !isInt(n) || n < 1 || after < 1 || after > sh.maxRows) {
          throw gasError('Fake Sheet.insertRowsAfter: invalid arguments.');
        }
        beforeWrite(sh, 'insertRowsAfter', after, 1, n, sh.maxCols);
        if (sh.rows.length > after) sh.rows.splice(after, 0, ...new Array(n).fill(undefined));
        const f = {};
        Object.keys(sh.formulas).forEach((k) => {
          const [rr, cc] = k.split(':').map(Number);
          f[(rr > after ? rr + n : rr) + ':' + cc] = sh.formulas[k];
        });
        sh.formulas = f;
        shiftRects(sh.formats, 'row', after, n);
        shiftRects(sh.validations, 'row', after, n);
        sh.maxRows += n;
        return self;
      },
      clear() {
        beforeWrite(sh, 'clearSheet', 1, 1, sh.maxRows, sh.maxCols);
        sh.rows = [];
        sh.formulas = {};
        sh.formats = [];
        sh.validations = [];
        return self;
      },
      getFilter() { return sh.filter ? makeFilter(ssState, sh) : null; },
    };
    self = strict(obj, 'Sheet', SHEET_FORMATTING);
    sheetStateOf.set(self, sh);
    return self;
  }

  // ----- Spreadsheet -------------------------------------------------------------------------
  function stateFromSheetArg(ssState, sheet) {
    const st = sheet && sheetStateOf.get(sheet);
    if (!st || ssState.sheets.indexOf(st) < 0) throw gasError('Fake Spreadsheet: the sheet does not belong to this spreadsheet.');
    return st;
  }
  function newSheetState(name) {
    world.sheetCounter += 1;
    return { name, sheetId: world.sheetCounter, rows: [], maxRows: 1000, maxCols: 26, formulas: {},
      formats: [], validations: [], filter: null };
  }
  function makeSpreadsheet(ssState) {
    const obj = {
      getId() { return ssState.id; },
      getName() { return ssState.name; },
      getUrl() { return `https://docs.google.com/spreadsheets/d/${ssState.id}/edit`; },
      getSheetByName(name) {
        const st = ssState.sheets.find((s) => s.name === name);
        return st ? makeSheet(ssState, st) : null;
      },
      getSheets() { return ssState.sheets.map((s) => makeSheet(ssState, s)); },
      insertSheet(name, index) {
        if (typeof name !== 'string' || !name) throw gasError('Fake Spreadsheet.insertSheet: a sheet name is required.');
        if (ssState.sheets.some((s) => s.name === name)) {
          throw gasError(`A sheet with the name "${name}" already exists. Please enter another name.`);
        }
        const st = newSheetState(name);
        let idx = index === undefined ? ssState.sheets.length : Number(index);
        if (!isInt(idx) || idx < 0) throw gasError('Fake Spreadsheet.insertSheet: invalid index.');
        idx = Math.min(idx, ssState.sheets.length);
        world.log.writes.push({ seq: nextSeq(), phase: world.phase, op: 'insertSheet', sheet: name,
          lockHeld: !!world.lock.held });
        ssState.sheets.splice(idx, 0, st);
        ssState.active = st;
        return makeSheet(ssState, st);
      },
      deleteSheet(sheet) {
        const st = stateFromSheetArg(ssState, sheet);
        if (ssState.sheets.length === 1) throw gasError("You can't remove all the sheets in a document.");
        world.log.writes.push({ seq: nextSeq(), phase: world.phase, op: 'deleteSheet', sheet: st.name,
          lockHeld: !!world.lock.held });
        world.log.deletedSheets.push({ phase: world.phase, sheet: st.name, lastRow: lastRowOf(st) });
        ssState.sheets.splice(ssState.sheets.indexOf(st), 1);
        if (ssState.active === st) ssState.active = ssState.sheets[0];
      },
      getSpreadsheetTimeZone() { return ssState.tz; },
      setSpreadsheetTimeZone(tz) { ssState.tz = String(tz); },
      toast(msg, title, timeout) { world.log.toasts.push({ msg: String(msg), title: title == null ? '' : String(title), timeout }); },
      setActiveSheet(sheet) { ssState.active = stateFromSheetArg(ssState, sheet); return sheet; },
      moveActiveSheet(pos) {
        const st = ssState.active;
        if (!st) return;
        if (!isInt(pos) || pos < 1) throw gasError('Fake Spreadsheet.moveActiveSheet: position must be >= 1.');
        ssState.sheets.splice(ssState.sheets.indexOf(st), 1);
        ssState.sheets.splice(Math.min(pos - 1, ssState.sheets.length), 0, st);
      },
    };
    return strict(obj, 'Spreadsheet', null);
  }

  // ----- builders ----------------------------------------------------------------------------
  function builder(kind) {
    const st = { list: null, allowInvalid: true };
    let self = null;
    self = new Proxy({}, {
      get(t, prop) {
        if (typeof prop === 'symbol' || PASSIVE.has(prop)) return undefined;
        if (prop === 'build') {
          return () => Object.freeze({ kind, list: st.list ? st.list.slice() : null, allowInvalid: st.allowInvalid });
        }
        return (...args) => {
          if (prop === 'requireValueInList') st.list = Array.isArray(args[0]) ? args[0].slice() : null;
          if (prop === 'setAllowInvalid') st.allowInvalid = !!args[0];
          return self;
        };
      },
    });
    return self;
  }

  // ----- services ----------------------------------------------------------------------------
  const SpreadsheetApp = strict({
    getActiveSpreadsheet() {
      const id = world.activeOverride || world.boundId;
      return id && world.spreadsheets[id] ? makeSpreadsheet(world.spreadsheets[id]) : null;
    },
    openById(id) {
      const st = world.spreadsheets[String(id)];
      if (!st || st.accessible === false) {
        throw gasError('Unexpected error while getting the method or property openById on object SpreadsheetApp.');
      }
      return makeSpreadsheet(st);
    },
    flush() { world.log.flushes.push({ seq: nextSeq(), phase: world.phase }); },
    newDataValidation() { return builder('dataValidation'); },
    newConditionalFormatRule() { return builder('conditionalFormat'); },
    BorderStyle: Object.freeze({ DOTTED: 'DOTTED', DASHED: 'DASHED', SOLID: 'SOLID', SOLID_MEDIUM: 'SOLID_MEDIUM',
      SOLID_THICK: 'SOLID_THICK', DOUBLE: 'DOUBLE' }),
  }, 'SpreadsheetApp', null);

  const lockObj = strict({
    waitLock(timeoutMs) {
      world.log.lock.push({ seq: nextSeq(), phase: world.phase, op: 'waitLock', ms: timeoutMs });
      if (world.lock.busy) throw gasError('Lock timeout: another process was holding the lock for too long.');
      world.lock.held = true;
    },
    tryLock(timeoutMs) {
      world.log.lock.push({ seq: nextSeq(), phase: world.phase, op: 'tryLock', ms: timeoutMs });
      if (world.lock.busy) return false;
      world.lock.held = true;
      return true;
    },
    releaseLock() {
      world.log.lock.push({ seq: nextSeq(), phase: world.phase, op: 'releaseLock' });
      world.lock.held = false;
    },
  }, 'Lock', null);
  const LockService = strict({ getScriptLock() { return lockObj; } }, 'LockService', null);

  function utf8Length(s) { return host.utf8Encode(s).length; }
  const cacheObj = strict({
    get(key) {
      const e = world.cache[String(key)];
      if (!e) return null;
      if (e.exp <= nowMs()) { delete world.cache[String(key)]; return null; }
      return e.value;
    },
    put(key, value, ttlSeconds) {
      const k = String(key);
      if (k.length > 250) throw gasError('Argument too large: key');
      if (value === null || value === undefined || typeof value === 'object' || typeof value === 'function') {
        throw gasError('Fake CacheService.put: value must be a string (got ' + (value === null ? 'null' : typeof value) + ').');
      }
      const v = String(value);
      if (utf8Length(v) > 100 * 1024) throw gasError('Argument too large: value');
      let ttl = ttlSeconds === undefined ? 600 : Number(ttlSeconds);
      if (!(ttl >= 1)) ttl = 1;
      if (ttl > 21600) ttl = 21600;
      world.cache[k] = { value: v, exp: nowMs() + ttl * 1000, ttl };
    },
    remove(key) { delete world.cache[String(key)]; },
    removeAll(keys) { (keys || []).forEach((k) => { delete world.cache[String(k)]; }); },
  }, 'Cache', null);
  const CacheService = strict({ getScriptCache() { return cacheObj; } }, 'CacheService', null);

  let propsObj = null;
  propsObj = strict({
    getProperty(key) {
      return Object.prototype.hasOwnProperty.call(world.props, String(key)) ? world.props[String(key)] : null;
    },
    setProperty(key, value) { world.props[String(key)] = String(value); return propsObj; },
    getProperties() { const o = {}; Object.keys(world.props).forEach((k) => { o[k] = world.props[k]; }); return o; },
    deleteProperty(key) { delete world.props[String(key)]; return propsObj; },
  }, 'Properties', null);
  const PropertiesService = strict({ getScriptProperties() { return propsObj; } }, 'PropertiesService', null);

  const TOKENINFO = 'https://oauth2.googleapis.com/tokeninfo?id_token=';
  const UrlFetchApp = strict({
    fetch(url, params) {
      if (typeof url !== 'string' || url.indexOf(TOKENINFO) !== 0) {
        throw gasError('Fake UrlFetchApp.fetch: only ' + TOKENINFO + '<token> is faked, got ' + String(url));
      }
      if (params && params.method && String(params.method).toLowerCase() !== 'get') {
        throw gasError('Fake UrlFetchApp.fetch: tokeninfo is called with GET.');
      }
      let token;
      try { token = decodeURIComponent(url.slice(TOKENINFO.length)); } catch (e) { token = url.slice(TOKENINFO.length); }
      world.log.fetches.push({ seq: nextSeq(), url, muteHttpExceptions: !!(params && params.muteHttpExceptions) });
      const info = Object.prototype.hasOwnProperty.call(world.tokens, token) ? world.tokens[token] : null;
      const code = info ? 200 : 400;
      const body = info ? JSON.stringify(info) : JSON.stringify({ error: 'invalid_token' });
      if (code >= 400 && !(params && params.muteHttpExceptions)) {
        throw gasError(`Request failed for https://oauth2.googleapis.com returned code ${code}. ` +
          `Truncated server response: ${body} (use muteHttpExceptions option to examine full response)`);
      }
      return strict({ getResponseCode() { return code; }, getContentText() { return body; } }, 'HTTPResponse', null);
    },
  }, 'UrlFetchApp', null);

  function toBytes(data) {
    if (typeof data === 'string') return host.utf8Encode(data);
    if (Array.isArray(data)) return data.map((b) => Number(b) & 0xff);
    throw gasError('Fake Utilities: expected a string or a byte array.');
  }
  function signed(bytes) { const out = []; for (let i = 0; i < bytes.length; i++) { const b = bytes[i] & 0xff; out.push(b > 127 ? b - 256 : b); } return out; }
  const Utilities = strict({
    computeHmacSha256Signature(value, key) {
      return signed(host.hmacSha256(toBytes(value), toBytes(key)));
    },
    base64EncodeWebSafe(data) {
      return host.base64Encode(toBytes(data)).replace(/\+/g, '-').replace(/\//g, '_');
    },
    base64DecodeWebSafe(encoded) {
      const s = String(encoded);
      if (/[+/]/.test(s)) throw gasError('Could not decode string.');
      const bytes = host.base64Decode(s.replace(/-/g, '+').replace(/_/g, '/'));
      if (!bytes) throw gasError('Could not decode string.');
      return signed(bytes);
    },
    newBlob(data) {
      const bytes = toBytes(data);
      return strict({ getDataAsString() { return host.utf8Decode(bytes); } }, 'Blob', null);
    },
    getUuid() { return host.uuid(); },
    formatDate,
    sleep() {},
  }, 'Utilities', null);

  const Session = strict({
    getEffectiveUser() { return strict({ getEmail() { return world.ownerEmail; } }, 'User', null); },
    getScriptTimeZone() { return world.scriptTimeZone; },
  }, 'Session', null);

  const MimeType = Object.freeze({ JSON: 'JSON', TEXT: 'TEXT', CSV: 'CSV', ICAL: 'ICAL', JAVASCRIPT: 'JAVASCRIPT',
    RSS: 'RSS', ATOM: 'ATOM', VCARD: 'VCARD', XML: 'XML' });
  const ContentService = strict({
    createTextOutput(content) {
      let text = content === undefined ? '' : String(content);
      let mime = 'TEXT';
      let out = null;
      out = strict({
        getContent() { return text; },
        setContent(s) { text = String(s); return out; },
        append(s) { text += String(s); return out; },
        getMimeType() { return mime; },
        setMimeType(m) {
          if (!Object.prototype.hasOwnProperty.call(MimeType, m)) throw gasError('Fake ContentService: unknown MimeType ' + String(m));
          mime = m;
          return out;
        },
      }, 'TextOutput', null);
      return out;
    },
    MimeType,
  }, 'ContentService', null);

  Object.assign(G, { SpreadsheetApp, LockService, CacheService, PropertiesService, UrlFetchApp, Utilities,
    Session, ContentService });

  // Control surface used by the harness only (returned, never installed as a global).
  return {
    makePostEvent(contents) {
      const text = String(contents);
      return {
        postData: { contents: text, type: 'text/plain', length: text.length, name: 'postData' },
        parameter: {}, parameters: {}, queryString: '', contentLength: text.length, contextPath: '',
      };
    },
    makeGetEvent(params) {
      const p = {}; const ps = {};
      Object.keys(params || {}).forEach((k) => { p[k] = String(params[k]); ps[k] = [String(params[k])]; });
      return { parameter: p, parameters: ps, queryString: '', contentLength: -1, contextPath: '' };
    },
    newSheetState,
    openSpreadsheet(id) { return world.spreadsheets[id] ? makeSpreadsheet(world.spreadsheets[id]) : null; },
    formatDate,
    toRealmArgs(json) { return JSON.parse(json); },
  };
}

const INSTALL_SCRIPT = new vm.Script(`(${installFakeAppsScript.toString()})`, {
  filename: path.join(__dirname, 'harness.js#fake-apps-script'),
});

// ---------------------------------------------------------------------------------------------
// Script loading (compiled once per process).
// ---------------------------------------------------------------------------------------------
let compiled = null;
function backendFiles() {
  if (!fs.existsSync(BACKEND_SRC)) return [];
  const all = fs.readdirSync(BACKEND_SRC).filter((f) => f.endsWith('.gs')).sort();
  const first = ['Config.gs', 'Util.gs'].filter((f) => all.indexOf(f) >= 0);
  return first.concat(all.filter((f) => first.indexOf(f) < 0)).map((f) => path.join(BACKEND_SRC, f));
}
function compileScripts() {
  if (compiled) return compiled;
  const files = [SETUP_GS].concat(backendFiles());
  compiled = files.map((file) => ({
    file,
    rel: path.relative(REPO_ROOT, file),
    script: new vm.Script(fs.readFileSync(file, 'utf8'), { filename: file }),
  }));
  return compiled;
}
const SETUP_ONLY = () => compileScripts().filter((s) => s.file === SETUP_GS);

// ---------------------------------------------------------------------------------------------
// Host-side value conversion.
// ---------------------------------------------------------------------------------------------
function isDateLike(v) { return Object.prototype.toString.call(v) === '[object Date]'; }
function toHost(v) {
  if (v === null || typeof v !== 'object') return v;
  if (isDateLike(v)) return new Date(v.getTime());
  if (Array.isArray(v)) return Array.from(v, toHost);
  const o = {};
  Object.keys(v).forEach((k) => { o[k] = toHost(v[k]); });
  return o;
}

function sheetTitle(keyOrTitle) {
  const def = SCHEMA.sheets.find((s) => s.key === keyOrTitle || s.title === keyOrTitle);
  if (def) return def.title;
  return keyOrTitle;
}

function newWorld() {
  return {
    spreadsheets: {},
    boundId: null,
    activeOverride: null,
    props: {},
    cache: {},
    lock: { busy: false, held: false },
    tokens: {},
    clock: { offsetMs: 0 },
    phase: 'setup',
    seq: 0,
    sheetCounter: 0,
    ownerEmail: OWNER_EMAIL,
    scriptTimeZone: SCRIPT_TIME_ZONE,
    faults: [],
    log: { writes: [], reads: [], flushes: [], lock: [], fetches: [], toasts: [], deletedSheets: [],
      anomalies: [], formatting: 0 },
  };
}

function newSpreadsheetState(world, name, opts) {
  let id;
  do { id = '1' + hostBridge.randomId(43); } while (world.spreadsheets[id]);
  world.sheetCounter += 1;
  world.spreadsheets[id] = {
    id,
    name: name || 'جدول بيانات بلا عنوان',
    tz: 'Etc/UTC',
    accessible: !(opts && opts.accessible === false),
    sheets: [{ name: 'Sheet1', sheetId: world.sheetCounter, rows: [], maxRows: 1000, maxCols: 26, formulas: {},
      formats: [], validations: [], filter: null }],
    active: null,
  };
  world.spreadsheets[id].active = world.spreadsheets[id].sheets[0];
  return id;
}

// One Apps Script execution: a fresh realm with the fakes, setup.gs and the backend loaded.
function newExecution(world, withBackend) {
  const logs = [];
  const sandboxConsole = {};
  ['log', 'info', 'warn', 'error', 'debug'].forEach((level) => {
    sandboxConsole[level] = (...args) => {
      logs.push({ level, args });
      if (process.env.RUMMAN_TEST_VERBOSE) console.error(`[apps-script ${level}]`, ...args);
    };
  });
  const ctx = vm.createContext({ console: sandboxConsole }, { name: 'apps-script-execution' });
  const install = INSTALL_SCRIPT.runInContext(ctx);
  const control = install(world, hostBridge);
  const scripts = withBackend ? compileScripts() : SETUP_ONLY();
  for (const s of scripts) {
    try {
      s.script.runInContext(ctx, { timeout: EXEC_TIMEOUT_MS });
    } catch (e) {
      const err = new Error(`Loading ${s.rel} failed: ${e && e.stack ? e.stack : e}`);
      err.cause = e;
      throw err;
    }
  }
  return {
    ctx,
    control,
    logs,
    call(fnName, args) {
      if (vm.runInContext(`typeof ${fnName}`, ctx) !== 'function') {
        const files = scripts.map((s) => s.rel).join(', ');
        throw new Error(`${fnName} is not defined as a global function (loaded: ${files}). ` +
          'Is backend/src present?');
      }
      ctx.__rummanHarnessArgs = args || [];
      try {
        return vm.runInContext(`${fnName}.apply(null, globalThis.__rummanHarnessArgs)`, ctx, { timeout: EXEC_TIMEOUT_MS });
      } finally {
        delete ctx.__rummanHarnessArgs;
      }
    },
  };
}

// ---------------------------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------------------------
const DEFAULT_ADMIN = 'owner.admin@gmail.com';

function createEnv(options) {
  const opts = Object.assign({ bootstrapAdmin: DEFAULT_ADMIN, extraProps: {}, bound: true, setup: true }, options || {});
  const world = newWorld();
  if (opts.bootstrapAdmin) world.props.BOOTSTRAP_ADMIN_EMAIL = String(opts.bootstrapAdmin);
  Object.keys(opts.extraProps || {}).forEach((k) => { world.props[k] = String(opts.extraProps[k]); });
  if (opts.bound) world.boundId = newSpreadsheetState(world, 'حاسبة الرمان');

  let inspector = null;
  const history = [];

  const env = {
    world,
    schema: SCHEMA,
    clientIds: CLIENT_IDS,
    ownerEmail: OWNER_EMAIL,
    bootstrapAdmin: opts.bootstrapAdmin || null,
    history,
    lastRequest: null,
    get loadedFiles() { return compileScripts().map((s) => s.rel); },
    get spreadsheetId() { return world.boundId; },

    /** Runs a global function in a fresh execution (like pressing "Run" in the editor). */
    run(fnName, args, runOpts) {
      const ro = Object.assign({ withBackend: true, spreadsheetId: null }, runOpts || {});
      const exec = newExecution(world, ro.withBackend);
      const prevPhase = world.phase;
      world.phase = 'setup';
      world.activeOverride = ro.spreadsheetId;
      try {
        return toHost(exec.call(fnName, args || []));
      } finally {
        world.activeOverride = null;
        world.phase = prevPhase;
        world.lock.held = false;
      }
    },

    /** Evaluates code inside a fresh execution realm (fakes + setup.gs, optionally the backend). */
    evaluate(code, evalOpts) {
      const eo = Object.assign({ withBackend: false, phase: 'test' }, evalOpts || {});
      const exec = newExecution(world, eo.withBackend);
      const prevPhase = world.phase;
      world.phase = eo.phase;
      try {
        return toHost(vm.runInContext(code, exec.ctx, { timeout: EXEC_TIMEOUT_MS }));
      } finally {
        world.phase = prevPhase;
        world.lock.held = false;
      }
    },

    _request(kind, fnName, makeArg, label) {
      const exec = newExecution(world, true);
      const startSeq = world.seq;
      const arg = makeArg(exec.control);
      world.phase = 'request';
      world.lock.held = false;
      let out;
      let thrown = null;
      try {
        out = exec.call(fnName, [arg]);
      } catch (e) {
        thrown = e;
      } finally {
        world.phase = 'test';
      }
      const leakedLock = world.lock.held;
      world.lock.held = false; // the lock is released when an execution ends
      const after = (list) => list.filter((x) => x.seq > startSeq);
      const writes = after(world.log.writes);
      const flushes = after(world.log.flushes);
      const record = {
        kind,
        label,
        writes,
        reads: after(world.log.reads),
        flushes,
        lockOps: after(world.log.lock),
        fetches: after(world.log.fetches),
        leakedLock,
        logs: exec.logs,
        flushedAfterLastWrite: writes.length === 0 ||
          (flushes.length > 0 && flushes[flushes.length - 1].seq > writes[writes.length - 1].seq),
        mimeType: null,
        response: null,
        rawContent: null,
      };
      env.lastRequest = record;
      history.push(record);
      if (thrown) {
        const err = new Error(`${fnName} threw instead of returning a JSON envelope (${label}): ` +
          `${thrown && thrown.stack ? thrown.stack : thrown}`);
        err.cause = thrown;
        throw err;
      }
      if (!out || typeof out.getContent !== 'function') {
        throw new Error(`${fnName} must return ContentService.createTextOutput(...) (${label}); got ${out}`);
      }
      record.rawContent = String(out.getContent());
      record.mimeType = typeof out.getMimeType === 'function' ? out.getMimeType() : null;
      try {
        record.response = JSON.parse(record.rawContent);
      } catch (e) {
        throw new Error(`${fnName} returned non-JSON content (${label}): ${record.rawContent.slice(0, 500)}`);
      }
      return record.response;
    },

    /** POST a JSON body to doPost; returns the parsed envelope. `raw` sends a literal string. */
    post(body, postOpts) {
      const raw = postOpts && Object.prototype.hasOwnProperty.call(postOpts, 'raw') ? postOpts.raw : undefined;
      const contents = raw !== undefined ? raw : JSON.stringify(body);
      const label = body && body.action ? body.action : 'raw';
      return env._request('post', 'doPost', (control) => control.makePostEvent(contents), label);
    },

    /** GET (doGet) health check. */
    get(params) {
      return env._request('get', 'doGet', (control) => control.makeGetEvent(params || {}), 'doGet');
    },

    /** Registers a Google ID token answered by the fake tokeninfo endpoint. */
    registerGoogleUser(email, tokenOpts) {
      const o = Object.assign({}, tokenOpts || {});
      const nowS = Math.floor(env.clock.now() / 1000);
      const header = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'fake', typ: 'JWT' })).toString('base64url');
      const body = Buffer.from(JSON.stringify({ email, n: crypto.randomUUID() })).toString('base64url');
      const token = `${header}.${body}.${crypto.randomBytes(32).toString('base64url')}`;
      const aud = o.aud === undefined ? CLIENT_IDS.web : o.aud;
      const verified = o.verified === undefined ? true : o.verified;
      const info = {
        iss: o.iss === undefined ? 'https://accounts.google.com' : o.iss,
        azp: aud,
        aud,
        sub: String(o.sub || ('1' + crypto.randomInt(1e9, 9e9) + crypto.randomInt(1e9, 9e9))),
        email,
        email_verified: typeof verified === 'string' ? verified : String(!!verified),
        at_hash: crypto.randomBytes(8).toString('base64url'),
        iat: String(nowS - 5),
        exp: String(o.exp === undefined ? nowS + 3600 : o.exp),
        alg: 'RS256',
        kid: 'fake',
        typ: 'JWT',
      };
      if (o.name !== null) info.name = o.name === undefined ? `مستخدم ${email.split('@')[0]}` : o.name;
      world.tokens[token] = info;
      return token;
    },

    /** Logs in through auth.login; throws if the login fails. */
    loginAs(email, tokenOpts) {
      const idToken = env.registerGoogleUser(email, tokenOpts);
      const res = env.post({ action: 'auth.login', session: null, requestId: crypto.randomUUID(),
        payload: { idToken }, client: { platform: 'web', version: '1.0.0' } });
      if (!res || res.ok !== true) {
        throw new Error(`loginAs(${email}) failed: ${JSON.stringify(res)}`);
      }
      return { token: res.data.session, user: res.data.user, expiresAt: res.data.expiresAt, email, idToken,
        response: res };
    },

    /** Calls an action with a session (object from loginAs, a raw token string, or null). */
    call(session, action, payload, requestId) {
      const token = session && typeof session === 'object' ? session.token : session;
      return env.post({
        action,
        session: token === undefined ? null : token,
        requestId: requestId === undefined ? crypto.randomUUID() : requestId,
        payload: payload === undefined ? {} : payload,
        client: { platform: 'web', version: '1.0.0' },
      });
    },

    // ----- sheet inspection (host values) ----------------------------------------------------
    spreadsheetState(id) { return world.spreadsheets[id || world.boundId]; },
    sheetState(keyOrTitle, id) {
      const ss = env.spreadsheetState(id);
      if (!ss) return null;
      return ss.sheets.find((s) => s.name === sheetTitle(keyOrTitle)) || null;
    },
    sheetNames(id) { return env.spreadsheetState(id).sheets.map((s) => s.name); },
    /** Raw 2-D values of a sheet (host values), rows 1..lastRow, columns 1..lastColumn. */
    values(keyOrTitle, id) {
      const sh = env.sheetState(keyOrTitle, id);
      if (!sh) throw new Error(`No sheet "${sheetTitle(keyOrTitle)}"`);
      const lr = sheetLastRow(sh);
      const lc = sheetLastCol(sh);
      const out = [];
      for (let r = 1; r <= lr; r++) {
        const row = [];
        for (let c = 1; c <= lc; c++) {
          const v = sh.rows[r - 1] ? sh.rows[r - 1][c - 1] : undefined;
          row.push(v === undefined ? '' : toHost(v));
        }
        out.push(row);
      }
      return out;
    },
    headers(keyOrTitle, id) {
      const v = env.values(keyOrTitle, id);
      return (v[SCHEMA.headerRow - 1] || []).map((x) => String(x));
    },
    /** Rows from SCHEMA.firstDataRow as objects keyed by the header names currently on row 3. */
    readSheet(keyOrTitle, id) {
      const v = env.values(keyOrTitle, id);
      const headers = (v[SCHEMA.headerRow - 1] || []).map((x) => String(x));
      const out = [];
      for (let r = SCHEMA.firstDataRow; r <= v.length; r++) {
        const row = v[r - 1];
        const o = {};
        headers.forEach((h, i) => { if (h !== '') o[h] = row[i] === undefined ? '' : row[i]; });
        Object.defineProperty(o, '_row', { value: r, enumerable: false });
        out.push(o);
      }
      return out;
    },
    rows(keyOrTitle, id) { return env.readSheet(keyOrTitle, id); },
    findRow(keyOrTitle, recordId, id) {
      return env.readSheet(keyOrTitle, id).find((r) => r['المعرّف'] === recordId) || null;
    },
    column(keyOrTitle, header, id) {
      const i = env.headers(keyOrTitle, id).indexOf(header);
      return i < 0 ? null : i + 1;
    },

    /** Spreadsheet API object (fake) for direct manipulation from tests ("someone edits the sheet"). */
    get ss() { return env.openSpreadsheet(world.boundId); },
    openSpreadsheet(id) {
      if (!inspector) inspector = newExecution(world, false);
      return inspector.control.openSpreadsheet(id);
    },
    setCell(keyOrTitle, row, col, value, id) {
      const sh = env.openSpreadsheet(id || world.boundId).getSheetByName(sheetTitle(keyOrTitle));
      sh.getRange(row, col).setValue(value);
    },
    /** Updates cells of the row whose المعرّف equals recordId, by header name. */
    updateRow(keyOrTitle, recordId, changes, id) {
      const row = env.findRow(keyOrTitle, recordId, id);
      if (!row) throw new Error(`updateRow: ${recordId} not found in ${sheetTitle(keyOrTitle)}`);
      Object.keys(changes).forEach((h) => {
        const c = env.column(keyOrTitle, h, id);
        if (!c) throw new Error(`updateRow: no column "${h}" in ${sheetTitle(keyOrTitle)}`);
        env.setCell(keyOrTitle, row._row, c, changes[h], id);
      });
    },
    /** Appends a row given as {header: value} (missing headers left blank). */
    appendRowObject(keyOrTitle, obj, id) {
      const headers = env.headers(keyOrTitle, id);
      const unknown = Object.keys(obj).filter((k) => headers.indexOf(k) < 0);
      if (unknown.length) throw new Error(`appendRowObject: unknown columns ${unknown.join(', ')}`);
      const row = headers.map((h) => (Object.prototype.hasOwnProperty.call(obj, h) ? obj[h] : ''));
      env.openSpreadsheet(id || world.boundId).getSheetByName(sheetTitle(keyOrTitle)).appendRow(row);
    },
    /** Creates another spreadsheet reachable through openById (optionally formatted by setup.gs). */
    createSpreadsheet(createOpts) {
      const co = Object.assign({ name: 'ملف آخر', setup: true, accessible: true }, createOpts || {});
      const id = newSpreadsheetState(world, co.name, co);
      if (co.setup) env.run('setupRummanSheet', [], { withBackend: false, spreadsheetId: id });
      return id;
    },

    // ----- services ----------------------------------------------------------------------------
    props: {
      get(k) { return Object.prototype.hasOwnProperty.call(world.props, k) ? world.props[k] : null; },
      set(k, v) { world.props[k] = String(v); },
      delete(k) { delete world.props[k]; },
      all() { return Object.assign({}, world.props); },
    },
    cache: {
      get(k) {
        const e = world.cache[k];
        if (!e || e.exp <= env.clock.now()) return null;
        return e.value;
      },
      keys() { return Object.keys(world.cache).filter((k) => world.cache[k].exp > env.clock.now()); },
      entry(k) { return world.cache[k] ? Object.assign({}, world.cache[k]) : null; },
      remove(k) { delete world.cache[k]; },
      /** Simulates the cache being evicted / expired. */
      clear() { Object.keys(world.cache).forEach((k) => { delete world.cache[k]; }); },
    },
    lock: {
      setBusy(busy) { world.lock.busy = !!busy; },
      isBusy() { return world.lock.busy; },
      isHeld() { return world.lock.held; },
      ops() { return world.log.lock.slice(); },
    },
    clock: {
      now() { return Date.now() + world.clock.offsetMs; },
      advance(ms) { world.clock.offsetMs += ms; },
      offset() { return world.clock.offsetMs; },
    },
    /** Makes the next `times` writes (setValues/setValue/appendRow/...) to a sheet throw during requests. */
    failWrites(keyOrTitle, failOpts) {
      const fo = Object.assign({ times: 1, ops: null, message: 'Service Spreadsheets failed while accessing document with id fake.' }, failOpts || {});
      const f = { sheet: sheetTitle(keyOrTitle), remaining: fo.times, ops: fo.ops, message: fo.message, fired: 0 };
      world.faults.push(f);
      return f;
    },
    formatDate(date, tz, pattern) {
      if (!inspector) inspector = newExecution(world, false);
      return inspector.control.formatDate(new inspector.ctx.Date(date.getTime()), tz, pattern);
    },
  };

  if (opts.bound && opts.setup) env.run('setupRummanSheet', [], { withBackend: false });
  world.phase = 'test';
  return env;
}

function sheetLastRow(sh) {
  let last = 0;
  for (let i = sh.rows.length - 1; i >= 0; i--) {
    const row = sh.rows[i];
    if (row && row.some((v) => v !== '' && v !== undefined)) { last = i + 1; break; }
  }
  Object.keys(sh.formulas).forEach((k) => { const r = +k.split(':')[0]; if (r > last) last = r; });
  return last;
}
function sheetLastCol(sh) {
  let last = 0;
  sh.rows.forEach((row) => {
    if (!row) return;
    for (let j = row.length - 1; j >= last; j--) if (row[j] !== '' && row[j] !== undefined) { last = j + 1; break; }
  });
  Object.keys(sh.formulas).forEach((k) => { const c = +k.split(':')[1]; if (c > last) last = c; });
  return last;
}

module.exports = {
  createEnv,
  toHost,
  sheetTitle,
  SCHEMA,
  CLIENT_IDS,
  DEFAULT_ADMIN,
  OWNER_EMAIL,
  SUMMARY_TITLE,
  REPO_ROOT,
  BACKEND_SRC,
  backendFiles,
};
