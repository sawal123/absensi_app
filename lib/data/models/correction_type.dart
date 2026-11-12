enum CorrectionType {
  checkIn('Perbaikan · Jam masuk', 'check_in'),
  checkOut('Perbaikan · Jam pulang', 'check_out'),
  both('Perbaikan · Masuk & pulang', 'both');

  const CorrectionType(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static CorrectionType fromApi(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final type in CorrectionType.values) {
      if (type.apiValue == normalized) return type;
    }
    return CorrectionType.checkOut;
  }
}
