import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/read_error_state.dart';

class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, state),
              const SizedBox(height: 24),
              if (state.isLoadingDocs)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null && state.stockValuation.isEmpty)
                ReadErrorState(
                  message: state.error!,
                  onRetry: () => context
                      .read<InventoryCubit>()
                      .loadReports(force: true),
                )
              else
                _buildContent(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, InventoryState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'التقارير والإحصائيات',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          tooltip: 'تحديث البيانات',
          onPressed: state.isLoadingDocs
              ? null
              : () => context.read<InventoryCubit>().loadReports(force: true),
        ),
      ],
    );
  }

  Widget _buildContent(InventoryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStockValuationTable(state),
        const SizedBox(height: 32),
        _buildLowStockTable(state),
      ],
    );
  }

  Widget _buildStockValuationTable(InventoryState state) {
    final double grandTotal = state.stockValuation.fold(0, (sum, v) => sum + v.totalValue);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'قيمة المخزون الحالي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الإجمالي: ${grandTotal.toStringAsFixed(2)} ريال',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceContainerHigh),
          if (state.stockValuation.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'لا توجد أصناف في المخزون حالياً',
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
                dataTextStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
                columns: const [
                  DataColumn(label: Text('المستودع')),
                  DataColumn(label: Text('رمز SKU')),
                  DataColumn(label: Text('الصنف')),
                  DataColumn(label: Text('التصنيف')),
                  DataColumn(label: Text('الكمية', textAlign: TextAlign.center)),
                  DataColumn(label: Text('التكلفة (متوسط)', textAlign: TextAlign.center)),
                  DataColumn(label: Text('إجمالي القيمة', textAlign: TextAlign.center)),
                ],
                rows: state.stockValuation.map((v) {
                  return DataRow(
                    cells: [
                      DataCell(Text(v.warehouseName)),
                      DataCell(Text(v.sku)),
                      DataCell(Text(v.itemName)),
                      DataCell(Text(v.categoryName)),
                      DataCell(Text(v.quantity.toStringAsFixed(2))),
                      DataCell(Text(v.avgCost.toStringAsFixed(2))),
                      DataCell(Text(v.totalValue.toStringAsFixed(2))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockTable(InventoryState state) {
    if (state.lowStockReport.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              'لا توجد أصناف تحت الحد الأدنى',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 12),
                Text(
                  'الأصناف تحت الحد الأدنى',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.errorContainer),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
              ),
              dataTextStyle: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
              ),
              columns: const [
                DataColumn(label: Text('رمز SKU')),
                DataColumn(label: Text('الصنف')),
                DataColumn(label: Text('الحد الأدنى', textAlign: TextAlign.center)),
                DataColumn(label: Text('الرصيد الحالي', textAlign: TextAlign.center)),
                DataColumn(label: Text('مقدار النقص', textAlign: TextAlign.center)),
                DataColumn(label: Text('قيمة النقص (بالتكلفة)', textAlign: TextAlign.center)),
              ],
              rows: state.lowStockReport.map((v) {
                return DataRow(
                  cells: [
                    DataCell(Text(v.sku)),
                    DataCell(Text(v.itemName)),
                    DataCell(Text(v.minLevel.toStringAsFixed(2))),
                    DataCell(Text(
                      v.currentQty.toStringAsFixed(2),
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(v.shortage.toStringAsFixed(2))),
                    DataCell(Text(v.shortageValue.toStringAsFixed(2))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
