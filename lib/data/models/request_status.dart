enum RequestStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak'),
  cancelled('Dibatalkan');

  const RequestStatus(this.label);

  final String label;

  bool get isPending => this == RequestStatus.pending;

  bool get isDecided => this != RequestStatus.pending;

  String get apiValue => name;

  static RequestStatus fromApi(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final status in RequestStatus.values) {
      if (status.name == normalized) return status;
    }
    return RequestStatus.pending;
  }
}
