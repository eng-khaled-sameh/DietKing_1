import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/global_app_layout.dart';
import 'cubit/hr_cubit.dart';
import 'cubit/hr_state.dart';
import 'models/hr_enums.dart';
import 'widgets/hr_sidebar.dart';
import 'sections/employees_section.dart';
import 'sections/leave_requests_section.dart';
import 'sections/attendance_absences_section.dart';
import 'sections/deductions_bonuses_section.dart';
import 'sections/monthly_report_section.dart';

class HrShell extends StatelessWidget {
  const HrShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HrCubit(),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(
            0xFF1E1E1E,
          ), // Match app background (assuming it's dark theme)
          body: GlobalAppLayout(child: _HrShellContent()),
        ),
      ),
    );
  }
}

class _HrShellContent extends StatelessWidget {
  const _HrShellContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const HrSidebar(),
        Expanded(
          child: BlocBuilder<HrCubit, HrState>(
            buildWhen: (previous, current) =>
                previous.section != current.section,
            builder: (context, state) {
              switch (state.section) {
                case HrSection.employees:
                  return const EmployeesSection();
                case HrSection.leaveRequests:
                  return const LeaveRequestsSection();
                case HrSection.attendanceAbsences:
                  return const AttendanceAbsencesSection();
                case HrSection.deductionsBonuses:
                  return const DeductionsBonusesSection();
                case HrSection.monthlyReport:
                  return const MonthlyReportSection();
              }
            },
          ),
        ),
      ],
    );
  }
}
