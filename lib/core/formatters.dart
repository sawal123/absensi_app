import 'package:intl/intl.dart';

final NumberFormat _rupiahFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// 5000000 -> Rp 5.000.000
String formatRupiah(num value) => _rupiahFormat.format(value);

const _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _shortDayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// yyyy-MM-dd key used as the attendance row identifier.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String formatDayName(DateTime date) => _dayNames[date.weekday - 1];

String formatDayShort(DateTime date) => _shortDayNames[date.weekday - 1];

String monthName(int month) => _monthNames[month - 1];

String monthShort(int month) => _shortMonths[month - 1];

String formatFullDate(DateTime date) =>
    '${formatDayName(date)}, ${date.day} ${monthName(date.month)} ${date.year}';

String formatMonthYear(DateTime date) =>
    '${monthName(date.month)} ${date.year}';

String formatShortDate(DateTime date) =>
    '${date.day} ${monthShort(date.month)} ${date.year}';

String formatShortDateNoYear(DateTime date) =>
    '${date.day} ${monthShort(date.month)}';

String formatTime(DateTime? time) =>
    time == null ? '--:--' : DateFormat('HH:mm').format(time);

/// Clock style used across the mockups: 07.58
String formatClock(DateTime? time) {
  if (time == null) return '--:--';
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour.$minute';
}

String formatClockValue(String time) => time.replaceAll(':', '.');

String formatClockRange(String start, String end) =>
    '${formatClockValue(start)} – ${formatClockValue(end)}';

String formatDateTime(DateTime? time) =>
    time == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(time);

/// 4 Nov 2026 · 16.20 WIB
String formatStamp(DateTime time) =>
    '${time.day} ${monthShort(time.month)} ${time.year} · '
    '${formatClock(time)} WIB';

/// 9–10 November 2026, 28 Okt – 2 Nov 2026 or 30 Des 2025 – 2 Jan 2026.
String formatDateRange(DateTime start, DateTime end) {
  if (isSameDay(start, end)) {
    return '${start.day} ${monthName(start.month)} ${start.year}';
  }

  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${monthName(start.month)} ${start.year}';
  }

  if (start.year == end.year) {
    return '${start.day} ${monthShort(start.month)} – '
        '${end.day} ${monthShort(end.month)} ${start.year}';
  }

  return '${formatShortDate(start)} – ${formatShortDate(end)}';
}

String greetingFor(DateTime now) {
  if (now.hour < 11) return 'Selamat pagi,';
  if (now.hour < 15) return 'Selamat siang,';
  if (now.hour < 18) return 'Selamat sore,';
  return 'Selamat malam,';
}

String firstNameOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Karyawan';
  return trimmed.split(RegExp(r'\s+')).first;
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String formatDurationShort(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}j ${minutes}m';
}

String formatWorkingDays(int days) =>
    days <= 1 ? '1 hari kerja' : '$days hari kerja';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime startOfWeek(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime endOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0);

DateTime parseTimeOfDay(String value) => dateWithTime(DateTime.now(), value);

/// Menggabungkan [date] dengan jam [value] berformat HH:mm.
DateTime dateWithTime(DateTime date, String value) {
  final parts = value.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

/// Jumlah hari kerja (Senin–Jumat) dalam rentang inklusif.
int workingDaysBetween(
  DateTime start,
  DateTime end, {
  Set<String> holidays = const {},
}) {
  final from = dateOnly(start);
  final to = dateOnly(end);
  if (to.isBefore(from)) return 0;

  var days = 0;
  var cursor = from;
  while (!cursor.isAfter(to)) {
    if (cursor.weekday != DateTime.saturday &&
        cursor.weekday != DateTime.sunday &&
        !holidays.contains(dateKey(cursor))) {
      days++;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}

bool isLate(DateTime checkIn, String workStart, [int toleranceMinutes = 0]) {
  final start = dateWithTime(
    checkIn,
    workStart,
  ).add(Duration(minutes: toleranceMinutes));
  return checkIn.isAfter(start);
}
