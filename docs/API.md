# Rumman Calculator — Backend API contract (v1)

This is the single source of truth shared by the Apps Script backend (`backend/`), its Node test
harness (`backend/test/`), and the Flutter client (`app/lib/core/api/`). Change it here first.

## 1. Architecture

```
Flutter app ──(Google Sign-In: ID token)──► Apps Script web app ──► Google Sheets file
   (web/Android/iOS)     POST JSON              (runs as the sheet owner)
```

* The backend is a Google Apps Script project **bound to the spreadsheet**, deployed as a web app with
  *Execute as: Me (owner)* and *Who has access: Anyone*. Every request is authenticated by the
  backend itself (section 3); the endpoint being public is expected.
* Employees never get direct access to the spreadsheet. The script owner's account is the only
  account that touches the file ("connection account").
* No secrets live in the Flutter app or in the sheet. Server-only values live in **Script Properties**:
  * `SESSION_SECRET` — generated automatically on first use (two `Utilities.getUuid()` joined). Never returned.
  * `BOOTSTRAP_ADMIN_EMAIL` — set by the owner once, in the Apps Script editor (Project settings ▸ Script
    properties). That Google account is always allowed in as admin (auto-provisioned in the Users sheet).
  * `SPREADSHEET_ID` — optional. Empty ⇒ use the bound spreadsheet (`SpreadsheetApp.getActiveSpreadsheet()`).
    Set through `sheet.connect`.
  * `ALLOWED_CLIENT_IDS` — optional comma list overriding the built-in OAuth client IDs (section 3).
  * `SESSION_DAYS` — optional, default `7`.
  * `LAST_WRITE_AT`, `LAST_ERROR` — bookkeeping written by the backend. `LAST_ERROR` is shown to every admin, so
    ID tokens, session tokens and `id_token=` values are redacted before it is stored.

## 2. Transport

* `POST {API_URL}` with header `Content-Type: text/plain;charset=utf-8` (a "simple" request: no CORS
  preflight). Body is JSON:

```json
{
  "action": "purchases.create",
  "session": "<session token or null>",
  "requestId": "<UUID v4, required for every mutation>",
  "payload": { },
  "client": { "platform": "android|ios|web", "version": "1.0.0" }
}
```

* Apps Script always answers HTTP 200 (after a 302 redirect to `script.googleusercontent.com`).
  **Mobile clients must not rely on automatic redirects for POST**: send with redirects disabled, and if
  the status is 301/302/303/307/308, issue a `GET` to the `Location` header and read that body.
  Browsers follow the redirect themselves.
* Response envelope:

```json
{ "ok": true,  "data": { }, "serverTime": "2026-10-02T10:58:00+03:00" }
{ "ok": false, "error": { "code": "VALIDATION", "message": "رسالة عربية واضحة", "field": "boxes", "details": { } },
  "serverTime": "..." }
```

* `GET {API_URL}` (doGet) returns `{ "ok": true, "data": { "service": "rumman-calculator", "version": 1 } }`
  — a health check, no data.

### Error codes

| code | meaning | client behaviour |
|---|---|---|
| `AUTH_REQUIRED` | no/blank session on a protected action | go to login |
| `AUTH_INVALID_TOKEN` | Google ID token rejected (bad signature, audience, issuer, unverified email) | show error, stay on login |
| `AUTH_EXPIRED` | session expired or signature invalid | clear session, go to login |
| `SESSION_STALE` | user record changed since the session was issued (role/status/permissions) | clear session, go to login |
| `NOT_ALLOWED` | email not in the Users sheet, or user disabled. `details.email`, `details.reason` = `not_listed`/`disabled` | "unauthorized" screen |
| `FORBIDDEN` | signed in but lacks the permission. `details.permission` | message, no retry |
| `VALIDATION` | bad input. `field` names the payload key | show under the field |
| `NOT_FOUND` | record id unknown | message |
| `CONFLICT` | `expectedVersion` ≠ current. `details.currentVersion`, `details.current` (fresh record) | ask user to review |
| `COOLER_CLOSED` | purchase add/edit/cancel on a closed cooler | message |
| `LOCK_TIMEOUT` | another write held the lock > 25 s | safe to retry with the same `requestId` |
| `SHEET_NOT_CONFIGURED` | no spreadsheet bound/connected | admin: open sheet settings |
| `SHEET_UNREACHABLE` | `openById` failed (no access / deleted) | admin: open sheet settings |
| `SHEET_SCHEMA` | required sheet/column missing. `details.missing` = `[{sheet, columns:[...]}]` | admin: run repair |
| `UNKNOWN_ACTION` | action name not recognised | bug |
| `INTERNAL` | unexpected error (logged to `LAST_ERROR`) | retry later |

