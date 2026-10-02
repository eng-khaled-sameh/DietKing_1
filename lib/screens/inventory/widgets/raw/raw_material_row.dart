import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_state.dart';
import '../inventory_snack.dart';
import 'raw_status_badge.dart';

class RawMaterialRow extends StatelessWidget {
  final InventoryItemWithStock item;

  const RawMaterialRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item.item.sku,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.item.name,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.categoryLabel,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.stockQty} ${item.item.unitCode}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: item.isLow ? AppColors.statusRed : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: RawStatusBadge(isLow: item.isLow),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'تعديل الرصيد',
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceContainer,
                          title: Text('تعديل رصيد ${item.item.name}',
                              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                          content: Text('استخدم أزرار +/- لتعديل الرصيد',
                              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('إغلاق',
                                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Tooltip(
                  message: 'خصم 10',
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.statusRed, size: 20),
                    onPressed: () {
                      showInventorySnack(context, 'تم خصم 10 من ${item.item.name}');
                    },
                  ),
                ),
                Tooltip(
                  message: 'إضافة 10',
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.statusGreen, size: 20),
                    onPressed: () {
                      showInventorySnack(context, 'تم إضافة 10 إلى ${item.item.name}');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
