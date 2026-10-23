import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/hr/hr_api.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../models/hr_enums.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final HrApi _api = HrApi();
  static const int _limit = 50;

  /// تتبع التحميل الأول في الجلسة — لا نعيد الجلب إلا عند Refresh أو تغيير فلتر
  bool _loaded = false;

  EmployeesCubit() : super(const EmployeesState()) {
    fetchEmployees();
  }

  int _requestId = 0;

  Future<void> fetchEmployees({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (!refresh && state.hasReachedMax) return;
    // منع إعادة جلب الصفحة الأولى عند التنقل بين أقسام HR (الكاش)
    // لكن نسمح بـ pagination (الصفحات التالية) دائماً
    if (!refresh && _loaded && state.employees.isNotEmpty && state.offset == 0) return;

    final currentRequestId = ++_requestId;
    final currentOffset = refresh ? 0 : state.offset;

    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        offset: currentOffset,
        employees: refresh ? [] : state.employees,
        hasReachedMax: refresh ? false : state.hasReachedMax,
      ),
    );

    try {
      final res = await _api.listEmployees(
        search: state.search,
        jobRole: _jobRoleToString(state.jobRole),
        status: state.status?.name,
        branchId: state.branchId,
        noBranch: state.noBranch,
        limit: _limit,
        offset: currentOffset,
      );

      // إذا انطلق طلب أحدث أثناء انتظار هذا الرد، نتجاهل النتيجة القديمة
      if (currentRequestId != _requestId) return;

      final items = (res['items'] as List)
          .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final counts = Map<String, int>.from(res['counts']);
      final total = res['total'] as int;

      _loaded = true;
      final newEmployees = refresh ? items : [...state.employees, ...items];
      final bool reachedMax = items.isEmpty ||
          items.length < _limit ||
          (total > 0 && newEmployees.length >= total);

      emit(
        state.copyWith(
          isLoading: false,
          employees: newEmployees,
          offset: currentOffset + items.length,
          hasReachedMax: reachedMax,
          totalCount: total,
          counts: counts,
        ),
      );
    } catch (e) {
      if (currentRequestId != _requestId) return;
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
        hasReachedMax: true,
      ));
    }
  }

  String? _jobRoleToString(EmployeeJobRole? role) {
    if (role == null) return null;
    if (role == EmployeeJobRole.kitchenWorker) return 'kitchen_worker';
    if (role == EmployeeJobRole.branchManager) return 'branch_manager';
    return role.name;
  }

  void updateFilters({
    String? search,
    EmployeeJobRole? jobRole,
    EmployeeStatus? status,
    String? branchId,
    bool? noBranch,
    bool clearSearch = false,
    bool clearJobRole = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) {
    _loaded = false; // إعادة ضبط الكاش عند تغيير الفلتر
    emit(
      state.copyWith(
        search: search,
        jobRole: jobRole,
        status: status,
        branchId: branchId,
        noBranch: noBranch,
        offset: 0,
        hasReachedMax: false,
        clearSearch: clearSearch,
        clearJobRole: clearJobRole,
        clearStatus: clearStatus,
        clearBranch: clearBranch,
      ),
    );
    fetchEmployees(refresh: true);
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    // We don't emit loading state here to keep the list intact in the background.
    // The form dialog will handle its own loading state.
    await _api.createEmployee(data);
    // Refresh the list after successful creation
    await fetchEmployees(refresh: true);
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    final updatedEmp = await _api.updateEmployee(id, data);
    final updatedList = state.employees
        .map((e) => e.id == id ? updatedEmp : e)
        .toList();
    emit(state.copyWith(employees: updatedList));
  }

  Future<void> updateEmployeeStatus({
    required String id,
    required EmployeeStatus status,
    String? reason,
    String? suspensionEnd,
  }) async {
    try {
      final updatedEmp = await _api.updateEmployeeStatus(
        id: id,
        status: status.name,
        reason: reason,
        suspensionEnd: suspensionEnd,
      );

      // Update in local state
      final updatedList = state.employees
          .map((e) => e.id == id ? updatedEmp : e)
          .toList();
      emit(state.copyWith(employees: updatedList));
    } catch (e) {
      // For simplicity, we could re-throw or handle error
      rethrow;
    }
  }
}