All `message` strings are Arabic, name the field, and say how to fix it.

## 3. Authentication & sessions

### `auth.login` — payload `{ "idToken": "<Google ID token>" }`

0. Local pre-check (no UrlFetch quota spent; `auth.login` is public): the token must be a three-part base64url
   JWT whose payload (signature not checked here) has `aud` in the allowed client IDs, a Google `iss` and a future
   `exp`; otherwise `AUTH_INVALID_TOKEN` (`details.reason`: `malformed`/`audience`/`issuer`/`expired`).
   tokeninfo (step 1) stays the authoritative check.
1. `UrlFetchApp.fetch("https://oauth2.googleapis.com/tokeninfo?id_token=" + encodeURIComponent(idToken), {muteHttpExceptions: true})`.
   Reject (`AUTH_INVALID_TOKEN`) unless: HTTP 200; `aud` ∈ allowed client IDs; `iss` ∈ {`accounts.google.com`,
   `https://accounts.google.com`}; `email_verified` is `"true"`/`true`; `exp` (seconds) > now.
   Allowed client IDs (public identifiers, safe in code):
   * web `833981951758-668sjormn0kp8lm4e8c0ioltdr0ctip8.apps.googleusercontent.com`
   * iOS `833981951758-pb57t33tr66q4b8c3r9tsd3gnbs4doi5.apps.googleusercontent.com`
   * Android `833981951758-c4f37gpodur13gg933ka3hi14359alg1.apps.googleusercontent.com`
2. Email is lower-cased and trimmed. Find the Users row whose `البريد (Gmail)` matches (case-insensitive).
3. If the email equals `BOOTSTRAP_ADMIN_EMAIL` and no row exists, append one: role `مدير`, status `نشط`,
   all permission columns `نعم`, name = tokeninfo `name` or the email. If a row exists but is disabled or not
   admin, the bootstrap account is still treated as an active admin (break-glass) and the row is repaired.
4. Missing row ⇒ `NOT_ALLOWED` (`reason: not_listed`). Any status other than `نشط` (`معطّل`, blank or an unknown
   value) ⇒ `NOT_ALLOWED` (`reason: disabled`); the message names the `الحالة` column and the value `نشط`.
5. Issue a session and return `{ session, expiresAt, user }`. Audit-log the login? **No** (too noisy).

### Session token

`base64url(JSON payload) + "." + base64url(HMAC_SHA256(payloadPart, SESSION_SECRET))` where payload =
`{ "uid": "US-…", "email": "…", "uv": <user row version>, "iat": <unix s>, "exp": <unix s> }`.
Verification on every protected action: signature (constant-time compare), `exp > now`, user row still
exists, status active (bootstrap admin excepted), and row `الإصدار` === `uv` (else `SESSION_STALE`).
User lookups may be cached in `CacheService` for at most 60 s; any users.* write clears that cache.

### `auth.me` → `{ user }` · `auth.logout` → `{}` (stateless; client discards the token)

### User object

```json
{ "id": "US-0002", "email": "karim@gmail.com", "name": "كريم عبد الله",
  "role": "admin|entry|viewer", "status": "active|disabled", "isBootstrap": false, "version": 3,
  "permissions": { "addFarmers": true, "recordPurchases": true, "editOthers": false, "recordPayments": true,
                   "packaging": true, "closeCoolers": true, "reopenCoolers": false,
                   "manageUsers": false, "manageSettings": false, "viewData": true } }
```

