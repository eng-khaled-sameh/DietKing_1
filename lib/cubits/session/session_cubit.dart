import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_modules.dart';
import '../../models/login_branch.dart';

class SessionState extends Equatable {
  final bool isActive;
  final String userId;
  final String email;
  final String cashierName;
  final String? branchId;
  final String branchName;
  final String branchCode;
  final String shift;
  final String sessionId;
  final DateTime? startedAt;
  final AppRole? role;
  final AppModule? module;
  final double openingCash;

  const SessionState({
    this.isActive = false,
    this.userId = '',
    this.email = '',
    this.cashierName = '',
    this.branchId,
    this.branchName = '',
    this.branchCode = '',
    this.shift = '',
    this.sessionId = '',
    this.startedAt,
    this.role,
    this.module,
    this.openingCash = 0,
  });

  @override
  List<Object?> get props => [
        isActive, userId, email, cashierName, branchId, branchName, branchCode,
        shift, sessionId, startedAt, role, module, openingCash,
      ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  final Map<AppModule, _ModuleSession> _moduleSessions = {};

  bool hasModuleSession(AppModule module) => _moduleSessions.containsKey(module);

  void resume({
    required String userId,
    required String email,
    required String fullName,
    required AppRole role,
    required AppModule module,
  }) {
    final existing = _moduleSessions[module];
    if (existing == null) return;
    emit(SessionState(
      isActive: true,
      userId: userId,
      email: email,
      cashierName: fullName.isEmpty ? email.split('@').first : fullName,
      branchId: existing.branch?.id,
      branchName: existing.branch?.name ?? 'إدارة',
      branchCode: existing.branch?.code ?? '',
      shift: existing.shift,
      sessionId: existing.sessionId,
      startedAt: existing.startedAt,
      role: role,
      module: module,
      openingCash: existing.openingCash,
    ));
  }

  void start({
    required String userId,
    required String email,
    required String fullName,
    required AppRole role,
    required AppModule module,
    required String shift,
    LoginBranch? branch,
    double openingCash = 0,
  }) {
    if (hasModuleSession(module)) {
      resume(
        userId: userId,
        email: email,
        fullName: fullName,
        role: role,
        module: module,
      );
      return;
    }
    final moduleSession = _ModuleSession(
      shift: shift,
      branch: branch,
      openingCash: openingCash,
      sessionId: _generateUuidV4(),
      startedAt: DateTime.now(),
    );
    _moduleSessions[module] = moduleSession;
    emit(SessionState(
      isActive: true,
      userId: userId,
      email: email,
      cashierName: fullName.isEmpty ? email.split('@').first : fullName,
      branchId: moduleSession.branch?.id,
      branchName: moduleSession.branch?.name ?? 'إدارة',
      branchCode: moduleSession.branch?.code ?? '',
      shift: moduleSession.shift,
      sessionId: moduleSession.sessionId,
      startedAt: moduleSession.startedAt,
      role: role,
      module: module,
      openingCash: moduleSession.openingCash,
    ));
  }

  void end() {
    _moduleSessions.clear();
    emit(const SessionState());
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}

class _ModuleSession {
  const _ModuleSession({
    required this.shift,
    required this.branch,
    required this.openingCash,
    required this.sessionId,
    required this.startedAt,
  });

  final String shift;
  final LoginBranch? branch;
  final double openingCash;
  final String sessionId;
  final DateTime startedAt;
}
