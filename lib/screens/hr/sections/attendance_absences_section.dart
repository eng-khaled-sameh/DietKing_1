import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../data/hr/models/attendance_model.dart';
import '../cubit/hr_attendance_cubit.dart';
import '../models/hr_enums.dart';
import 'package:intl/intl.dart';
import '../../../data/hr/hr_api.dart';
import '../../../data/hr/hr_date_utils.dart';

class AttendanceAbsencesSection extends StatefulWidget {
  const AttendanceAbsencesSection({super.key});

  @override
  State<AttendanceAbsencesSection> createState() =>
      _AttendanceAbsencesSectionState();
}

class _AttendanceAbsencesSectionState
    extends State<AttendanceAbsencesSection> {
  @override
  void initState() {
    super.initState();
    // الـ cubit موجود في HrShell — فقط نتأكد أن التاريخ هو اليوم عند فتح القسم
    context.read<HrAttendanceCubit>().refreshToToday();
    context.read<BranchesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return const _AttendanceView();
  }
}

class _AttendanceView extends StatefulWidget {
  const _AttendanceView();

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView> {
  final TextEditingController _searchController = TextEditingController();
  EmployeeJobRole? _selectedJobRole;
  String? _selectedBranchId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),

        // Filters (Search by name + Job role filter + Branch filter)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              // بحث بالاسم أو الكود
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'بحث باسم الموظف',
                    hintText: 'اكتب اسم الموظف أو الكود...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),

              // تصفية بالوظيفة
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<EmployeeJobRole?>(
                  decoration: const InputDecoration(
                    labelText: 'تصفية بالوظيفة',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  value: _selectedJobRole,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...EmployeeJobRole.values.map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedJobRole = v);
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),

