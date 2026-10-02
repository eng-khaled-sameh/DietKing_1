import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../utils/csv_exporter.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/supply/supply_tabs.dart';
import '../widgets/supply/supply_orders_table.dart';
import '../dialogs/new_supply_order_dialog.dart';

class SupplyRequestsSection extends StatelessWidget {
  const SupplyRequestsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلبات المخزون والتوريد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final cubit = context.read<InventoryCubit>();
                      try {
                        final orders = cubit.state.supplyOrdersFor(cubit.state.supplyTab);
                        final rows = orders.map((o) => [o.number, o.supplierName, o.lines.length, '${o.expectedDate.year}-${o.expectedDate.month}-${o.expectedDate.day}', o.status.name]).toList();
                        final path = await CsvExporter.save(
                          baseName: 'SupplyOrders',
                          headers: ['رقم الطلب', 'المورّد', 'الخامات المطلوبة', 'تاريخ التوريد', 'الحالة'],
                          rows: rows,
                        );
                        if (context.mounted) {
                          showInventorySnack(context, 'تم حفظ الملف في: $path');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showInventorySnack(context, 'تعذر حفظ الملف', isError: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.file_download_outlined, color: AppColors.onSurface),
                    label: Text(
                      'تصدير القائمة',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const NewSupplyOrderDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, color: AppColors.onPrimary),
                    label: Text(
                      'طلب توريد جديد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SupplyTabs(),
          const SizedBox(height: 16),
          const Expanded(child: SupplyOrdersTable()),
        ],
      ),
    );
  }
}
