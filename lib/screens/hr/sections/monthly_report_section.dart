import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// صفحة التقرير الشهري التفصيلي — UI فقط (قيد التطوير)
class MonthlyReportSection extends StatelessWidget {
  const MonthlyReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'التقرير الشهري التفصيلي',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'هذه الصفحة قيد التطوير\nسيتم إضافة التقارير الشهرية قريباً',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: AppColors.outline.withOpacity(0.2)),
            ),
            child: Text(
              'قريباً — Coming Soon',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
