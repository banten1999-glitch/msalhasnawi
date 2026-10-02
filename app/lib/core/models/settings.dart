class BusinessSettings {
  const BusinessSettings({
    this.businessName = 'حاسبة الحسناوي',
    this.currency = 'جنيه مصري (EGP)',
    this.currencySymbol = 'ج.م',
    this.timezone = 'Africa/Cairo',
    this.moneyDecimals = 2,
    this.weightDecimals = 1,
    this.emptyBoxGrams = 1900,
    this.seasonStart,
  });

  factory BusinessSettings.fromJson(Map<String, dynamic> j) => BusinessSettings(
        businessName: j['businessName'] as String? ?? 'حاسبة الحسناوي',
        currency: j['currency'] as String? ?? 'جنيه مصري (EGP)',
        currencySymbol: j['currencySymbol'] as String? ?? 'ج.م',
        timezone: j['timezone'] as String? ?? 'Africa/Cairo',
        moneyDecimals: (j['moneyDecimals'] as num?)?.toInt() ?? 2,
        weightDecimals: (j['weightDecimals'] as num?)?.toInt() ?? 1,
        emptyBoxGrams: (j['emptyBoxGrams'] as num?)?.toInt() ?? 1900,
        seasonStart: j['seasonStart'] as String?,
      );

  final String businessName;
  final String currency;
  final String currencySymbol;
  final String timezone;
  final int moneyDecimals;
  final int weightDecimals;
  final int emptyBoxGrams;
  final String? seasonStart;
}
