import 'package:intl/intl.dart';

/// أدوات حساب التواريخ وفق سياسة الاحتفاظ المعتمدة لقسم الحسابات (شهران فقط):
/// - الاحتفاظ ببيانات الشهر الحالي والشهر السابق (شهران فقط).
/// - في يوم 5 من الشهر الحالي وما بعده: أقدم تاريخ متاح هو أول يوم من الشهر السابق (now.month - 1).
/// - قبل يوم 5 من الشهر الحالي (أول 4 أيام): مهلة إقفال تتيح الرجوع لشهر إضافي (now.month - 2).
///   مثال: في 2026-10-13، الحد الأدنى المحفوظ هو 2026-09-01 (شهور 9 و 10 محفوظة).
///   في 2026-11-05، يُحذف شهر 9 بالكامل، ويصبح الحد الأدنى 2026-10-01 (شهور 10 و 11 محفوظة).
class AccountingDateUtils {
  AccountingDateUtils._();

  /// حساب تاريخ الحد الأدنى المحفوظ المتاح في قاعدة البيانات (شهرين فقط)
  static DateTime getRetentionEarliestDate([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    if (now.day >= 5) {
      return DateTime(now.year, now.month - 1, 1);
    } else {
      return DateTime(now.year, now.month - 2, 1);
    }
  }

  /// تاريخ الحد الأقصى للاختيار (نهاية اليوم الحالي)
  static DateTime getRetentionLatestDate([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  /// التحقق من صلاحية تاريخ ما ضمن نافذة الاحتفاظ
  static bool isWithinRetention(DateTime date, [DateTime? referenceDate]) {
    final earliest = getRetentionEarliestDate(referenceDate);
    final latest = getRetentionLatestDate(referenceDate);
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(DateTime(earliest.year, earliest.month, earliest.day)) &&
        !d.isAfter(DateTime(latest.year, latest.month, latest.day));
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// وصف نصي مختصر لسياسة الاحتفاظ
  static String getRetentionDescription([DateTime? referenceDate]) {
    final earliest = getRetentionEarliestDate(referenceDate);
    final latest = getRetentionLatestDate(referenceDate);
    final df = DateFormat('dd/MM/yyyy');
    return 'البيانات المتاحة: ${df.format(earliest)} — ${df.format(latest)}';
  }
}
