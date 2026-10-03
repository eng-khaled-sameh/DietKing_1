import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../../../../data/inventory/models/kitchen_models.dart';
import '../catalog_item_details.dart';

class KitchenIssueRow extends StatelessWidget {
  final KitchenIssue issue;
  final Map<String, InventoryItem> itemsById;

  const KitchenIssueRow({
    super.key,
    required this.issue,
    required this.itemsById,
  });

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
              issue.number,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              issue.cookPlan ?? '—',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: issue.lines.map((line) {
                final item = itemsById[line.itemId];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: CatalogItemDetails(item: item)),
                      const SizedBox(width: 8),
                      Text(
                        formatCatalogQuantity(line.qty, item),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${issue.chefName} (${issue.shift.arabicLabel})',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'تم الصرف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.statusGreen,
                    fontWeight: FontWeight.bold,
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
