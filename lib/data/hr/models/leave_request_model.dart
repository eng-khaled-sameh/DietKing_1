class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String jobRole;
  final String? branchName;
  final String requestedFrom;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // pending | approved | rejected
  final String? decisionType; // with_deduction | without_deduction
  final String? decisionNotes;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.jobRole,
    this.branchName,
    required this.requestedFrom,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.decisionType,
    this.decisionNotes,
    required this.createdAt,
  });

  int get daysCount => endDate.difference(startDate).inDays + 1;

  String get statusLabel => switch (status) {
    'pending' => 'قيد المراجعة',
    'approved' => 'تمت الموافقة',
    'rejected' => 'مرفوضة',
    _ => status,
  };

  String get decisionTypeLabel => switch (decisionType) {
    'with_deduction' => 'بخصم',
    'without_deduction' => 'بدون خصم',
    _ => '-',
  };

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
    id: j['id'] as String,
    employeeId: j['employee_id'] as String,
    employeeName: j['employee_name'] as String? ?? '',
    employeeCode: j['employee_code'] as String? ?? '',
    jobRole: j['job_role'] as String? ?? '',
    branchName: j['branch_name'] as String?,
    requestedFrom: j['requested_from'] as String? ?? '',
    startDate: DateTime.parse(j['start_date'] as String),
    endDate: DateTime.parse(j['end_date'] as String),
    reason: j['reason'] as String,
    status: j['status'] as String,
    decisionType: j['decision_type'] as String?,
    decisionNotes: j['decision_notes'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}
