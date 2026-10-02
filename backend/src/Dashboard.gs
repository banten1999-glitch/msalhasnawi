/**
 * Dashboard.gs — لوحة التحكم (dashboard.get).
 *
 * الفترة تصفّي المشتريات بتاريخ العملية، والدفعات بتاريخ الدفعة، والتعبئة بتاريخ الشراء.
 * عدد البرادات لا يتأثر بالفترة. coolerId يقصر كل شيء على براد واحد.
 * النتيجة تُحفظ في CacheService 60 ثانية بمفتاح يضم المدخلات ونسخة البيانات (تزيد مع كل كتابة).
 */

const RMN_PERIODS = Object.freeze({
  season: 'هذا الموسم',
  today: 'اليوم',
  week: 'آخر 7 أيام',
  month: 'هذا الشهر',
  all: 'كل الفترات',
});

const RMN_RECENT_LIMIT = 10;

const RMN_STATUS_LABELS = Object.freeze({
  paid: 'مدفوع', partial: 'جزئي', unpaid: 'غير مدفوع', cancelled: 'ملغاة', active: 'فعّالة',
  draft: 'مسودة', approved: 'معتمد',
});

/** حدود الفترة {from, to} (Date أو null) بتوقيت العمل. */
function dashboardRange_(key, seasonStart, now, tz) {
  const endToday = endOfLocalDay_(now, tz);
  const p = partsInTz_(now, tz);
  if (key === 'all') return { from: null, to: null };
  if (key === 'today') return { from: startOfLocalDay_(now, tz), to: endToday };
  if (key === 'week') {
    const d = addDaysYmd_(p.y, p.mo, p.d, -6);
    return { from: localToInstant_(d.y, d.mo, d.d, 0, 0, 0, tz), to: endToday };
  }
  if (key === 'month') return { from: localToInstant_(p.y, p.mo, 1, 0, 0, 0, tz), to: endToday };
  // season
  let from = null;
  if (seasonStart) {
    const d = parseDateText_(seasonStart, tz);
    if (d) from = startOfLocalDay_(d, tz);
  }
  return { from: from, to: endToday };
}

/** هل التاريخ داخل الفترة؟ (السجل بلا تاريخ يدخل فقط في فترة بلا حدود.) */
function dmInRange_(date, range) {
  if (!range || (!range.from && !range.to)) return true;
  if (!date) return false;
  const t = date.getTime();
  if (range.from && t < range.from.getTime()) return false;
  if (range.to && t > range.to.getTime()) return false;
  return true;
}

/** dashboard.get {period?, coolerId?} */
function dashboardGetAction_(p) {
  const period = inEnum_(p.period, 'period', 'الفترة', RMN_PERIODS) || 'season';
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const tz = rqTzSafe_();
  const now = rqNow_();
  const key = RMN_CFG.dashboardCachePrefix + stDataVersion_() + ':' + period + ':' + coolerId + ':' +
    Utilities.formatDate(now, tz, RMN_CFG.fmtDay) + ':' + tz;
  const hit = cacheGet_(key);
  if (hit) {
    try {
      return JSON.parse(hit);
    } catch (e) {
      // نعيد الحساب.
    }
  }
  const data = dashboardCompute_(period, coolerId, now, tz);
  cachePut_(key, JSON.stringify(data), RMN_CFG.dashboardCacheSeconds);
  return data;
}

