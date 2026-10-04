import 'package:equatable/equatable.dart';

import '../core/app_modules.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.role,
    required this.isActive,
    required this.fullName,
    this.branchId,
  });

  final String userId;
  final String email;
  final AppRole role;
  final bool isActive;
  final String fullName;
  final String? branchId;

  @override
  List<Object?> get props => [userId, email, role, isActive, fullName, branchId];
}
