import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../utils/csv_exporter.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/branch/branch_order_card.dart';
import '../../../../data/inventory/models/branch_order.dart';

class BranchOrdersSection extends StatelessWidget {
  const BranchOrdersSection({super.key});

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
                'طلبات الفروع',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final cubit = context.read<InventoryCubit>();
                  try {
                    final rows = cubit.state.branchOrders.map((o) => [o.number, o.branchName, o.createdAt.toLocal().toString(), o.status.arabicLabel, o.status == BranchOrderStatus.approved ? 'نعم' : 'لا']).toList();
                    final path = await CsvExporter.save(
                      baseName: 'BranchOrders',
                      headers: ['رقم الطلب', 'الفرع', 'وقت الطلب', 'الحالة', 'تم التسليم'],
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
                  'تصدير الطلبات',
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceContainerHigh),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state.branchOrders.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد طلبات فروع حالياً',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: state.branchOrders.length,
                  itemBuilder: (context, index) {
                    final order = state.branchOrders[index];
                    return BranchOrderCard(key: ValueKey(order.id), order: order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
