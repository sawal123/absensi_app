import 'package:absensi/data/api/absensi_api.dart';
import 'package:absensi/data/models/correction_type.dart';
import 'package:absensi/data/models/request_status.dart';
import 'package:absensi/providers/my_requests_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_absensi_api.dart';

void main() {
  final now = DateTime(2026, 11, 7, 10, 15);

  late FakeAbsensiApi api;
  late MyRequestsProvider provider;

  setUp(() async {
    api = FakeAbsensiApi.demo(now);
    provider = MyRequestsProvider(
      api: api,
      employeeId: api.userIdByEmail['citra@absensi.com']!,
      year: now.year,
    );
    await provider.load();
  });

  test('loads types, balances, and personal requests', () {
    expect(provider.leaveTypes, hasLength(3));
    expect(provider.leaveBalances, hasLength(3));
    expect(provider.annualLeaveBalance!.remainingDays, 10);
    expect(provider.leaveRequests, hasLength(1));
    expect(provider.corrections, hasLength(1));
  });

  test('submitting a leave adds a pending request', () async {
    final ok = await provider.submitLeave(
      LeaveRequestDraft(
        employeeId: provider.employeeId,
        leaveTypeId: 1,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 20),
        reason: 'Acara keluarga besar akhir pekan.',
      ),
    );

    expect(ok, isTrue);
    expect(provider.leaveRequests, hasLength(2));
    expect(
      provider.leaveRequests.where((leave) => leave.status.isPending),
      hasLength(2),
    );
  });

  test('cancelling a pending leave changes its status', () async {
    final leave = provider.leaveRequests.first;

    expect(await provider.cancelLeave(leave.id), isTrue);
    expect(provider.leaveById(leave.id)!.status, RequestStatus.cancelled);
  });

  test('submitting a correction adds a pending request', () async {
    final ok = await provider.submitCorrection(
      CorrectionDraft(
        employeeId: provider.employeeId,
        date: DateTime(2026, 11, 6),
        correctionType: CorrectionType.checkOut,
        proposedCheckOut: DateTime(2026, 11, 6, 17, 10),
        reason: 'Lupa absen pulang setelah lembur.',
      ),
    );

    expect(ok, isTrue);
    expect(provider.corrections, hasLength(2));
    expect(
      provider.corrections.where((item) => item.status.isPending),
      hasLength(2),
    );
  });

  test('cancelling a pending correction changes its status', () async {
    final correction = provider.corrections.first;

    expect(await provider.cancelCorrection(correction.id), isTrue);
    expect(
      provider.correctionById(correction.id)!.status,
      RequestStatus.cancelled,
    );
  });

  test('balanceFor returns the matching leave type balance', () {
    expect(provider.balanceFor(2)!.remainingDays, 3);
    expect(provider.balanceFor(3)!.remainingDays, 12);
  });
}
