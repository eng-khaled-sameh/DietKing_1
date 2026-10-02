import 'package:flutter/material.dart';
import '../../../../../data/inventory/models/branch_order.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class BranchOrderItemsTable extends StatelessWidget {
  final BranchOrder order;

  const BranchOrderItemsTable({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: order.lines.map((line) {
        return Padding(
          key: ValueKey(line.id),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  line.itemId,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'المطلوب: ${line.qtyRequested}',
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'المعتمد: ${line.qtyApproved ?? "—"}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: line.qtyApproved != null ? AppColors.statusGreen : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
