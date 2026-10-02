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
///
/// يعمل فقط طالما فيه سجلات pending.
/// عند فشل الشبكة: exponential backoff (30s → 60s → 120s → 300s كحد أقصى).
/// بعد أول نجاح: يرجع للـ 30 ثانية.
class SyncCubit extends Cubit<SyncState> {
  late final SyncService _service;
  Timer? _timer;
  String? _userId;
  final LocalRecordsRepository _repo = LocalRecordsRepository();

  /// جدول الـ backoff: بالثواني
  static const List<int> _backoffSchedule = [30, 60, 120, 300];

  /// الفهرس الحالي في جدول الـ backoff
  int _backoffIndex = 0;

  SyncCubit() : super(const SyncState()) {
    _service = SyncService(onCountsChanged: _handleCountsChanged);
  }

  /// يُستدعى بعد تسجيل الدخول لتعيين المستخدم الحالي وبدء المزامنة
  Future<void> onLogin(String userId) async {
    _userId = userId;
    _backoffIndex = 0;
    await _refreshCounts();
    // لو فيه pending: شغّل مزامنة فورية وابدأ الـ timer
    if (state.pendingCount > 0) {
      unawaited(triggerSync());
      _scheduleNextTimer();
    }
  }

  /// يُستدعى بعد تسجيل الخروج لإيقاف Timer
  void onLogout() {
    _stopTimer();
    _userId = null;
    _backoffIndex = 0;
    emit(const SyncState());
  }

  /// تشغيل مزامنة فورية (يُنادى من الواجهة أو بعد حفظ سجل جديد)
  Future<void> triggerSync() async {
    if (_userId == null || _userId!.isEmpty) return;
    if (state.isSyncing) return;

    emit(state.copyWith(isSyncing: true));
    final hadNetworkError = await _service.runOnce(_userId!);
    await _refreshCounts();

    // إذا نجحت المزامنة (ولو جزئياً): أعِد تعيين الـ backoff
    if (!hadNetworkError) {
      _backoffIndex = 0;
    } else {
      // فشل الشبكة: زِد الـ backoff للمرة القادمة
      if (_backoffIndex < _backoffSchedule.length - 1) {
        _backoffIndex++;
      }
    }

    // إعادة جدولة لو ما زال فيه pending
    if (state.pendingCount > 0) {
      _scheduleNextTimer();
    } else {
      _stopTimer();
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

  /// يجدول Timer للمحاولة القادمة بناءً على backoff index الحالي
  void _scheduleNextTimer() {
    _stopTimer();

    final delaySeconds = _backoffSchedule[_backoffIndex];
    _timer = Timer(Duration(seconds: delaySeconds), () async {
      if (_userId == null) return;

      // تحقق أولاً: هل ما زال فيه pending؟
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
