import 'package:absensi/core/formatters.dart';
import 'package:absensi/data/demo/demo_approvals.dart';
import 'package:absensi/data/demo/demo_schedule.dart';
import 'package:absensi/data/models/office_settings.dart';
import 'package:absensi/data/models/request_status.dart';
import 'package:absensi/providers/approval_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_absensi_api.dart';

void main() {
  final now = DateTime(2026, 11, 7, 10, 15);

  group('formatters', () {
    test('formatClock uses the dotted style from the mockups', () {
      expect(formatClock(DateTime(2026, 11, 5, 7, 58)), '07.58');
      expect(formatClock(DateTime(2026, 11, 5, 17, 5)), '17.05');
      expect(formatClock(null), '--:--');
    });

    test('formatDateRange collapses the shared month', () {
      expect(
        formatDateRange(DateTime(2026, 11, 9), DateTime(2026, 11, 10)),
        '9–10 November 2026',
      );
      expect(
        formatDateRange(DateTime(2026, 11, 9), DateTime(2026, 11, 9)),
        '9 November 2026',
      );
      expect(
        formatDateRange(DateTime(2026, 10, 28), DateTime(2026, 11, 2)),
        '28 Okt – 2 Nov 2026',
      );
    });

    test('startOfWeek returns the previous Monday', () {
      final monday = startOfWeek(DateTime(2026, 11, 7));
      expect(monday, DateTime(2026, 11, 2));
    });

    test('greetingFor follows the time of day', () {
      expect(greetingFor(DateTime(2026, 11, 7, 7)), 'Selamat pagi,');
      expect(greetingFor(DateTime(2026, 11, 7, 13)), 'Selamat siang,');
      expect(greetingFor(DateTime(2026, 11, 7, 17)), 'Selamat sore,');
      expect(greetingFor(DateTime(2026, 11, 7, 21)), 'Selamat malam,');
    });

    test('initials keeps the first and last name', () {
      expect(initials('Aditya Pratama'), 'AP');
      expect(initials('Budi'), 'B');
      expect(initials('  '), '?');
    });
  });

  group('demo schedule', () {
    const settings = OfficeSettings();

    test('friday uses the night shift and sunday is off', () {
      expect(
        DemoSchedule.shiftFor(DateTime(2026, 11, 6), settings)!.crossDay,
        isTrue,
      );
      expect(DemoSchedule.shiftFor(DateTime(2026, 11, 8), settings), isNull);
    });

    test('nextShift skips the weekend', () {
      final next = DemoSchedule.nextShift(DateTime(2026, 11, 7), settings);
      expect(next, isNotNull);
      expect(next!.date, DateTime(2026, 11, 9));
      expect(next.shift.name, 'Reguler');
    });
  });

  group('demo dataset', () {
    test('contains expanded leave and correction fixtures', () {
      final users = {
        for (var i = 0; i < DemoApprovals.employees.length; i++)
          DemoApprovals.employees[i].email: i + 2,
      };
      expect(DemoApprovals.leaves(now, users), hasLength(8));
      expect(DemoApprovals.corrections(now, users), hasLength(5));
      expect(DemoApprovals.leaveTypes, hasLength(3));
    });
  });

  group('approval provider', () {
    late FakeAbsensiApi api;
    late ApprovalProvider provider;

    setUp(() async {
      api = FakeAbsensiApi.demo(now);
      provider = ApprovalProvider(
        api: api,
        reviewerId: 1,
        reviewerName: 'Administrator',
      );
      await provider.load();
    });

    test('loads the expanded demo requests', () {
      expect(provider.pendingLeaveCount, 4);
      expect(provider.pendingCorrectionCount, 3);
      expect(provider.pendingCount, 7);
      expect(provider.leaveCount, 8);
      expect(provider.correctionCount, 5);
    });

    test('approving a leave updates its status', () async {
      final citra = provider.leaves.firstWhere(
        (leave) =>
            leave.employeeName == 'Citra Lestari' && leave.status.isPending,
      );

      expect(await provider.approveLeave(citra.id, note: 'Disetujui'), isTrue);
      expect(provider.leaveById(citra.id)!.status, RequestStatus.approved);
      expect(provider.pendingLeaveCount, 3);
    });

    test('rejecting requires a note', () async {
      final citra = provider.leaves.firstWhere(
        (leave) =>
            leave.employeeName == 'Citra Lestari' && leave.status.isPending,
      );

      expect(await provider.rejectLeave(citra.id, note: '  '), isFalse);
      expect(
        await provider.rejectLeave(citra.id, note: 'Saldo tidak cukup'),
        isTrue,
      );
      expect(provider.leaveById(citra.id)!.status, RequestStatus.rejected);
    });

    test('approving a correction updates its status', () async {
      final correction = provider.pendingCorrections.first;

      expect(await provider.approveCorrection(correction.id), isTrue);
      expect(
        provider.correctionById(correction.id)!.status,
        RequestStatus.approved,
      );
    });

    test('rejecting a correction requires a note', () async {
      final correction = provider.pendingCorrections.first;

      expect(await provider.rejectCorrection(correction.id, note: ''), isFalse);
      expect(
        await provider.rejectCorrection(correction.id, note: 'Bukti kurang'),
        isTrue,
      );
      expect(
        provider.correctionById(correction.id)!.status,
        RequestStatus.rejected,
      );
    });

    test('approved leaves are visible for the covered date', () {
      final rina = provider.leaves.firstWhere(
        (leave) => leave.employeeName == 'Rina Wulandari',
      );
      final citra = provider.leaves.firstWhere(
        (leave) => leave.employeeName == 'Citra Lestari',
      );

      expect(provider.leaveForId(rina.employeeId, now), isNotNull);
      expect(provider.leaveForId(citra.employeeId, now), isNull);
    });

    test('status filter narrows the visible lists', () {
      provider.selectStatus(RequestStatus.pending);
      expect(provider.visibleLeaves, hasLength(4));

      provider.selectStatus(RequestStatus.rejected);
      expect(provider.visibleLeaves.single.status, RequestStatus.rejected);

      provider.selectStatus(RequestStatus.cancelled);
      expect(provider.visibleLeaves.single.status, RequestStatus.cancelled);
    });
  });
}
