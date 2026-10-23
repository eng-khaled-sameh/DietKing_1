import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/data/hr/hr_api.dart';
import 'package:my_desktop_app/data/hr/models/leave_request_model.dart';

class HrLeaveRequestsState {
  final bool isLoading;
  final String? error;
  final List<LeaveRequest> requests;

  const HrLeaveRequestsState({
    this.isLoading = false,
    this.error,
    this.requests = const [],
  });

  HrLeaveRequestsState copyWith({
    bool? isLoading,
    String? error,
    List<LeaveRequest>? requests,
  }) {
    return HrLeaveRequestsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      requests: requests ?? this.requests,
    );
  }
}

class HrLeaveRequestsCubit extends Cubit<HrLeaveRequestsState> {
  final HrApi _api = HrApi();
  bool _loaded = false;

  HrLeaveRequestsCubit() : super(const HrLeaveRequestsState()) {
    fetchRequests();
  }

  Future<void> fetchRequests({bool force = false}) async {
    if (_loaded && !force) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final data = await _api.listLeaveRequests();
      _loaded = true;
      emit(state.copyWith(isLoading: false, requests: data));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> decideRequest({
    required String id,
    required String status,
    String? decisionType,
    String? notes,
    bool? isPaid,
  }) async {
    try {
      await _api.decideLeaveRequest(
        id: id,
        status: status,
        decisionType: decisionType,
        notes: notes,
        isPaid: isPaid,
      );
      _loaded = false;
      fetchRequests(force: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
