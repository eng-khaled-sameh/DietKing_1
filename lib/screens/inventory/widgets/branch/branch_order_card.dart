import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/inventory/models/branch_order.dart';
import '../inventory_snack.dart';
import '../confirm_dialog.dart';

class BranchOrderCard extends StatelessWidget {
  final BranchOrder order;

  const BranchOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDispatched = order.status == BranchOrderStatus.approved;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDispatched
              ? AppColors.statusGreen.withValues(alpha: 0.3)
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isDispatched ? Icons.check_circle : Icons.storefront,
                    color: isDispatched ? AppColors.statusGreen : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${order.branchName} (طلب ${order.number})',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDispatched
                      ? AppColors.statusGreen.withValues(alpha: 0.1)
                      : AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status.arabicLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDispatched ? AppColors.statusGreen : AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تاريخ الطلب: ${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.lines.length} أصناف مطلوبة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const Divider(color: AppColors.outlineVariant, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isDispatched
                    ? null
                    : () async {
                        final confirm = await showConfirmDialog(
                          context,
                          title: 'رفض الطلب',
                          content: 'هل أنت متأكد من رفض الطلب ${order.number}؟',
                        );
                        if (confirm && context.mounted) {
                          showInventorySnack(context, 'تم رفض الطلب ${order.number}');
                        }
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('رفض الطلب'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusRed,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: isDispatched
                    ? null
                    : () {
                        showInventorySnack(context, 'تم اعتماد الطلب ${order.number} وتسليمه للسائق');
                      },
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('اعتماد وتسليم للسائق'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
