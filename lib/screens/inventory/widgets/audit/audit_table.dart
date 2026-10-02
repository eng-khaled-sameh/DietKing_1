import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import 'audit_row_tile.dart';

class AuditTable extends StatelessWidget {
  const AuditTable({super.key});

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
          _buildTableHeader(),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              buildWhen: (previous, current) => previous.auditRows != current.auditRows,
              builder: (context, state) {
                if (state.auditRows.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد أصناف للجرد',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: state.auditRows.length,
                  itemBuilder: (context, index) {
                    // Do not rebuild all rows, only the one changing state.
                    // This is handled by relying on the unique key of the item or its bloc building.
                    // Here, we provide key based on SKU so Flutter knows it's the same widget.
                    final row = state.auditRows[index];
                    return AuditRowTile(key: ValueKey(row.sku), row: row);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('رمز SKU', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('الصنف', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('الرصيد الدفتري', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('الرصيد الفعلي', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Center(child: Text('الفارق', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text('الحالة', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Text('ملاحظات الجرد', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
