import '../models/hr_enums.dart';

class HrState {
  final HrSection section;

  const HrState({this.section = HrSection.employees});

  HrState copyWith({HrSection? section}) {
    return HrState(section: section ?? this.section);
  }
}