              // تصفية بالفرع
              Expanded(
                flex: 2,
                child: BlocBuilder<BranchesCubit, BranchesState>(
                  builder: (context, branchesState) {
                    final branches = branchesState.branches;
                    return DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'تصفية بالفرع',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      value: _selectedBranchId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('الكل')),
                        ...branches.map(
                          (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedBranchId = v);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),

        Expanded(
          child: BlocBuilder<HrAttendanceCubit, HrAttendanceState>(
            builder: (context, state) {
              if (state.isLoading && state.employees.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null) {
                return Center(
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                );
              }
              if (state.employees.isEmpty) {
                return const Center(child: Text('لا يوجد موظفين مسجلين'));
              }

              // تطبيق التصفية والبحث
              final query = _searchController.text.trim().toLowerCase();
              final filtered = state.employees.where((emp) {
                if (query.isNotEmpty) {
                  final nameMatch = emp.fullName.toLowerCase().contains(query);
                  final codeMatch = emp.code.toLowerCase().contains(query);
                  if (!nameMatch && !codeMatch) return false;
                }
                if (_selectedJobRole != null) {
                  final roleCode = switch (_selectedJobRole!) {
                    EmployeeJobRole.kitchenWorker => 'kitchen_worker',
                    EmployeeJobRole.branchManager => 'branch_manager',
                    _ => _selectedJobRole!.name,
                  };
                  if (emp.jobRole != roleCode &&
                      emp.jobRole != _selectedJobRole!.name &&
                      emp.jobRole != _selectedJobRole!.label) {
                    return false;
                  }
                }
                if (_selectedBranchId != null) {
                  if (emp.branchId != _selectedBranchId) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد نتائج مطابقة لمعايير البحث والتصفية',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _selectedJobRole = null;
                            _selectedBranchId = null;
                          });
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('إعادة تعيين الفلاتر'),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 165,
                  crossAxisSpacing: AppDimens.spaceMd,
                  mainAxisSpacing: AppDimens.spaceMd,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final emp = filtered[index];
                  return _EmployeeAttendanceCard(emp: emp);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الحضور والغياب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          BlocBuilder<HrAttendanceCubit, HrAttendanceState>(
            builder: (context, state) {
              final today = DateTime.now();
              final isToday = state.selectedDate.year == today.year &&
                  state.selectedDate.month == today.month &&
                  state.selectedDate.day == today.day;
              return Row(
                children: [
                  // زر الانتقال ليوم اليوم مع ريفريش
                  Tooltip(
                    message: 'العودة لليوم',
                    child: IconButton(
                      icon: Icon(
                        Icons.today,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      onPressed: () =>
                          context.read<HrAttendanceCubit>().refreshToToday(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      context.read<HrAttendanceCubit>().changeDate(
                        state.selectedDate.subtract(const Duration(days: 1)),
                      );
                    },
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(state.selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.primary : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      context.read<HrAttendanceCubit>().changeDate(
                        state.selectedDate.add(const Duration(days: 1)),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}


class _EmployeeAttendanceCard extends StatelessWidget {
  final AttendanceEmployeeEntry emp;

  const _EmployeeAttendanceCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (emp.attendanceStatus) {
      case 'present':
        statusColor = AppColors.statusGreen;
        statusLabel = 'حاضر';
        break;
      case 'absent':
        statusColor = AppColors.error;
        statusLabel = 'غائب';
        break;
      case 'on_leave':
        statusColor = AppColors.secondary;
        statusLabel = 'إجازة';
        break;
      default:
        statusColor = AppColors.outline;
        statusLabel = 'لم يسجل';
    }

    final leaveStats = context.select<HrAttendanceCubit, EmployeeLeaveCount?>(
      (c) => c.state.leaveStats[emp.id],
    );
    final paidLeaves = leaveStats?.paidDays ?? 0;
    final unpaidLeaves = leaveStats?.unpaidDays ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.1)),
      ),
      color: AppColors.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showMonthlyAttendanceDialog(context, emp),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: اسم الموظف + شارة حالة الحضور
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      emp.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // الكود والوظيفة والفرع
              Row(
                children: [
                  Text(
                    emp.code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${emp.jobRole} - ${emp.branchName ?? 'المركز الرئيسي'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // شارات الإجازات: المدفوعة وغير المدفوعة
              Row(
                children: [
                  // إجازة مدفوعة
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: AppColors.statusGreen.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            size: 13,
                            color: AppColors.statusGreen,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'مدفوعة: $paidLeaves',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // إجازة غير مدفوعة (بخصم)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: Colors.amber.shade700.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 13,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'غير مدفوعة: $unpaidLeaves',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthlyAttendanceDialog(
    BuildContext context,
    AttendanceEmployeeEntry employee,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _MonthlyAttendanceDialog(
          employee: employee,
          hrCubit: context.read<HrAttendanceCubit>(),
        );
      },
    );
  }
}

class _MonthlyAttendanceDialog extends StatefulWidget {
  final AttendanceEmployeeEntry employee;
  final HrAttendanceCubit hrCubit;

  const _MonthlyAttendanceDialog({
    required this.employee,
    required this.hrCubit,
  });

  @override
  State<_MonthlyAttendanceDialog> createState() =>
      _MonthlyAttendanceDialogState();
}

class _MonthlyAttendanceDialogState extends State<_MonthlyAttendanceDialog> {
  final HrApi _api = HrApi();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _api.getMonthlyAttendance(
        employeeId: widget.employee.id,
        year: _currentMonth.year,
        month: _currentMonth.month,
      );
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editRecord(
    DateTime date,
    AttendanceRecord? existingRecord,
  ) async {
    String? selectedStatus = existingRecord?.status;
    String notes = existingRecord?.notes ?? '';

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'تعديل الحضور - ${DateFormat('yyyy-MM-dd').format(date)}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'present', child: Text('حاضر')),
                      DropdownMenuItem(value: 'absent', child: Text('غائب')),
                      DropdownMenuItem(value: 'on_leave', child: Text('إجازة')),
                    ],
                    onChanged: (v) => setState(() => selectedStatus = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    onChanged: (v) => notes = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selectedStatus == null
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedStatus != null) {
      await _api.submitAttendance(
        employeeId: widget.employee.id,
        recordDate: date,
        status: selectedStatus!,
        context: 'hr',
        notes: notes.isNotEmpty ? notes : null,
      );
      _loadRecords();
      widget.hrCubit.fetchEmployees(); // Refresh outer list
    }
  }

  @override
  Widget build(BuildContext context) {
    final retentionEarliest = HrDateUtils.getRetentionEarliestDate();
    final latestDate = HrDateUtils.getRetentionLatestDate();

    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    final canGoPrev = !prevMonth.isBefore(DateTime(retentionEarliest.year, retentionEarliest.month, 1));
    final canGoNext = !nextMonth.isAfter(DateTime(latestDate.year, latestDate.month, 1));

    // حدود صلاحية الموظف
    final empStart = widget.employee.hireDate ?? widget.employee.createdAt ?? DateTime(2020);
    final empStartDay = DateTime(empStart.year, empStart.month, empStart.day);
    final empEndDay = (widget.employee.status != 'active' && widget.employee.statusChangedAt != null)
        ? DateTime(widget.employee.statusChangedAt!.year, widget.employee.statusChangedAt!.month, widget.employee.statusChangedAt!.day)
        : latestDate;

    // استخراج الأيام الصالحة للعرض فقط
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final validDays = <DateTime>[];
    for (int i = 1; i <= daysInMonth; i++) {
      final d = DateTime(_currentMonth.year, _currentMonth.month, i);
      // إخفاء أي يوم قبل تاريخ تعيين/إنشاء الموظف أو بعد تاريخ وقفه/فصله أو خارج نافذة الاحتفاظ
      if (d.isBefore(empStartDay) || d.isAfter(empEndDay) || d.isBefore(retentionEarliest)) {
        continue;
      }
      validDays.add(d);
    }

    final isEmployeeActive = widget.employee.status == 'active';

    final presentCount = _records.where((r) => r.status == 'present').length;
    final absentCount = _records.where((r) => r.status == 'absent').length;
    final paidLeaveCount =
        _records.where((r) => r.status == 'on_leave' && r.isPaidLeave).length;
    final unpaidLeaveCount =
        _records.where((r) => r.status == 'on_leave' && !r.isPaidLeave).length;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سجل الحضور: ${widget.employee.fullName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'الحالة: ${widget.employee.status == 'active' ? 'نشط' : 'غير نشط (${widget.employee.status})'} | البداية: ${DateFormat('yyyy-MM-dd').format(empStartDay)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isEmployeeActive ? AppColors.statusGreen : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: canGoPrev ? 'الشهر السابق' : 'خارج نطاق البيانات المحفوظة',
            onPressed: canGoPrev
                ? () {
                    setState(() => _currentMonth = prevMonth);
                    _loadRecords();
                  }
                : null,
          ),
          Text(
            DateFormat('yyyy-MM').format(_currentMonth),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: canGoNext ? 'الشهر التالي' : 'لا يمكن اختيار تاريخ مستقبلي',
            onPressed: canGoNext
                ? () {
                    setState(() => _currentMonth = nextMonth);
                    _loadRecords();
                  }
                : null,
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 440,
        child: Column(
          children: [
            // ── مفتاح الألوان (Legend) مع أعداد الأيام ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legendItem('حاضر ($presentCount)', AppColors.statusGreen),
                  _legendItem('إجازة مدفوعة ($paidLeaveCount)', AppColors.statusGreen),
                  _legendItem('إجازة بخصم ($unpaidLeaveCount)', Colors.orange),
                  _legendItem('غائب ($absentCount)', AppColors.error),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : validDays.isEmpty
                      ? const Center(
                          child: Text('لا توجد أيام مسجلة للموظف في هذا الشهر ضمن نطاق تعيينه وحفظ البيانات'),
                        )
                      : ListView.builder(
                          itemCount: validDays.length,
                          itemBuilder: (context, index) {
                            final date = validDays[index];
                            final record = _records
                                .where((r) => r.recordDate.day == date.day && r.recordDate.month == date.month)
                                .firstOrNull;

                            final isFuture = date.isAfter(DateTime.now());
                            final isOnLeave = record?.status == 'on_leave';
                            final canEdit = isEmployeeActive && !isFuture && !isOnLeave;

                            Color statusColor = AppColors.onSurfaceVariant;
                            if (record?.status == 'present') {
                              statusColor = AppColors.statusGreen;
                            } else if (record?.status == 'absent') {
                              statusColor = AppColors.error;
                            } else if (record?.status == 'on_leave') {
                              statusColor = (record?.isPaidLeave ?? true)
                                  ? AppColors.statusGreen
                                  : Colors.orange;
                            }

                            return ListTile(
                              leading: Text(DateFormat('yyyy-MM-dd (EEEE)', 'ar').format(date)),
                              title: Row(
                                children: [
                                  Text(
                                    record?.statusLabel ?? 'لم يسجل',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (record?.status == 'on_leave') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        (record?.isPaidLeave ?? true) ? 'مدفوعة' : 'بخصم',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: record?.notes != null ? Text(record!.notes!) : null,
                              trailing: canEdit
                                  ? IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      tooltip: 'تعديل الحضور',
                                      onPressed: () => _editRecord(date, record),
                                    )
                                  : Tooltip(
                                      message: !isEmployeeActive
                                          ? 'لا يمكن تسجيل حضور لموظف غير نشط'
                                          : (isOnLeave ? 'الموظف في إجازة معتمدة' : 'تاريخ غير قابل للتعديل'),
                                      child: Icon(
                                        Icons.lock_outline,
                                        size: 18,
                                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