function dashboardCompute_(period, coolerId, now, tz) {
  stRequire_(stDataKeys_().concat(['settings']));
  const settings = settingsRead_();
  const ix = dmIndex_();
  if (coolerId) coolersMustFind_(coolerId, 'coolerId');
  const range = dashboardRange_(period, settings.seasonStart, now, tz);
  const inScope = function (cid) { return !coolerId || cid === coolerId; };

  const k = {
    closedCoolers: 0, openCoolers: 0, distinctFarmers: 0, purchases: 0, boxes: 0, weightGrams: 0,
    purchaseValuePiasters: 0, packagingApprovedPiasters: 0, paidPiasters: 0, remainingPiasters: 0,
    remainingFarmersPiasters: 0, remainingSuppliersPiasters: 0, avgPricePerKgPiasters: 0,
  };
  const recent = [];
  let records = 0;

  // البرادات (لا تتأثر بالفترة)
  const coolerRows = coolersSorted_().filter(function (r) { return inScope(cellStr_(r['المعرّف'])); });
  coolerRows.forEach(function (r) {
    if (coolerIsClosed_(r)) k.closedCoolers++;
    else k.openCoolers++;
  });

  // المشتريات
  const farmers = {};
  stTable_('purchases').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = purchaseToApi_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'purchase', id: x.id, title: x.farmerName || 'مزارع',
      subtitle: dashboardSubtitle_('شراء', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.occurredAt || x.createdAt, amountPiasters: x.valuePiasters,
      status: x.status === 'cancelled' ? 'cancelled' : x.payStatus,
      statusLabel: RMN_STATUS_LABELS[x.status === 'cancelled' ? 'cancelled' : x.payStatus],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء الفعلي']),
    });
    if (x.status !== 'active') return;
    k.purchases++;
    k.boxes += x.boxes;
    k.weightGrams += x.totalWeightGrams;
    k.purchaseValuePiasters += x.valuePiasters;
    if (x.farmerId && !farmers[x.farmerId]) {
      farmers[x.farmerId] = true;
      k.distinctFarmers++;
    }
  });

  // مشتريات التعبئة
  stTable_('packaging').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = packagingSummary_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'packaging', id: x.id, title: x.supplier || ('شراء تعبئة ' + x.no),
      subtitle: dashboardSubtitle_('تعبئة', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.occurredAt || x.createdAt, amountPiasters: x.completeTotalPiasters,
      status: x.status, statusLabel: RMN_STATUS_LABELS[x.status],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء']),
    });
    if (x.status === 'approved') k.packagingApprovedPiasters += x.completeTotalPiasters;
  });

  // الدفعات
  let paidFarmers = 0;
  let paidSuppliers = 0;
  stTable_('payments').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = paymentToApi_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'payment', id: x.id, title: x.payeeName || (x.payeeType === 'supplier' ? 'مورد' : 'مزارع'),
      subtitle: dashboardSubtitle_('دفعة', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.paidAt || x.createdAt, amountPiasters: x.amountPiasters,
      status: x.status, statusLabel: RMN_STATUS_LABELS[x.status],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء']),
    });
    if (x.status !== 'active') return;
    k.paidPiasters += x.amountPiasters;
    if (x.targetType === 'packaging') paidSuppliers += x.amountPiasters;
    else paidFarmers += x.amountPiasters;
  });

  k.remainingPiasters = k.purchaseValuePiasters + k.packagingApprovedPiasters - k.paidPiasters;
  k.remainingFarmersPiasters = k.purchaseValuePiasters - paidFarmers;
  k.remainingSuppliersPiasters = k.packagingApprovedPiasters - paidSuppliers;
  k.avgPricePerKgPiasters = avgPricePerKg_(k.purchaseValuePiasters, k.weightGrams);

  // البراد الحالي والبرادات المفتوحة
  const open = coolerRows.filter(function (r) { return !coolerIsClosed_(r); });
  let current = null;
  if (coolerId) {
    current = coolerRows[0] || null;
  } else if (open.length) {
    current = open.slice().sort(dmByTimeDesc_(function (r) { return cellDate_(r['تاريخ ووقت الفتح']); },
      function (r) { return seqNumber_(r['المعرّف'], 'CL'); }))[0];
  }

  recent.sort(function (a, b) {
    const ta = a._t ? a._t.getTime() : 0;
    const tb = b._t ? b._t.getTime() : 0;
    if (ta !== tb) return tb - ta;
    const ca = a._c ? a._c.getTime() : 0;
    const cb = b._c ? b._c.getTime() : 0;
    if (ca !== cb) return cb - ca;
    return a.id < b.id ? 1 : (a.id > b.id ? -1 : 0);
  });

  return {
    period: {
      key: period, label: RMN_PERIODS[period],
      from: range.from ? fmtIso_(range.from) : null, to: range.to ? fmtIso_(range.to) : null,
    },
    empty: records === 0,
    kpis: k,
    currentCooler: current ? coolerSummary_(current) : null,
    openCoolers: open.map(coolerSummary_),
    recent: recent.slice(0, RMN_RECENT_LIMIT).map(dmStripPrivate_),
  };
}

function dashboardSubtitle_(kind, coolerNo, by) {
  const parts = [kind];
  if (coolerNo !== null && coolerNo !== undefined) parts.push('براد ' + coolerNo);
  if (by) parts.push(by);
  return parts.join(' · ');
}
