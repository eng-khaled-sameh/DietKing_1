import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/data/hr/hr_api.dart';
import 'package:my_desktop_app/data/hr/models/attendance_model.dart';

class EmployeeLeaveCount {
  final int paidDays;
  final int unpaidDays;

  const EmployeeLeaveCount({
    this.paidDays = 0,
    this.unpaidDays = 0,
  });
}

class HrAttendanceState {
  final bool isLoading;
  final String? error;
  final List<AttendanceEmployeeEntry> employees;
  final DateTime selectedDate;
  final Map<String, EmployeeLeaveCount> leaveStats;

  const HrAttendanceState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
    required this.selectedDate,
    this.leaveStats = const {},
  });

  HrAttendanceState copyWith({
    bool? isLoading,
    String? error,
    List<AttendanceEmployeeEntry>? employees,
    DateTime? selectedDate,
    Map<String, EmployeeLeaveCount>? leaveStats,
  }) {
    return HrAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      employees: employees ?? this.employees,
      selectedDate: selectedDate ?? this.selectedDate,
      leaveStats: leaveStats ?? this.leaveStats,
    );
  }
}

class HrAttendanceCubit extends Cubit<HrAttendanceState> {
  final HrApi _api = HrApi();
  /// التاريخ الذي تم جلب بياناته آخر مرة
  DateTime? _loadedDate;
  /// الشهر الذي تم جلب إحصائيات إجازاته آخر مرة
  String? _loadedLeaveMonth;

  HrAttendanceCubit()
      // دائماً ابدأ بتاريخ اليوم الفعلي عند إنشاء الـ cubit
      : super(HrAttendanceState(selectedDate: _today())) {
    fetchEmployees();
  }

  /// يوم اليوم بدون وقت (لضمان المقارنة الصحيحة)
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> fetchEmployees({bool force = false}) async {
    final monthKey = '${state.selectedDate.year}-${state.selectedDate.month}';
    final bool dateChanged = _loadedDate != state.selectedDate;
    final bool monthChanged = _loadedLeaveMonth != monthKey;

    // لا نُعيد الجلب إذا لم تتغير البيانات والشهر موجود (توفير استهلاك البيانات)
    if (!force && !dateChanged && state.employees.isNotEmpty && !monthChanged) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      final dataFuture = _api.getAllEmployeesAttendance(
        date: state.selectedDate,
      );

      // جلب إحصائيات الإجازات المدفوعة وغير المدفوعة للشهر المحدد
      Future<Map<String, EmployeeLeaveCount>?> fetchLeaves() async {
        if (!force && !monthChanged && state.leaveStats.isNotEmpty) {
          return state.leaveStats;
        }
        try {
          final startOfMonth = DateTime(state.selectedDate.year, state.selectedDate.month, 1);
          final endOfMonth = DateTime(state.selectedDate.year, state.selectedDate.month + 1, 0);
          final comp = await _api.getComprehensiveReport(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );
          _loadedLeaveMonth = monthKey;
          return {
            for (final entry in comp)
              entry.employeeId: EmployeeLeaveCount(
                paidDays: entry.paidLeaveDays,
                unpaidDays: entry.leaveWithDeductionDays,
              ),
          };
        } catch (_) {
          return state.leaveStats;
        }
      }

      final results = await Future.wait([
        dataFuture,
        fetchLeaves(),
      ]);

      final employees = results[0] as List<AttendanceEmployeeEntry>;
      final leaveStats =
          results[1] as Map<String, EmployeeLeaveCount>? ?? state.leaveStats;

      _loadedDate = state.selectedDate;
      emit(state.copyWith(
        isLoading: false,
        employees: employees,
        leaveStats: leaveStats,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// الانتقال ليوم آخر وجلب بياناته
  Future<void> changeDate(DateTime newDate) async {
    emit(state.copyWith(selectedDate: newDate));
    fetchEmployees(); // تاريخ جديد → جلب جديد دائماً
  }

  /// إعادة الضبط ليوم اليوم (يُستدعى عند العودة للصفحة)
  Future<void> refreshToToday() async {
    final today = _today();
    if (state.selectedDate != today) {
      emit(state.copyWith(selectedDate: today));
      _loadedDate = null; // تاريخ تغيّر → أعد الجلب
    }
    await fetchEmployees();
  }

  Future<void> updateAttendance(
    String employeeId,
    String status,
    String? notes,
  ) async {
    try {
      await _api.submitAttendance(
        employeeId: employeeId,
        recordDate: state.selectedDate,
        status: status,
        context: 'hr',
        notes: notes,
      );
      _loadedDate = null; // بيانات تغيّرت → أعد الجلب
      _loadedLeaveMonth = null;
      fetchEmployees(force: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
