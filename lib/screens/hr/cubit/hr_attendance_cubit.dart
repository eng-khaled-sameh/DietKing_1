import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/data/hr/hr_api.dart';
import 'package:my_desktop_app/data/hr/models/attendance_model.dart';
import 'package:google_fonts/google_fonts.dart';

class HrAttendanceState {
  final bool isLoading;
  final String? error;
  final List<AttendanceEmployeeEntry> employees;
  final DateTime selectedDate;

  const HrAttendanceState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
    required this.selectedDate,
  });

  HrAttendanceState copyWith({
    bool? isLoading,
    String? error,
    List<AttendanceEmployeeEntry>? employees,
    DateTime? selectedDate,
  }) {
    return HrAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      employees: employees ?? this.employees,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class HrAttendanceCubit extends Cubit<HrAttendanceState> {
  final HrApi _api = HrApi();

  HrAttendanceCubit() : super(HrAttendanceState(selectedDate: DateTime.now())) {
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final data = await _api.getAllEmployeesAttendance(
        date: state.selectedDate,
      );
      emit(state.copyWith(isLoading: false, employees: data));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> changeDate(DateTime newDate) async {
    emit(state.copyWith(selectedDate: newDate));
    fetchEmployees();
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
      fetchEmployees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
