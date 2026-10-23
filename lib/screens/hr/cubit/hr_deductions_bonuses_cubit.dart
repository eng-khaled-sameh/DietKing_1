import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/data/hr/hr_api.dart';
import 'package:my_desktop_app/data/hr/models/deduction_bonus_model.dart';

class HrDeductionsBonusesState {
  final bool isLoading;
  final String? error;
  final List<DeductionBonusRequest> requests;

  const HrDeductionsBonusesState({
    this.isLoading = false,
    this.error,
    this.requests = const [],
  });

  HrDeductionsBonusesState copyWith({
    bool? isLoading,
    String? error,
    List<DeductionBonusRequest>? requests,
  }) {
    return HrDeductionsBonusesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      requests: requests ?? this.requests,
    );
  }
}

class HrDeductionsBonusesCubit extends Cubit<HrDeductionsBonusesState> {
  final HrApi _api = HrApi();
  bool _loaded = false;

  HrDeductionsBonusesCubit() : super(const HrDeductionsBonusesState()) {
    fetchRequests();
  }

  Future<void> fetchRequests({bool force = false}) async {
    if (_loaded && !force) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final data = await _api.listDeductionBonuses();
      _loaded = true;
      emit(state.copyWith(isLoading: false, requests: data));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> decideRequest({
    required String id,
    required String status,
    double? finalCashAmount,
    String? notes,
  }) async {
    try {
      await _api.decideDeductionBonus(
        id: id,
        status: status,
        finalCashAmount: finalCashAmount,
        notes: notes,
      );
      _loaded = false;
      fetchRequests(force: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
