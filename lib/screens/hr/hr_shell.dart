import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/global_app_layout.dart';
import 'cubit/employees_cubit.dart';
import 'cubit/hr_attendance_cubit.dart';
import 'cubit/hr_cubit.dart';
import 'cubit/hr_deductions_bonuses_cubit.dart';
import 'cubit/hr_leave_requests_cubit.dart';
import 'cubit/hr_state.dart';
import 'models/hr_enums.dart';
import 'widgets/hr_sidebar.dart';
import 'sections/employees_section.dart';
import 'sections/leave_requests_section.dart';
import 'sections/attendance_absences_section.dart';
import 'sections/deductions_bonuses_section.dart';
import 'sections/monthly_report_section.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HrShell — الغلاف الرئيسي لـ HR
// كل الـ cubits الفرعية تُنشأ هنا مرة واحدة وتبقى طوال الجلسة
// البيانات تُجلب مرة واحدة فقط ولا تُعاد إلا عند Refresh أو تغيير فلتر
// ══════════════════════════════════════════════════════════════════════════════

class HrShell extends StatelessWidget {
  const HrShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HrCubit()),
        BlocProvider(create: (_) => EmployeesCubit()),
        BlocProvider(create: (_) => HrLeaveRequestsCubit()),
        BlocProvider(create: (_) => HrAttendanceCubit()),
        BlocProvider(create: (_) => HrDeductionsBonusesCubit()),
      ],
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: _HrShellContent(),
        ),
      ),
    );
  }
}

class _HrShellContent extends StatelessWidget {
  const _HrShellContent();

  @override
  Widget build(BuildContext context) {
    return GlobalAppLayout(
      onRefresh: () => _refreshAll(context),
      child: Row(
        children: [
          const HrSidebar(),
          Expanded(
            child: BlocBuilder<HrCubit, HrState>(
              builder: (context, state) {
                return switch (state.section) {
                  HrSection.employees          => const EmployeesSection(),
                  HrSection.leaveRequests      => const LeaveRequestsSection(),
                  HrSection.attendanceAbsences => const AttendanceAbsencesSection(),
                  HrSection.deductionsBonuses  => const DeductionsBonusesSection(),
                  HrSection.monthlyReport      => const MonthlyReportSection(),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  /// يُعيد جلب جميع بيانات HR من السيرفر (يُستدعى من زر Refresh)
  Future<void> _refreshAll(BuildContext context) async {
    context.read<EmployeesCubit>().fetchEmployees(refresh: true);
    context.read<HrLeaveRequestsCubit>().fetchRequests(force: true);
    context.read<HrDeductionsBonusesCubit>().fetchRequests(force: true);
    context.read<HrAttendanceCubit>().fetchEmployees(force: true);
    context.read<HrCubit>().refresh();
  }
}
