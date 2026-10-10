import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/hr_enums.dart';
import 'hr_state.dart';

class HrCubit extends Cubit<HrState> {
  HrCubit() : super(const HrState());

  void setSection(HrSection section) {
    emit(state.copyWith(section: section));
  }
}
