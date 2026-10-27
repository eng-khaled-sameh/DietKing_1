import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

// ─── نتيجة dialog الوجبة ──────────────────────────────────────────────────────
/// [mealType] = 'لحم' | 'دجاج' | 'سمك'
/// [isPackage] = true لو تم تحديد خيار الباقة (السعر 0)
class MealTypeResult {
  final String mealType;
  final bool isPackage;

  const MealTypeResult({required this.mealType, required this.isPackage});
}

// ─── Dialog الاختيار ──────────────────────────────────────────────────────────

/// قائمة منبثقة لتحديد نوع البروتين (لحم / دجاج / سمك) مع خيار "باقة" (0 ريال)
/// تُعيد [MealTypeResult] أو null عند الإلغاء
class MealTypeSelectionDialog extends StatefulWidget {
  const MealTypeSelectionDialog({super.key});

  @override
  State<MealTypeSelectionDialog> createState() =>
      _MealTypeSelectionDialogState();
}

class _MealTypeSelectionDialogState extends State<MealTypeSelectionDialog> {
  String? _selectedType; // 'لحم' | 'دجاج' | 'سمك'
  bool _isPackage = false;

  static const _types = [
    ('لحم', Icons.kebab_dining_rounded),
    ('دجاج', Icons.lunch_dining_rounded),
    ('سمك', Icons.set_meal_rounded),
  ];

  void _confirm() {
    if (_selectedType == null) return;
    Navigator.of(context).pop(
      MealTypeResult(mealType: _selectedType!, isPackage: _isPackage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _selectedType != null;

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
          width: 360,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── العنوان ────────────────────────────────────────────────────
              Text(
                'اختر نوع الوجبة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'اختر البروتين ثم حدد إن كانت ضمن باقة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceXl),

              // ── خيارات البروتين (اختيار واحد) ─────────────────────────────
              Text(
                'نوع البروتين',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs + 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: _types.map((t) {
                  final label = t.$1;
                  final icon = t.$2;
                  final isSelected = _selectedType == label;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _TypeButton(
                        label: label,
                        icon: icon,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedType = label),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimens.spaceLg),
              const Divider(height: 1, color: Color(0x22FFFFFF)),
              const SizedBox(height: AppDimens.spaceMd),

              // ── خيار الباقة (toggle) ────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _isPackage = !_isPackage),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _isPackage
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFB45309).withValues(alpha: 0.25),
                              const Color(0xFFD97706).withValues(alpha: 0.12),
                            ],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          )
                        : null,
                    color: _isPackage
                        ? null
                        : AppColors.surfaceContainerHigh,
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: _isPackage
                          ? const Color(0xFFD97706).withValues(alpha: 0.65)
                          : AppColors.outlineVariant.withValues(alpha: 0.4),
                      width: _isPackage ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // أيقونة
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isPackage
                              ? const Color(0xFFD97706).withValues(alpha: 0.2)
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          size: 20,
                          color: _isPackage
                              ? const Color(0xFFD97706)
                              : AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // النص
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'باقة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontMd,
                                fontWeight: FontWeight.w700,
                                color: _isPackage
                                    ? const Color(0xFFD97706)
                                    : AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'السعر يُسجَّل بـ 0 ريال في الفاتورة والتقارير',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontXs,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Checkbox / Toggle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isPackage
                              ? const Color(0xFFD97706)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isPackage
                                ? const Color(0xFFD97706)
                                : AppColors.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: _isPackage
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // شارة "0 ر.س" لو الباقة محددة
              if (_isPackage) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusFull),
                      border: Border.all(
                        color:
                            const Color(0xFFD97706).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '✓ سيتم تسجيل هذه الوجبة بقيمة 0 ريال',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppDimens.spaceLg),

              // ── أزرار الإجراء ───────────────────────────────────────────
              Row(
                children: [
                  // إلغاء
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd),
                          side: BorderSide(
                            color: AppColors.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontMd,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // تأكيد
                  Expanded(
                    flex: 2,
                    child: AnimatedOpacity(
                      opacity: canConfirm ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: canConfirm
                              ? AppColors.primaryButtonGradient
                              : null,
                          color: canConfirm
                              ? null
                              : AppColors.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canConfirm ? _confirm : null,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              child: Center(
                                child: Text(
                                  canConfirm
                                      ? 'تأكيد${_isPackage ? " (باقة)" : " ($_selectedType)"}'
                                      : 'اختر نوعاً أولاً',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: AppDimens.fontMd,
                                    fontWeight: FontWeight.w700,
                                    color: canConfirm
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
}

// ─── زر اختيار نوع البروتين ──────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withValues(alpha: 0.25)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.75)
                : AppColors.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


