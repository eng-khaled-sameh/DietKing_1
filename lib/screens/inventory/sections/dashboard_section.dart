import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../utils/csv_exporter.dart';
import '../widgets/dashboard/kpi_card.dart';
import '../widgets/inventory_snack.dart';
import '../../../../core/utils/file_saved_dialog.dart';

/// لوحة المخزون الرئيسية — الأرقام من الكاش المحلي (صفر طلبات شبكة إضافية)
class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

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
              _buildKpiGrid(state),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(state.error!),
              ],
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
          'نظرة عامة على المخزون',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // زر تحديث
            Tooltip(
              message: 'تحديث البيانات',
              child: IconButton(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                onPressed: state.isLoading
                    ? null
                    : () => context.read<InventoryCubit>().refreshCatalogAndStock(),
              ),
            ),
            const SizedBox(width: 8),
            // تصدير نواقص المخزون
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final items = context.read<InventoryCubit>().state.visibleItems
                      .where((m) => m.isLow)
                      .toList();
                  final rows = items
                      .map((m) => [
                            m.item.sku,
                            m.item.name,
                            m.stockQty,
                            m.item.minLevel,
                            m.item.unitCode,
                          ])
                      .toList();
                  final path = await CsvExporter.save(
                    baseName: 'LowStock',
                    headers: ['رمز SKU', 'الاسم', 'الرصيد', 'الحد الأدنى', 'الوحدة'],
                    rows: rows,
                  );
                  if (context.mounted) {
                    showFileSavedDialog(context, path);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showInventorySnack(context, 'تعذر حفظ الملف', isError: true);
                  }
                }
              },
              icon: const Icon(
                Icons.file_download_outlined,
                color: AppColors.onSurface,
              ),
              label: Text(
                'تصدير نواقص المخزون',
                style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiGrid(InventoryState state) {
    final totalItems = state.catalog?.items.where((i) => i.isActive).length ?? 0;
    final rawItems = state.catalog?.items
            .where((i) {
              if (!i.isActive) return false;
              final cat = state.catalog?.categories
                  .where((c) => c.id == i.categoryId)
                  .firstOrNull;
              return cat?.kind.name == 'raw';
            })
            .length ??
        0;
    final finishedItems = state.finishedItems.length;
    final stockValue = state.totalStockValue;

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      children: [
        KPICard(
          title: 'إجمالي الأصناف',
          value: '$totalItems',
          icon: Icons.inventory_2_outlined,
          iconColor: AppColors.primary,
        ),
        KPICard(
          title: 'الخامات',
          value: '$rawItems',
          icon: Icons.grain,
          iconColor: AppColors.tertiary,
        ),
        KPICard(
          title: 'منتجات تامة',
          value: '$finishedItems',
          icon: Icons.restaurant_menu,
          iconColor: AppColors.secondary,
        ),
        KPICard(
          title: 'قيمة المخزون',
          value: stockValue > 0
              ? '${stockValue.toStringAsFixed(0)} ج.م'
              : '—',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.statusGreen,
        ),
        KPICard(
          title: 'أصناف منخفضة',
          value: '${state.lowStockCount}',
          subtitle: 'تحت الحد الأدنى',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.statusRed,
          isAlert: state.lowStockCount > 0,
        ),
        KPICard(
          title: 'طلبات توريد نشطة',
          value: '${state.activeSupplyCount}',
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.secondary,
        ),
        KPICard(
          title: 'طلبات فروع مقدّمة',
          value: '${state.submittedBranchOrdersCount}',
          icon: Icons.storefront_outlined,
          iconColor: AppColors.secondaryContainer,
          isAlert: state.submittedBranchOrdersCount > 0,
        ),
        KPICard(
          title: 'حالة المزامنة',
          value: state.isLoading ? 'جارٍ...' : 'محدّث',
          icon: state.isLoading
              ? Icons.sync
              : Icons.cloud_done_outlined,
          iconColor: state.isLoading
              ? AppColors.onSurfaceVariant
              : AppColors.statusGreen,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.statusRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.statusRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