Role → permissions: `admin` all true. `viewer` only `viewData`. `entry` = `viewData` + the six sheet
columns (إضافة المزارعين→addFarmers, تسجيل المشتريات→recordPurchases, تعديل عمليات الآخرين→editOthers,
تسجيل المدفوعات→recordPayments, مشتريات التعبئة→packaging, تقفيل البرادات→closeCoolers);
`reopenCoolers`, `manageUsers`, `manageSettings` are admin-only. **Permissions are enforced in the backend
for every action** (table in section 6).

## 4. Sheet mapping

Layout comes from `sheets/schema.json` (generated by `sheets/build_sheet.py`): title row 1, description
row 2, **header row 3**, data from **row 4**. Columns are located **by header name**, never by position;
`الإصدار` (version, integer ≥ 1) and `مفتاح عدم التكرار` (idempotency key) are hidden columns.
Records are never deleted: cancellation sets status + reason.

Enum translation (sheet ⇄ API):

| field | sheet values → API |
|---|---|
| role | مدير→admin · موظف إدخال→entry · مشاهدة فقط→viewer |
| user status | نشط→active · معطّل→disabled · blank/unknown→disabled (fails closed; the bootstrap admin is still active) |
| cooler status | مفتوح→open · مقفّل→closed |
| purchase / payment status | فعّالة→active · ملغاة→cancelled |
| pay status | مدفوع→paid · جزئي→partial · غير مدفوع→unpaid |
| weight method | مباشر→direct · عينة→sample |
| packaging status | مسودة→draft · معتمد→approved · ملغى→cancelled |
| packaging item status | مكتمل→complete · غير مكتمل→incomplete · محذوف→removed |
| payment method | نقدًا→cash · تحويل بنكي→bank · محفظة إلكترونية→wallet |
| payee type | مزارع→farmer · مورد→supplier |
| payment target | شراء رمان→purchase · شراء تعبئة→packaging |
| farmer status | نشط→active · موقوف→inactive |
| yes/no | نعم→true · لا→false |

IDs: `CL-`, `FR-`, `PU-`, `PK-`, `PD-`, `PY-`, `US-`, `AU-`, `IT-` + 4+ digit zero-padded sequence
(next = max existing numeric suffix + 1, computed under the lock). Human numbers: cooler `رقم البراد`
= max + 1; farmer `رقم المزارع` = max + 1; packaging `رقم الشراء` = `P-` + 4 digits; payment `رقم الدفعة` = `D-` + 4 digits.

## 5. Numbers, money, time

* **API money is integer piasters** (`…Piasters`), **weights are integer grams** (`…Grams`). Clients parse
  user input (Arabic or Latin digits, `٫`/`.` decimal) into these integers by string arithmetic, not floats.
* Server formulas (authoritative, recomputed on every write):
  * `totalWeightGrams = boxes × avgWeightGrams`
  * `valuePiasters = round_half_up(totalWeightGrams × pricePerKgPiasters / 1000)`
  * packaging line `totalPiasters = quantity × unitPricePiasters` (quantity is an integer)
  * every total = sum of stored per-record values.
* The sheet stores human units: kg with up to 3 decimals, EGP with 2 decimals. Convert with
  `Math.round(x * 1000)` / `Math.round(x * 100)` when reading.
* Validation limits: boxes integer 1…100000; avgWeightGrams 1…60000; pricePerKgPiasters 1…100000;
  amounts > 0; partial payment < value; payment ≤ remaining.
* Sample method: `sampleWeightsGrams` (1…200 integers > 0) and optional `tareGrams` (≥ 0, default from
  settings `وزن الصندوق الفارغ (كغ)`). Server checks `avgWeightGrams === round(mean(sample) − tare)` (±1 g)
  else `VALIDATION` on `avgWeightGrams`. Stored as text `12.4، 12.9، …` (kg) and tare (kg).
