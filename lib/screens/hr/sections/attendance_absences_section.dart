import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/models/attendance_model.dart';
import '../cubit/hr_attendance_cubit.dart';
import 'package:intl/intl.dart';
import '../../../data/hr/hr_api.dart';

class AttendanceAbsencesSection extends StatelessWidget {
  const AttendanceAbsencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HrAttendanceCubit(),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
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

              return GridView.builder(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 350,
                  mainAxisExtent: 140,
                  crossAxisSpacing: AppDimens.spaceMd,
                  mainAxisSpacing: AppDimens.spaceMd,
                ),
                itemCount: state.employees.length,
                itemBuilder: (context, index) {
                  final emp = state.employees[index];
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
              return Row(
                children: [
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(color: AppColors.outline.withOpacity(0.1)),
      ),
      color: AppColors.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showMonthlyAttendanceDialog(context, emp),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      emp.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                emp.code,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.work_outline,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${emp.jobRole} - ${emp.branchName ?? 'المركز الرئيسي'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('سجل الحضور: ${widget.employee.fullName}')),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(
                () => _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                ),
              );
              _loadRecords();
            },
          ),
          Text(DateFormat('yyyy-MM').format(_currentMonth)),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(
                () => _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                ),
              );
              _loadRecords();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                  0,
                ).day,
                itemBuilder: (context, index) {
                  final date = DateTime(
                    _currentMonth.year,
                    _currentMonth.month,
                    index + 1,
                  );
                  final record = _records
                      .where((r) => r.recordDate.day == date.day)
                      .firstOrNull;

                  return ListTile(
                    leading: Text(DateFormat('yyyy-MM-dd').format(date)),
                    title: Text(record?.statusLabel ?? 'لم يسجل'),
                    subtitle: record?.notes != null
                        ? Text(record!.notes!)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editRecord(date, record),
                    ),
                  );
                },
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
}
