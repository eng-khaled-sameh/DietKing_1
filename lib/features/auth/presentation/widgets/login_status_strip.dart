import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط حالة النظام العلوي مع بيانات ثابتة للنظام ونقطة البيع والوقت
class LoginStatusStrip extends StatelessWidget {
  const LoginStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimens.statusStripMaxWidth,
          ),
          child: Container(
            height: AppDimens.statusStripHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                // ── يمين: معلومات نقطة البيع ───────────────────────────────
                _PosInfoSection(),

                // ── وسط: التاريخ الميلادي والهجري ───────────────────────────
                _DateSection(),

                // ── يسار: مؤشر الاتصال والساعة ───────────────────────────────
                _StatusTimeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosInfoSection extends StatelessWidget {
  const _PosInfoSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            size: AppDimens.iconMd,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'نقطة البيع المصرحة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            Text(
              'محطة الكاشير الرئيسية #01',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_rounded,
          size: AppDimens.iconSm,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          '23 سبتمبر 2026',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        Text(
          '11 ربيع الآخر 1448 هـ',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _StatusTimeSection extends StatelessWidget {
  const _StatusTimeSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pill أخضر: متصل بالإنترنت
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(
              color: AppColors.tertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                'متصل بالإنترنت',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),

        // Pill الساعة (نص ثابت)
        // TODO: bind to live clock
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: AppDimens.iconSm,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                '11:16 ص',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
