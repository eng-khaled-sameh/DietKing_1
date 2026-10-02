import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubit/inventory_cubit.dart';
import '../models/enums.dart';

class SectionHeader extends StatelessWidget {
  final String sectionName;
  final String title;
  final String? badgeText;
  final Color? badgeColor;
  final IconData? badgeIcon;
  final List<Widget> actions;

  const SectionHeader({
    super.key,
    required this.sectionName,
    required this.title,
    this.badgeText,
    this.badgeColor,
    this.badgeIcon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => context.read<InventoryCubit>().selectSection(InventorySection.dashboard),
              child: Text(
                'الرئيسية',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              ' / $sectionName',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXxl,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: AppDimens.spaceMd),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.primaryContainer).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(badgeIcon, size: 16, color: badgeColor ?? AppColors.primary),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            badgeText!,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: actions,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceXl),
      ],
    );
  }
}
