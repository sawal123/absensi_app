import 'package:absensi/core/formatters.dart';
import 'package:absensi/core/geo.dart';
import 'package:absensi/core/security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password hashing is deterministic and salted', () {
    expect(hashPassword('admin123'), hashPassword('admin123'));
    expect(hashPassword('admin123'), isNot(hashPassword('admin124')));
  });

  test('dateKey pads month and day', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('isLate compares against work start time', () {
    final onTime = DateTime(2026, 1, 5, 7, 59);
    final late = DateTime(2026, 1, 5, 8, 1);
    expect(isLate(onTime, '08:00'), isFalse);
    expect(isLate(late, '08:00'), isTrue);
  });

  test('distanceInMeters returns zero for identical points', () {
    expect(
      distanceInMeters(-6.2, 106.816666, -6.2, 106.816666),
      closeTo(0, 0.001),
    );
  });

  test('distanceInMeters is roughly one degree of latitude', () {
    final distance = distanceInMeters(0, 0, 1, 0);
    expect(distance, closeTo(111195, 500));
  });
}
