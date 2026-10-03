/**
 * Coolers.gs — صفحة «البرادات»: الفتح والتقفيل وإعادة الفتح، وملخص كل براد.
 * أعمدة «عند التقفيل» تُكتب لحظة التقفيل فقط، وإعادة الفتح تُبقيها كما هي. إعادة التقفيل بعد إعادة
 * الفتح تستبدلها بأرقام التقفيل الأخير (العقد §6: كل تقفيل يكتب اللقطة)، واللقطة السابقة تُحفظ في
 * «القيم السابقة» بسجل التعديلات.
 */

const RMN_SNAPSHOT_COLUMNS = Object.freeze({
  farmers: 'عدد المزارعين عند التقفيل',
  purchases: 'عدد العمليات عند التقفيل',
  boxes: 'الصناديق عند التقفيل',
  weightGrams: 'الوزن عند التقفيل (كغ)',
  valuePiasters: 'قيمة الرمان عند التقفيل (ج.م)',
  paidPiasters: 'المدفوع عند التقفيل (ج.م)',
  remainingPiasters: 'المتبقي عند التقفيل (ج.م)',
  packagingPiasters: 'التعبئة عند التقفيل (ج.م)',
  totalCostPiasters: 'إجمالي التكلفة عند التقفيل (ج.م)',
});

function coolerIsClosed_(rec) {
  return enumToApi_('coolerStatus', rec['الحالة'], 'open') === 'closed';
}

/**
 * صف براد بقي من coolers.create فشل حفظه فعُوِّض (Store.gs): مقفّل دون وقت تقفيل، وفي ملاحظاته
 * «تعذّر إكمال الحفظ». لم يُبلَّغ به أحد (الرد كان INTERNAL)، فلا يظهر في القوائم ولا يُعدّ في اللوحة.
 */
function coolerIsCompensated_(rec) {
  return coolerIsClosed_(rec) && !inPresent_(rec['تاريخ ووقت التقفيل']) &&
    cellStr_(rec['ملاحظات']).indexOf(RMN_CFG.compensationReason) >= 0;
}

function coolerClosedError_(rec, message) {
  const no = cellInt_(rec['رقم البراد']);
  return apiError_('COOLER_CLOSED', message ||
    ('البراد رقم ' + no + ' مقفّل، فلا يمكن إضافة مشتريات رمان إليه أو تعديلها أو إلغاؤها. ' +
      'اطلب من المدير إعادة فتحه إن لزم التعديل.'),
    'coolerId', { coolerId: cellStr_(rec['المعرّف']), coolerNo: no });
}

/** لقطة «عند التقفيل» من الأعمدة، أو null إن لم يُقفَل البراد من قبل. */
function coolerSnapshot_(rec) {
  const C2 = RMN_SNAPSHOT_COLUMNS;
  if (!inPresent_(rec[C2.purchases]) && !inPresent_(rec[C2.valuePiasters])) return null;
  return {
    farmers: cellInt_(rec[C2.farmers]) || 0,
    purchases: cellInt_(rec[C2.purchases]) || 0,
    boxes: cellInt_(rec[C2.boxes]) || 0,
    weightGrams: cellGrams_(rec[C2.weightGrams]) || 0,
    valuePiasters: cellMoney_(rec[C2.valuePiasters]) || 0,
    paidPiasters: cellMoney_(rec[C2.paidPiasters]) || 0,
    remainingPiasters: cellMoney_(rec[C2.remainingPiasters]) || 0,
    packagingPiasters: cellMoney_(rec[C2.packagingPiasters]) || 0,
    totalCostPiasters: cellMoney_(rec[C2.totalCostPiasters]) || 0,
  };
}

