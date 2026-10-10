import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/hr/hr_api.dart';
import '../../../../../data/hr/models/attendance_model.dart';
import 'package:intl/intl.dart';

class AdminAttendanceSection extends StatefulWidget {
  final String branchId;
  final String contextType; // 'cashier' or 'inventory'

  const AdminAttendanceSection({
    super.key,
    required this.branchId,
    this.contextType = 'cashier',
  });

  @override
  State<AdminAttendanceSection> createState() => _AdminAttendanceSectionState();
}

class _AdminAttendanceSectionState extends State<AdminAttendanceSection> {
  final HrApi _api = HrApi();
  bool _isLoading = true;
  String _error = '';

  List<EmployeeSimple> _branchEmployees = [];
  List<EmployeeSimple> _drivers = [];
  Map<String, dynamic> _todayAttendance = {};

  bool _showDrivers = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final futures = await Future.wait([
        _api.getBranchEmployees(
          branchId: widget.branchId,
          context: widget.contextType,
        ),
        _api.getDrivers(),
      ]);

      _branchEmployees = List<EmployeeSimple>.from(futures[0] as List);
      _drivers = List<EmployeeSimple>.from(futures[1] as List);

      final allIds = [
        ..._branchEmployees,
        ..._drivers,
      ].map((e) => e.id).toList();
      if (allIds.isNotEmpty) {
        _todayAttendance = await _api.getTodayAttendance(employeeIds: allIds);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _submitAttendance(String empId, String status) async {
    try {
      await _api.submitAttendance(
        employeeId: empId,
        recordDate: DateTime.now(),
        status: status,
        context: widget.contextType,
      );

      // Update local state
      setState(() {
        _todayAttendance[empId] = {
          'status': status,
          'recorded_from': widget.contextType,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل ال${status == 'present' ? 'حضور' : 'غياب'} بنجاح',
          ),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty)
      return Center(
        child: Text(_error, style: const TextStyle(color: AppColors.error)),
      );

    final currentList = _showDrivers ? _drivers : _branchEmployees;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تسجيل حضور وغياب (${DateFormat('yyyy-MM-dd').format(DateTime.now())})',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('موظفي الفرع')),
                  ButtonSegment(value: true, label: Text('السائقين')),
                ],
                selected: {_showDrivers},
                onSelectionChanged: (set) =>
                    setState(() => _showDrivers = set.first),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),

          if (currentList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('لا يوجد موظفين مسجلين في هذا القسم'),
              ),
            ),

          ...currentList.map((emp) {
            final att = _todayAttendance[emp.id];
            final hasRecorded = att != null;
            final recordedStatus = hasRecorded ? att['status'] : null;

            return Card(
              margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              color: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                side: BorderSide(color: AppColors.outline.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.fullName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            emp.jobRoleLabel,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                    if (hasRecorded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (recordedStatus == 'present'
                                      ? AppColors.statusGreen
                                      : AppColors.error)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: recordedStatus == 'present'
                                ? AppColors.statusGreen
                                : AppColors.error,
                          ),
                        ),
                        child: Text(
                          recordedStatus == 'present'
                              ? 'حاضر'
                              : (recordedStatus == 'on_leave'
                                    ? 'إجازة'
                                    : 'غائب'),
                          style: TextStyle(
                            color: recordedStatus == 'present'
                                ? AppColors.statusGreen
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _submitAttendance(emp.id, 'absent'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text('غياب'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _submitAttendance(emp.id, 'present'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('حضور'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
