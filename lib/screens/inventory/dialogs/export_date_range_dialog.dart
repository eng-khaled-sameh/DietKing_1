import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// حوار اختيار الفترة الزمنية لتصدير إكسيل
/// مقيّد بسياسة الاحتفاظ بالبيانات (شهرين - تُحذف بيانات الشهر الأقدم يوم 5 من كل شهر)
class ExportDateRangeDialog extends StatefulWidget {
  final String title;

  const ExportDateRangeDialog({super.key, required this.title});

  /// حساب تاريخ بداية أقدم سجل متاح وفق سياسة الاحتفاظ بالبيانات
  static DateTime calculateRetentionCutoff() {
    final now = DateTime.now();
    // يوم 5 في الشهر الجديد يتم حذف بيانات شهر من الشهرين السابقين
    final monthsBack = now.day >= 5 ? 2 : 3;
    return DateTime(now.year, now.month - monthsBack, 1);
  }

  @override
  State<ExportDateRangeDialog> createState() => _ExportDateRangeDialogState();
}

class _ExportDateRangeDialogState extends State<ExportDateRangeDialog> {
  late DateTime _earliestDate;
  late DateTime _latestDate;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _earliestDate = ExportDateRangeDialog.calculateRetentionCutoff();
    _latestDate = DateTime(now.year, now.month, now.day);

    // افتراضياً: بداية الشهر الحالي حتى اليوم
    _startDate = DateTime(now.year, now.month, 1);
    if (_startDate.isBefore(_earliestDate)) {
      _startDate = _earliestDate;
    }
    _endDate = _latestDate;
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: _earliestDate,
      lastDate: _endDate,
      helpText: 'اختر تاريخ البداية',
      cancelText: 'إلغاء',
      confirmText: 'تحديد',
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _latestDate,
      helpText: 'اختر تاريخ النهاية',
      cancelText: 'إلغاء',
      confirmText: 'تحديد',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _applyPreset(int preset) {
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case 0: // هذا الشهر
          _startDate = DateTime(now.year, now.month, 1);
          if (_startDate.isBefore(_earliestDate)) _startDate = _earliestDate;
          _endDate = _latestDate;
          break;
        case 1: // الشهر السابق
          final firstOfPrev = DateTime(now.year, now.month - 1, 1);
          final lastOfPrev = DateTime(now.year, now.month, 0);
          _startDate = firstOfPrev.isBefore(_earliestDate) ? _earliestDate : firstOfPrev;
          _endDate = lastOfPrev.isAfter(_latestDate) ? _latestDate : lastOfPrev;
          break;
        case 2: // كامل الفترة المحفوظة
          _startDate = _earliestDate;
          _endDate = _latestDate;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تصدير Excel — ${widget.title}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontLg,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'حدد الفترة الزمنية المطلوبة لاستخراج الملف',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── تنبيه سياسة حفظ البيانات ───────────────────────
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceSm + 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Text(
                        'وفقاً لسياسة النظام، يتم الاحتفاظ بالبيانات لمدة شهرين (حيث تُحذف بيانات الشهر الأقدم في يوم 5 من كل شهر). أقدم تاريخ متاح للاستخراج هو ${_formatDate(_earliestDate)}.',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontXs,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── خيارات سريعة (Presets) ────────────────────────
              Text(
                'فترات سريعة:',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip('هذا الشهر', () => _applyPreset(0)),
                  _buildPresetChip('الشهر السابق', () => _applyPreset(1)),
                  _buildPresetChip('كامل الفترة المحفوظة', () => _applyPreset(2)),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),

              // ── حقول التاريخ (من / إلى) ───────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector(
                      label: 'من تاريخ',
                      dateText: _formatDate(_startDate),
                      onTap: _selectStartDate,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: _buildDateSelector(
                      label: 'إلى تاريخ',
                      dateText: _formatDate(_endDate),
                      onTap: _selectEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceXl),

              // ── أزرار الإجراء ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      final range = DateTimeRange(
                        start: DateTime(
                          _startDate.year,
                          _startDate.month,
                          _startDate.day,
                          0,
                          0,
                          0,
                        ),
                        end: DateTime(
                          _endDate.year,
                          _endDate.month,
                          _endDate.day,
                          23,
                          59,
                          59,
                          999,
                        ),
                      );
                      Navigator.of(context).pop(range);
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(
                      'تصدير إلى Excel',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required String dateText,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