/** CoolerSummary بالأرقام الحية من العمليات والدفعات الفعّالة. */
function coolerSummary_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const a = dmCoolerAgg_(id);
  return {
    id: id,
    no: cellInt_(rec['رقم البراد']),
    name: cellStr_(rec['الاسم / الوصف']),
    status: enumToApi_('coolerStatus', rec['الحالة'], 'open'),
    carNo: cellStr_(rec['رقم السيارة']),
    driver: cellStr_(rec['السائق']),
    notes: cellStr_(rec['ملاحظات']),
    openedAt: cellIso_(rec['تاريخ ووقت الفتح']),
    openedBy: labelName_(rec['فتحه']),
    closedAt: cellIso_(rec['تاريخ ووقت التقفيل']),
    closedBy: labelName_(rec['قفّله']),
    farmers: a.farmers,
    purchases: a.purchases,
    boxes: a.boxes,
    weightGrams: a.weightGrams,
    valuePiasters: a.valuePiasters,
    paidPiasters: a.paidPiasters,
    remainingPiasters: a.valuePiasters - a.paidPiasters,
    packagingApprovedPiasters: a.packagingApprovedPiasters,
    packagingLatePiasters: a.packagingLatePiasters,
    totalCostPiasters: a.valuePiasters + a.packagingApprovedPiasters,
    avgPricePerKgPiasters: avgPricePerKg_(a.valuePiasters, a.weightGrams),
    version: stVersion_(rec),
    closeSnapshot: coolerSnapshot_(rec),
  };
}

/** البرادات الحقيقية (دون صفوف الحفظ الفاشل) من الأحدث إلى الأقدم. */
function coolersSorted_() {
  const rows = stTable_('coolers').rows.filter(function (r) { return !coolerIsCompensated_(r); });
  rows.sort(function (a, b) { return (cellInt_(b['رقم البراد']) || 0) - (cellInt_(a['رقم البراد']) || 0); });
  return rows;
}

/** يجد البراد أو NOT_FOUND. */
function coolersMustFind_(id, field) {
  const rec = stFindById_(stTable_('coolers'), id);
  if (!rec) failNotFound_(field || 'id', 'البراد', id);
  return rec;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** coolers.list {status?: open|closed|all} — الأحدث أولًا. */
function coolersListAction_(p) {
  dmIndex_();
  const status = inEnum_(p.status, 'status', 'حالة البراد', { open: 'مفتوح', closed: 'مقفّل', all: 'الكل' }) || 'all';
  const list = coolersSorted_().map(coolerSummary_).filter(function (c) {
    return status === 'all' || c.status === status;
  });
  return { coolers: list };
}

/** coolers.get {id} → {cooler, purchases, packaging}. */
function coolersGetAction_(p) {
  dmIndex_();
  const id = inId_(p.id, 'id', 'البراد');
  const rec = coolersMustFind_(id, 'id');
  const purchases = stTable_('purchases').rows
    .filter(function (r) { return cellStr_(r['معرّف البراد']) === id; })
    .map(purchaseToApi_);
  purchases.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  const packaging = stTable_('packaging').rows
    .filter(function (r) { return cellStr_(r['معرّف البراد']) === id; })
    .map(packagingSummary_);
  packaging.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return {
    cooler: coolerSummary_(rec),
    purchases: purchases.map(dmStripPrivate_),
    packaging: packaging.map(dmStripPrivate_),
  };
}

/**
 * coolers.create {name?, carNo?, driver?, notes?} — رقم البراد = الأكبر + 1، والحالة مفتوح.
 * idempotent على requestId (العقد §7): يُحفظ في «مفتاح عدم التكرار»، فإعادة الطلب نفسه بعد انتهاء ذاكرة
 * الطلبات تعيد البراد نفسه مع replayed: true بدل فتح براد ثانٍ.
 */
function coolersCreateAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const replay = stFindByKey_(t, req && req.requestId);
  if (replay) return { cooler: coolerSummary_(replay), replayed: true };
  const name = inStr_(p.name, 'name', 'اسم البراد / الوصف', { max: 80 });
  const carNo = inStr_(p.carNo, 'carNo', 'رقم السيارة', { max: 30 });
  const driver = inStr_(p.driver, 'driver', 'اسم السائق', { max: 80 });
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const row = {
    'المعرّف': stNextId_(t, 'CL'),
    'رقم البراد': stNextNumber_(t, 'رقم البراد'),
    'الاسم / الوصف': name,
    'رقم السيارة': carNo,
    'السائق': driver,
    'تاريخ ووقت الفتح': rqNow_(),
    'الحالة': 'مفتوح',
    'فتحه': userLabel_(rq_().user),
    'ملاحظات': notes,
    'مفتاح عدم التكرار': req && req.requestId ? req.requestId : '',
  };
  const rec = stAppend_(t, [row])[0];
  auditAdd_('إنشاء', 'براد', row['المعرّف'], 'فتح البراد رقم ' + row['رقم البراد'], null, row, '');
  return { cooler: coolerSummary_(rec) };
}

