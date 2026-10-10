class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime recordDate;
  final String status; // 'present' | 'absent' | 'on_leave'
  final String? recordedFrom;
  final String? notes;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.recordDate,
    required this.status,
    this.recordedFrom,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id: j['id'] as String,
    employeeId: j['employee_id'] as String,
    recordDate: DateTime.parse(j['date'] as String),
    status: j['status'] as String,
    recordedFrom: j['recorded_from'] as String?,
    notes: j['notes'] as String?,
  );

  String get statusLabel => switch (status) {
    'present' => 'حاضر',
    'absent' => 'غائب',
    'on_leave' => 'في إجازة',
    _ => 'غير محدد',
  };
}

class AttendanceEmployeeEntry {
  final String id;
  final String code;
  final String fullName;
  final String jobRole;
  final String? branchId;
  final String? branchName;
  final String? attendanceStatus; // null = لم يسجل بعد
  final String? attendanceId;

  const AttendanceEmployeeEntry({
    required this.id,
    required this.code,
    required this.fullName,
    required this.jobRole,
    this.branchId,
    this.branchName,
    this.attendanceStatus,
    this.attendanceId,
  });

  factory AttendanceEmployeeEntry.fromJson(Map<String, dynamic> j) =>
      AttendanceEmployeeEntry(
        id: j['id'] as String,
        code: j['code'] as String,
        fullName: j['full_name'] as String,
        jobRole: j['job_role'] as String,
        branchId: j['branch_id'] as String?,
        branchName: j['branch_name'] as String?,
        attendanceStatus: j['attendance_status'] as String?,
        attendanceId: j['attendance_id'] as String?,
      );
}

class EmployeeSimple {
  final String id;
  final String code;
  final String fullName;
  final String jobRole;
  final String? branchId;
  final String? branchName;

  const EmployeeSimple({
    required this.id,
    required this.code,
    required this.fullName,
    required this.jobRole,
    this.branchId,
    this.branchName,
  });

  factory EmployeeSimple.fromJson(Map<String, dynamic> j) => EmployeeSimple(
    id: j['id'] as String,
    code: j['code'] as String,
    fullName: j['full_name'] as String,
    jobRole: j['job_role'] as String,
    branchId: j['branch_id'] as String?,
    branchName: j['branch_name'] as String?,
  );

  String get jobRoleLabel => switch (jobRole) {
    'cashier' => 'كاشير',
    'worker' => 'عامل',
    'branch_manager' => 'مدير فرع',
    'driver' => 'سائق',
    'storekeeper' => 'أمين مخزن',
    'chef' => 'شيف',
    'kitchen_worker' => 'عامل مطبخ',
    'accountant' => 'محاسب',
    'hr' => 'موارد بشرية',
    _ => jobRole,
  };
}