* **Timestamps** are ISO-8601 strings **in the business time zone with offset**, e.g.
  `2026-10-02T06:40:00+03:00` (zone from settings `المنطقة الزمنية`, default `Africa/Cairo`). Clients show the
  wall-clock part as-is. Inputs (`occurredAt`, `paidAt`) use the same format; omitted ⇒ server "now".
  The real creation time and creator are always stored separately from `occurredAt`.

## 6. Actions

`P:` = required permission (all protected actions also need an active session). Mutations need
`requestId` and run under `LockService.getScriptLock().waitLock(25000)`.

### Reads (P: viewData)

* `dashboard.get` `{ period?: "season"|"today"|"week"|"month"|"all", coolerId?: string }` →
```json
{ "period": { "key": "season", "label": "هذا الموسم", "from": "…", "to": "…" },
  "empty": false,
  "kpis": { "closedCoolers": 12, "openCoolers": 2, "distinctFarmers": 37, "purchases": 168, "boxes": 7142,
            "weightGrams": 78315600, "purchaseValuePiasters": 117648240, "packagingApprovedPiasters": 11264000,
            "paidPiasters": 115190400, "remainingPiasters": 13721840, "remainingFarmersPiasters": 12221840,
            "remainingSuppliersPiasters": 1500000, "avgPricePerKgPiasters": 1502 },
  "currentCooler": CoolerSummary | null,
  "openCoolers": [CoolerSummary],
  "recent": [ { "type": "purchase|payment|packaging", "id": "PU-0023", "title": "حسن البدري",
                "subtitle": "شراء · براد 14 · محمد", "coolerNo": 14, "at": "…", "amountPiasters": 441000,
                "status": "paid|partial|unpaid|draft|approved|cancelled|active", "statusLabel": "جزئي" } ] }
```
  Period filters purchases by `occurredAt`, payments by `paidAt`, packaging by date; `season` starts at
  settings `بداية الموسم`. Cooler counts ignore the period. `coolerId` restricts everything to one cooler.
  `paidPiasters` = active payments whose `paidAt` is in the period. The remaining figures describe the rows of the
  period: `remainingFarmersPiasters` = Σ (value − all active payments) over the period's active purchases,
  `remainingSuppliersPiasters` = the same over the period's approved packaging, `remainingPiasters` = their sum. So
  they are never negative (a payment today for an older purchase lowers nothing in "today"); with `period: all`,
  `remainingPiasters = purchaseValuePiasters + packagingApprovedPiasters − paidPiasters`.
  A cooler row left by a failed `coolers.create` (compensated: `مقفّل`, no closing time, note `تعذّر إكمال الحفظ`)
  is not a real cooler: it is excluded from cooler counts, `openCoolers`, `currentCooler` and `coolers.list`.
  `currentCooler` = the given cooler, else the open cooler with the latest opening time. `recent` = last 10
  across purchases/payments/packaging (cancelled included, labelled). Cache the result for 60 s keyed by
  params + data version (bumped on every write).
* `coolers.list` `{ status?: "open"|"closed"|"all" }` → `{ coolers: [CoolerSummary] }` (newest first).
  `CoolerSummary`: `{ id, no, name, status, carNo, driver, notes, openedAt, openedBy, closedAt, closedBy,
  farmers, purchases, boxes, weightGrams, valuePiasters, paidPiasters, remainingPiasters,
  packagingApprovedPiasters, packagingLatePiasters, totalCostPiasters, avgPricePerKgPiasters, version,
  closeSnapshot: null | { farmers, purchases, boxes, weightGrams, valuePiasters, paidPiasters, remainingPiasters,
  packagingPiasters, totalCostPiasters } }` — live figures from active purchases/payments; closeSnapshot from the
  «عند التقفيل» columns.
