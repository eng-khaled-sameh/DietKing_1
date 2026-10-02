import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../../models/enums.dart';
import 'raw_material_row.dart';

class RawMaterialsTable extends StatelessWidget {
  const RawMaterialsTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          _buildTableHeader(context),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                final items = state.visibleRawMaterials;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد خامات مطابقة للبحث',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return RawMaterialRow(item: items[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _buildSortableColumn(context, 'رمز SKU', RawSortColumn.sku, 2),
          _buildSortableColumn(context, 'اسم الصنف', RawSortColumn.name, 3),
          _buildSortableColumn(context, 'الفئة', RawSortColumn.category, 2),
          _buildSortableColumn(context, 'الرصيد الحالي', RawSortColumn.stock, 2),
          const Expanded(flex: 2, child: Text('')), // Status column
          const Expanded(flex: 3, child: Text('')), // Actions column
        ],
      ),
    );
  }

  Widget _buildSortableColumn(BuildContext context, String label, RawSortColumn column, int flex) {
    final cubit = context.read<InventoryCubit>();
    return Expanded(
      flex: flex,
      child: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          final isSorted = state.rawSortColumn == column;
          final isAscending = state.rawSortAscending;
          return InkWell(
            onTap: () => cubit.sortRaw(column),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSorted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