/** coolers.close {id, expectedVersion, clientPendingCount} — يكتب لقطة «عند التقفيل». */
function coolersCloseAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const id = inId_(p.id, 'id', 'البراد');
  // مطلوب (العقد §6 لا يعلّمه اختياريًا): بدونه لا نعرف إن كان على الجهاز عمليات لم تُرسل بعد.
  const pending = inInt_(p.clientPendingCount, 'clientPendingCount', 'عدد العمليات بانتظار المزامنة', {
    required: true, min: 0, max: 100000,
    hint: 'حدّث التطبيق، وانتظر حتى تُرسل كل العمليات بانتظار المزامنة، ثم أعد التقفيل.',
  });
  if (pending > 0) {
    failValidation_('clientPendingCount',
      'توجد ' + pending + ' عمليات بانتظار المزامنة على هذا الجهاز. انتظر حتى تُرسل كلها (أو اتصل بالإنترنت) ثم أعد التقفيل.',
      { pending: pending });
  }
  const rec = coolersMustFind_(id, 'id');
  if (coolerIsClosed_(rec)) {
    throw coolerClosedError_(rec, 'البراد رقم ' + cellInt_(rec['رقم البراد']) + ' مقفّل بالفعل. لا حاجة لتقفيله مرة أخرى.');
  }
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) failConflict_('هذا البراد', stVersion_(rec), coolerSummary_(rec));

  const live = coolerSummary_(rec);
  const prevSnapshot = coolerSnapshot_(rec);
  const S = RMN_SNAPSHOT_COLUMNS;
  const c = {
    'الحالة': 'مقفّل',
    'تاريخ ووقت التقفيل': rqNow_(),
    'قفّله': userLabel_(rq_().user),
  };
  c[S.farmers] = live.farmers;
  c[S.purchases] = live.purchases;
  c[S.boxes] = live.boxes;
  c[S.weightGrams] = toKg_(live.weightGrams);
  c[S.valuePiasters] = toEgp_(live.valuePiasters);
  c[S.paidPiasters] = toEgp_(live.paidPiasters);
  c[S.remainingPiasters] = toEgp_(live.remainingPiasters);
  c[S.packagingPiasters] = toEgp_(live.packagingApprovedPiasters);
  c[S.totalCostPiasters] = toEgp_(live.totalCostPiasters);
  stUpdate_(t, rec, c);
  const after = coolerSummary_(rec);
  auditAdd_('تقفيل', 'براد', id,
    'تقفيل البراد رقم ' + after.no + ': ' + after.purchases + ' عملية، ' + fmtKgMsg_(after.weightGrams) +
    '، قيمة ' + fmtMoneyMsg_(after.valuePiasters),
    prevSnapshot ? { closeSnapshot: prevSnapshot } : { status: 'open' },
    { status: 'closed', closeSnapshot: after.closeSnapshot }, '');
  return { cooler: after };
}

/** coolers.reopen {id, reason} — للمدير فقط؛ تبقى اللقطة. */
function coolersReopenAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const id = inId_(p.id, 'id', 'البراد');
  const reason = inReason_(p.reason, 'لإعادة فتح البراد');
  const rec = coolersMustFind_(id, 'id');
  if (!coolerIsClosed_(rec)) {
    failValidation_('id', 'البراد رقم ' + cellInt_(rec['رقم البراد']) + ' مفتوح بالفعل. لا حاجة لإعادة فتحه.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_('هذا البراد', stVersion_(rec), coolerSummary_(rec));
  }
  stUpdate_(t, rec, { 'الحالة': 'مفتوح' });
  auditAdd_('إعادة فتح', 'براد', id, 'إعادة فتح البراد رقم ' + cellInt_(rec['رقم البراد']),
    { status: 'closed' }, { status: 'open' }, reason);
  return { cooler: coolerSummary_(rec) };
}