* `coolers.get` `{ id }` → `{ cooler: CoolerSummary, purchases: [Purchase], packaging: [PackagingSummary] }`.
* `farmers.list` `{ query?: string, includeInactive?: bool }` → `{ farmers: [{ id, no, name, phone, village, notes, status, version }] }`.
* `purchases.list` `{ coolerId?, farmerId?, from?, to?, includeCancelled?: bool }` → `{ purchases: [Purchase] }`.
  `Purchase`: `{ id, coolerId, coolerNo, farmerId, farmerName, occurredAt, boxes, avgWeightGrams, weightMethod,
  sampleWeightsGrams, tareGrams, totalWeightGrams, pricePerKgPiasters, valuePiasters, paidPiasters,
  remainingPiasters, payStatus, status, cancelReason, notes, createdAt, createdBy, updatedAt, updatedBy, version }`.
* `payments.list` `{ targetId?, payeeId?, coolerId? }` → `{ payments: [Payment] }`.
  `Payment`: `{ id, no, payeeType, payeeName, payeeId, targetType, targetId, coolerId, coolerNo, amountPiasters,
  method, paidAt, status, cancelReason, notes, createdAt, createdBy, version }`.
* `packaging.list` `{ status?, coolerId? }` → `{ packaging: [PackagingSummary] }`;
  `packaging.get` `{ id }` → `{ packaging: PackagingSummary, items: [PackagingItem] }`.
  `PackagingSummary`: `{ id, no, supplier, invoiceNo, occurredAt, coolerId, coolerNo, status, itemsCount,
  incompleteCount, completeTotalPiasters, paidPiasters, remainingPiasters, late, notes, createdAt, createdBy,
  version }`; `PackagingItem`: `{ id, name, quantity|null, unit, unitPricePiasters|null, totalPiasters|null,
  status, notes, version }`.
* `itemTypes.list` → `{ itemTypes: [{ id, name, unit, order, active }] }`.
* `settings.get` → `{ businessName, currency, currencySymbol, timezone, moneyDecimals, weightDecimals,
  emptyBoxGrams, seasonStart }`.

### Mutations

