import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_desktop_app/core/theme/app_dimens.dart';

import '../theme/app_colors.dart';
import '../shift_info.dart';

/// شريط معلومات الجلسة: الكاشير + الفرع + حالة الاتصال + الوقت والتاريخ
class PosSessionInfoRow extends StatefulWidget {
  const PosSessionInfoRow({super.key});

  @override
  State<PosSessionInfoRow> createState() => _PosSessionInfoRowState();
}

class _PosSessionInfoRowState extends State<PosSessionInfoRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          // Dynamic cashier and branch info
          _InfoChip(
            icon: Icons.badge_outlined,
            label: 'الكاشير:',
            value: ShiftInfo.cashierName,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          _InfoChip(
            icon: Icons.store_outlined,
            label: 'الفرع:',
            value: ShiftInfo.branchName,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          // Shift title chip
          _InfoChip(
            icon: Icons.watch_later_outlined,
            label: 'الوردية:',
            value: ShiftInfo.currentShiftTitle,
          ),
          const Spacer(),

          // ── (2) وسط: حالة الاتصال النابضة ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: AppColors.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'متصل - Register 01',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── (3) يسار: الوقت والتاريخ (ثابتين) ───────────────────────────
          // TODO: bind to live clock
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '08:25 ص',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontMd,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1.1,
                ),
              ),
              Text(
                '23 سبتمبر 2026 | 11 ربيع الآخر 1448 هـ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimens.iconSm, color: AppColors.primary),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          '$label ',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
