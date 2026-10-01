import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/login_branch.dart';

// ── State ──────────────────────────────────────────────────────────────────────

/// بيانات الجلسة — ثابتة بالكامل بعد start()، لا يوجد copyWith ولا setters
class SessionState extends Equatable {
  final bool isActive;
  final String userId;
  final String email;
  final String cashierName;
  final String branchId;
  final String branchName;
  final String branchCode;
  final String shift;
  // ── حقول مضافة: معرّف الجلسة ووقت البداية ─────────────────────────────────
  final String sessionId;   // UUID v4 مولَّد بـ Random.secure عند start()
  final DateTime? startedAt; // وقت بداية الجلسة بتوقيت الجهاز

  const SessionState({
    this.isActive = false,
    this.userId = '',
    this.email = '',
    this.cashierName = '',
    this.branchId = '',
    this.branchName = '',
    this.branchCode = '',
    this.shift = '',
    this.sessionId = '',
    this.startedAt,
  });

  @override
  List<Object?> get props => [
        isActive,
        userId,
        email,
        cashierName,
        branchId,
        branchName,
        branchCode,
        shift,
        sessionId,
        startedAt,
      ];
}

// ── Cubit ──────────────────────────────────────────────────────────────────────

/// Cubit الجلسة — على مستوى التطبيق، فوق الـ Navigator
/// بيانات الجلسة لا تتغير بعد start() إلا عند end()
class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  /// يبدأ الجلسة مرة واحدة فقط من بيانات المستخدم المسجّل دخوله
  /// [branch]: الفرع المختار في شاشة الدخول
  /// [shift]: الوردية المختارة (الاسم بدون وقت)
  /// [userId]: معرّف المستخدم من Supabase Auth
  /// [email]: إيميل المستخدم من Supabase Auth
  ///
  /// لو الجلسة نشطة بالفعل: تجاهل الاستدعاء تماماً
  void start({
    required LoginBranch branch,
    required String shift,
    required String userId,
    required String email,
  }) {
    // الجلسة نشطة: لا تعدّل شيء
    if (state.isActive) return;

    // cashierName = الجزء قبل @ في الإيميل
    final cashierName = email.split('@').first;

    emit(SessionState(
      isActive: true,
      userId: userId,
      email: email,
      cashierName: cashierName,
      branchId: branch.id,
      branchName: branch.name,
      branchCode: branch.code,
      shift: shift,
      sessionId: _generateUuidV4(),
      startedAt: DateTime.now(),
    ));
  }

  /// ينهي الجلسة — الطريقة الوحيدة لتفريغ البيانات، تُستدعى عند تسجيل الخروج
  void end() {
    emit(const SessionState());
  }

  // ── UUID v4 بـ Random.secure ───────────────────────────────────────────────
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-'
        '${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-'
        '${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}
