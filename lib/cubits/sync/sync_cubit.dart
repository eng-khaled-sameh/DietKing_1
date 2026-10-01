import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/core/local_db.dart';
import 'package:my_desktop_app/core/sync_service.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class SyncState extends Equatable {
  final int pendingCount;
  final int failedCount;
  final bool isSyncing;

  const SyncState({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
  });

  SyncState copyWith({int? pendingCount, int? failedCount, bool? isSyncing}) =>
      SyncState(
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
        isSyncing: isSyncing ?? this.isSyncing,
      );

  @override
  List<Object?> get props => [pendingCount, failedCount, isSyncing];
}

// ── Cubit ──────────────────────────────────────────────────────────────────────

/// SyncCubit — على مستوى التطبيق
/// يدير SyncService + Timer.periodic كل 30 ثانية
class SyncCubit extends Cubit<SyncState> {
  late final SyncService _service;
  Timer? _timer;
  String? _userId;
  final LocalRecordsRepository _repo = LocalRecordsRepository();

  SyncCubit() : super(const SyncState()) {
    _service = SyncService(onCountsChanged: _handleCountsChanged);
  }

  /// يُستدعى بعد تسجيل الدخول لتعيين المستخدم الحالي وبدء المزامنة
  Future<void> onLogin(String userId) async {
    _userId = userId;
    await _refreshCounts();
    unawaited(triggerSync());
    _startTimer();
  }

  /// يُستدعى بعد تسجيل الخروج لإيقاف Timer
  void onLogout() {
    _stopTimer();
    _userId = null;
    emit(const SyncState());
  }

  /// تشغيل مزامنة فورية (يُنادى من الواجهة أو بعد حفظ سجل جديد)
  Future<void> triggerSync() async {
    if (_userId == null || _userId!.isEmpty) return;
    if (state.isSyncing) return;

    emit(state.copyWith(isSyncing: true));
    try {
      await _service.runOnce(_userId!);
    } finally {
      await _refreshCounts();
    }
  }

  Future<void> _refreshCounts() async {
    if (_userId == null) return;
    final p = await _repo.countPending(_userId!);
    final f = await _repo.countFailed(_userId!);
    if (!isClosed) {
      emit(state.copyWith(pendingCount: p, failedCount: f, isSyncing: false));
    }
  }

  void _handleCountsChanged(int pending, int failed) {
    if (!isClosed) {
      emit(
        state.copyWith(
          pendingCount: pending,
          failedCount: failed,
          isSyncing: false,
        ),
      );
    }
    // أوقف Timer لو مفيش pending
    if (pending == 0) _stopTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_userId == null) return;
      final p = await _repo.countPending(_userId!);
      if (p == 0) {
        _stopTimer();
        return;
      }
      await triggerSync();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }
}
