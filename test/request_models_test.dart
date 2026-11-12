import 'package:absensi/core/formatters.dart';
import 'package:absensi/data/models/attendance_correction.dart';
import 'package:absensi/data/models/correction_type.dart';
import 'package:absensi/data/models/leave_request.dart';
import 'package:absensi/data/models/request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('request status', () {
    test('maps api values and falls back to pending', () {
      expect(RequestStatus.fromApi('pending'), RequestStatus.pending);
      expect(RequestStatus.fromApi('approved'), RequestStatus.approved);
      expect(RequestStatus.fromApi('rejected'), RequestStatus.rejected);
      expect(RequestStatus.fromApi('cancelled'), RequestStatus.cancelled);
      expect(RequestStatus.fromApi('unknown'), RequestStatus.pending);
      expect(RequestStatus.fromApi(null), RequestStatus.pending);
    });

    test('exposes api value and decision state', () {
      expect(RequestStatus.approved.apiValue, 'approved');
      expect(RequestStatus.pending.isDecided, isFalse);
      expect(RequestStatus.cancelled.isDecided, isTrue);
    });
  });

  group('workingDaysBetween', () {
    test('counts weekdays inclusively', () {
      expect(
        workingDaysBetween(DateTime(2026, 11, 2), DateTime(2026, 11, 8)),
        5,
      );
    });

    test('returns zero for a weekend-only range', () {
      expect(
        workingDaysBetween(DateTime(2026, 11, 7), DateTime(2026, 11, 8)),
        0,
      );
    });

    test('returns zero when the range is reversed', () {
      expect(
        workingDaysBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 2)),
        0,
      );
    });
  });

  group('LeaveRequest json', () {
    test('parses flat laravel resource', () {
      final leave = LeaveRequest.fromJson({
        'id': 7,
        'code': 'CT-261104-0256',
        'employee_id': 3,
        'employee_name': 'Citra Lestari',
        'nip': '0256',
        'team': 'Tim Operasional',
        'leave_type_id': 1,
        'leave_type_name': 'Cuti tahunan',
        'start_date': '2026-11-13',
        'end_date': '2026-11-14',
        'requested_days': 2,
        'reason': 'Acara keluarga.',
        'status': 'approved',
        'reviewed_by': 1,
        'reviewed_at': '2026-11-05T09:00:00+07:00',
        'review_note': 'Disetujui.',
        'created_at': '2026-11-04T09:10:00+07:00',
        'balance_before': 8,
        'balance_after': 6,
      });

      expect(leave.id, 7);
      expect(leave.employeeId, 3);
      expect(leave.type, 'Cuti tahunan');
      expect(leave.workingDays, 2);
      expect(leave.status, RequestStatus.approved);
      expect(leave.reviewerId, 1);
      expect(leave.balanceRemaining, 8);
      expect(leave.balanceAfter, 6);
      expect(leave.startDate, DateTime(2026, 11, 13));
    });

    test('parses nested employee and leave type objects', () {
      final leave = LeaveRequest.fromJson({
        'id': 8,
        'employee': {
          'id': 4,
          'name': 'Dimas Prakoso',
          'nip': '0260',
          'department': 'Tim Operasional',
        },
        'leave_type': {'id': 2, 'name': 'Izin'},
        'start_date': '2026-11-09',
        'end_date': '2026-11-09',
        'requested_days': 1,
        'reason': 'Izin pribadi.',
        'status': 'pending',
        'created_at': '2026-11-08T09:10:00+07:00',
      });

      expect(leave.employeeId, 4);
      expect(leave.employeeName, 'Dimas Prakoso');
      expect(leave.team, 'Tim Operasional');
      expect(leave.leaveTypeId, 2);
      expect(leave.type, 'Izin');
      expect(leave.status, RequestStatus.pending);
    });
  });

  group('AttendanceCorrection json', () {
    test('allows a null proposed check-in', () {
      final correction = AttendanceCorrection.fromJson({
        'id': 4,
        'code': 'PA-261105-0248',
        'employee_id': 1,
        'employee_name': 'Aditya Pratama',
        'nip': '0248',
        'team': 'Tim Operasional',
        'date': '2026-11-05',
        'scheduled_start': '08:00',
        'scheduled_end': '17:00',
        'recorded_check_in_at': '2026-11-05T07:58:00+07:00',
        'recorded_check_out_at': null,
        'proposed_check_in_at': null,
        'proposed_check_out_at': '2026-11-05T17:05:00+07:00',
        'correction_type': 'check_out',
        'reason': 'Lupa absen pulang.',
        'status': 'pending',
        'created_at': '2026-11-05T09:10:00+07:00',
      });

      expect(correction.proposedCheckIn, isNull);
      expect(correction.proposedCheckOut, isNotNull);
      expect(correction.recordedCheckOut, isNull);
      expect(correction.correctionType, CorrectionType.checkOut);
      expect(correction.status, RequestStatus.pending);
    });
  });
}
