class SheetCheck {
  const SheetCheck({
    required this.key,
    required this.title,
    required this.exists,
    this.rows = 0,
    this.missingColumns = const [],
    this.extraColumns = const [],
  });

  factory SheetCheck.fromJson(Map<String, dynamic> j) => SheetCheck(
        key: j['key'] as String? ?? '',
        title: j['title'] as String? ?? '',
        exists: j['exists'] == true,
        rows: (j['rows'] as num?)?.toInt() ?? 0,
        missingColumns: [for (final c in (j['missingColumns'] as List?) ?? const []) c.toString()],
        extraColumns: [for (final c in (j['extraColumns'] as List?) ?? const []) c.toString()],
      );

  final String key;
  final String title;
  final bool exists;
  final int rows;
  final List<String> missingColumns;
  final List<String> extraColumns;

  bool get ok => exists && missingColumns.isEmpty;
}

class SheetStatus {
  const SheetStatus({
    required this.configured,
    required this.ok,
    this.spreadsheetId,
    this.title,
    this.url,
    this.connectedAs,
    this.timezone,
    this.sheets = const [],
    this.lastWriteAt,
    this.lastErrorAt,
    this.lastErrorMessage,
    this.checkedAt,
    this.warning,
  });

  factory SheetStatus.fromJson(Map<String, dynamic> j) {
    final err = (j['lastError'] as Map?)?.cast<String, dynamic>();
    return SheetStatus(
      configured: j['configured'] == true,
      ok: j['ok'] == true,
      spreadsheetId: j['spreadsheetId'] as String?,
      title: j['title'] as String?,
      url: j['url'] as String?,
      connectedAs: j['connectedAs'] as String?,
      timezone: j['timezone'] as String?,
      sheets: [for (final s in (j['sheets'] as List?) ?? const []) SheetCheck.fromJson((s as Map).cast<String, dynamic>())],
      lastWriteAt: j['lastWriteAt'] as String?,
      lastErrorAt: err?['at'] as String?,
      lastErrorMessage: err?['message'] as String?,
      checkedAt: j['checkedAt'] as String?,
      warning: j['warning'] as String?,
    );
  }

  final bool configured;
  final bool ok;
  final String? spreadsheetId;
  final String? title;
  final String? url;

  /// حساب Google المالك للسكربت، وهو الحساب الوحيد الذي يصل إلى الملف.
  final String? connectedAs;
  final String? timezone;
  final List<SheetCheck> sheets;
  final String? lastWriteAt;
  final String? lastErrorAt;
  final String? lastErrorMessage;
  final String? checkedAt;

  /// تنبيه بعد تغيير الملف: البيانات القديمة لا تُنقل تلقائيًا.
  final String? warning;

  bool get needsRepair => sheets.any((s) => !s.ok);
}