| action | permission | payload → data |
|---|---|---|
| `coolers.create` | recordPurchases | `{ name?, carNo?, driver?, notes? }` → `{ cooler }` (status open, number = max+1). Idempotent on `requestId` (stored in `مفتاح عدم التكرار`): a repeat returns the same cooler with `replayed: true`. |
| `coolers.close` | closeCoolers | `{ id, expectedVersion, clientPendingCount }` → `{ cooler }`. `clientPendingCount > 0` ⇒ `VALIDATION` ("عمليات بانتظار المزامنة"). Writes the «عند التقفيل» snapshot, closedAt/By, status `مقفّل`. Already closed ⇒ `COOLER_CLOSED`. Closing again after a reopen replaces the snapshot with the figures of the latest close; the previous snapshot is kept in the audit row's previous values. |
| `coolers.reopen` | reopenCoolers (admin) | `{ id, reason }` (reason required) → `{ cooler }`. Keeps the snapshot; audit action `إعادة فتح`. |
| `farmers.create` | addFarmers | `{ name, phone?, village?, notes?, allowDuplicate? }` → `{ farmer }`. Same normalised name exists ⇒ `VALIDATION` field `name` unless `allowDuplicate`. Idempotent on `requestId` (stored in `مفتاح عدم التكرار`): a repeat returns the same farmer with `replayed: true`. |
| `farmers.update` | addFarmers | `{ id, expectedVersion, name?, phone?, village?, notes?, status? }` → `{ farmer }` |
| `purchases.create` | recordPurchases (+ addFarmers when `newFarmerName`) | `{ coolerId, farmerId? , newFarmerName?, boxes, avgWeightGrams, weightMethod, sampleWeightsGrams?, tareGrams?, pricePerKgPiasters, occurredAt?, notes?, payment: { mode: "full"|"partial"|"none", amountPiasters?, method? } }` → `{ purchase, payment|null, farmer|null, replayed }`. Cooler must be open (`COOLER_CLOSED`). `payment.mode = full` records a payment equal to the value. Idempotent on `requestId` (stored in `مفتاح عدم التكرار`): a repeat returns the stored purchase with `replayed: true`. |
| `purchases.update` | recordPurchases (+ editOthers if `createdBy` ≠ caller) | `{ id, expectedVersion, changes: { farmerId?, boxes?, avgWeightGrams?, weightMethod?, sampleWeightsGrams?, tareGrams?, pricePerKgPiasters?, occurredAt?, notes? } }` → `{ purchase }`. Cooler open; recompute value; if new value < paid ⇒ `VALIDATION`. Audit old/new values. |
| `purchases.cancel` | recordPurchases (+ editOthers) | `{ id, reason }` → `{ purchase }`. Cooler open; active payments exist ⇒ `VALIDATION` ("ألغِ الدفعات أولًا"). |
| `payments.create` | recordPayments | `{ targetType: "purchase"|"packaging", targetId, amountPiasters, method: "cash"|"bank"|"wallet", paidAt?, notes? }` → `{ payment, target }`. Allowed on closed coolers. Packaging target must be approved. Amount ≤ remaining. Idempotent on `requestId`. Updates the cached paid/remaining/payStatus on the target row. |
| `payments.cancel` | recordPayments | `{ id, reason }` → `{ payment, target }` |
| `packaging.save` | packaging | `{ id?, expectedVersion?, supplier?, invoiceNo?, coolerId?, occurredAt?, notes?, items: [{ id?, name, quantity?, unit, unitPricePiasters? }] }` → `{ packaging, items }`. Creates or updates a **draft**; empty quantity/price stay empty (never 0) and mark the item `غير مكتمل`. The client always sends the full item list: existing item rows of this draft that are not in the list get status `محذوف` (API `removed`) and are excluded from `items`, counts and totals. Approved/cancelled purchases cannot be saved (`VALIDATION`). Idempotent on `requestId` for creation. |
| `packaging.approve` | packaging | `{ id, expectedVersion }` → `{ packaging, items }`. Requires ≥ 1 item and every item complete. `تكلفة متأخرة` = `نعم` if the linked cooler is closed. |
| `packaging.cancel` | packaging | `{ id, reason }` → `{ packaging }`. Active payments ⇒ `VALIDATION`. |
| `itemTypes.save` | manageSettings | `{ id?, name, unit, order?, active? }` → `{ itemType }` |
| `users.list` | manageUsers | → `{ users: [User] }` |
| `users.add` | manageUsers | `{ email, name, role, permissions? }` → `{ user }`. Email must look like an email; duplicate ⇒ `VALIDATION`. |
| `users.update` | manageUsers | `{ id, expectedVersion, name?, role?, status?, permissions? }` → `{ user }`. Must not leave zero active admins (`VALIDATION`, "آخر مدير نشط"). The bootstrap admin cannot be disabled or demoted. Bumps the user version ⇒ that user's sessions become `SESSION_STALE`. |
| `settings.update` | manageSettings | `{ businessName?, currencySymbol?, timezone?, moneyDecimals?, weightDecimals?, emptyBoxGrams?, seasonStart? }` → settings |
| `sheet.status` | manageSettings | → `SheetStatus` (below). Read-only. |
| `sheet.repair` | manageSettings | → `SheetStatus`. Creates missing sheets/columns and reapplies formatting **without deleting data** (reuses `buildDataSheet_` / `buildSummary_` from `sheets/setup.gs`). |
| `sheet.connect` | manageSettings **and bootstrap admin only** | `{ spreadsheet: "<url or id>" }` → `SheetStatus` + `warning` ("البيانات القديمة لا تُنقل تلقائيًا"). Verifies `openById` works before saving `SPREADSHEET_ID`. Any other caller ⇒ `FORBIDDEN` (`details.permission: "manageSettings"`, `details.reason: "bootstrap_only"`), checked before the payload, so the connection account is never revealed to them. Reason: connecting another file moves all new data into a file someone else may own (section 1: only the owner's account touches the file). |

`SheetStatus`: `{ configured, spreadsheetId, title, url, connectedAs, timezone, ok,
sheets: [{ key, title, exists, rows, missingColumns: [], extraColumns: [] }], lastWriteAt, lastError: null | { at, message }, checkedAt }`.

`viewer` role can call reads only. Every mutation appends an audit row to `سجل التعديلات`:
id `AU-…`, time, user name (email), action label (إنشاء/تعديل/إلغاء/تقفيل/إعادة فتح/دفعة), record type
(براد/مزارع/شراء رمان/شراء تعبئة/دفعة/مستخدم/إعدادات/ملف), record id, Arabic description, previous values
(JSON), new values (JSON), reason.

## 7. Consistency rules

* **Idempotency**: every mutation's result is cached in `CacheService` under `req:<requestId>` for 6 h and
  returned verbatim on repeat (the client may retry freely with the same `requestId`). Creations also store
  the `requestId` in `مفتاح عدم التكرار` so repeats are detected even after the cache expires: purchases,
  payments, packaging, coolers and farmers. (Users and item types are protected by their unique email / name
  checks instead.) The coolers/farmers key columns were added after v1: a file without them keeps working with
  cache-only idempotency, and `sheet.status` lists them as missing until `sheet.repair` adds them.
  The client keeps the same `requestId` while it retries one submission (network error, timeout, `LOCK_TIMEOUT`)
  with an unchanged payload, and uses a new one for a new or edited submission.
* **Optimistic concurrency**: updates carry `expectedVersion`; mismatch ⇒ `CONFLICT`. Every write
  increments `الإصدار` and sets `آخر تعديل`/`عدّله` where the sheet has them.
* **Locking**: all mutations hold the script lock for the whole read-validate-write cycle.
* **Partial failure**: multi-row writes (purchase + payment, packaging + items) validate everything first,
  then write. If a later write throws, earlier rows written in that request are compensated (purchase/payment
  marked `ملغاة` with reason `تعذّر إكمال الحفظ`), `LAST_ERROR` is recorded, and `INTERNAL` is returned; the
  `requestId` result is not cached so a retry can succeed.
* **Batch reads**: one `getValues()` per sheet per request (memoised); dashboard cached 60 s.
* A success response is returned only after `SpreadsheetApp.flush()`.

## 8. Apps Script API subset

The backend uses only these Apps Script services (the Node harness fakes exactly this set; formatting
methods used by `setup.gs` are chainable no-ops in the fake):

`SpreadsheetApp.openById / getActiveSpreadsheet / flush / newDataValidation / newConditionalFormatRule / BorderStyle`,
`Spreadsheet.getId / getName / getUrl / getSheetByName / getSheets / insertSheet / getSpreadsheetTimeZone / setSpreadsheetTimeZone / toast / setActiveSheet / moveActiveSheet / deleteSheet`,
`Sheet.getName / getLastRow / getLastColumn / getMaxRows / getMaxColumns / getRange(row, col, numRows?, numCols?) / getRange(a1) / appendRow / insertColumnsAfter / insertRowsAfter / (formatting…)`,
`Range.getValues / setValues / getValue / setValue / setFormula / setFormulas / (formatting…)`,
`LockService.getScriptLock().waitLock / tryLock / releaseLock`,
`CacheService.getScriptCache().get / put / remove / removeAll`,
`PropertiesService.getScriptProperties().getProperty / setProperty / getProperties / deleteProperty`,
`UrlFetchApp.fetch(url, {muteHttpExceptions})` → `getResponseCode / getContentText`,
`Utilities.computeHmacSha256Signature / base64EncodeWebSafe / base64DecodeWebSafe / newBlob(bytes).getDataAsString / getUuid / formatDate / sleep`,
`Session.getEffectiveUser().getEmail / Session.getScriptTimeZone`,
`ContentService.createTextOutput(s).setMimeType(ContentService.MimeType.JSON)`.
