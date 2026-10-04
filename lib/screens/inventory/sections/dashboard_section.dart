import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/dashboard/kpi_card.dart';

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
              _buildKpiGrid(context, state),
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
          ],
        ),
      ],
    );
  }

  Widget _buildKpiGrid(BuildContext context, InventoryState state) {
    final totalItems = state.catalog?.items.where((i) => i.isActive).length ?? 0;
    final rawItems = state.catalog?.items
            .where((i) {
              if (!i.isActive) return false;
              final cat = state.catalog?.categories
                  .where((c) => c.id == i.categoryId)
                  .firstOrNull;
              return cat?.kind.name == 'raw';
            })
            .length ?? 0;
    final finishedItems = state.finishedItems.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final int crossAxisCount = screenWidth < 1100 ? 2 : 4;
        const double spacing = 16.0;
        
        final double itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              height: 120, // fixed height for uniform look
              child: KPICard(
                title: 'إجمالي الأصناف',
                value: '$totalItems',
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              height: 120,
              child: KPICard(
                title: 'الخامات',
                value: '$rawItems',
                icon: Icons.grain,
                iconColor: AppColors.tertiary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              height: 120,
              child: KPICard(
                title: 'منتجات تامة',
                value: '$finishedItems',
                icon: Icons.restaurant_menu,
                iconColor: AppColors.secondary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              height: 120,
              child: KPICard(
                title: 'أصناف منخفضة',
                value: '${state.lowStockCount}',
                subtitle: 'تحت الحد الأدنى',
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.statusRed,
                isAlert: state.lowStockCount > 0,
              ),
            ),
            SizedBox(
              width: itemWidth,
              height: 120,
              child: KPICard(
                title: 'طلبات توريد نشطة',
                value: '${state.activeSupplyCount}',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.secondary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              height: 120,
              child: KPICard(
                title: 'طلبات فروع مقدّمة',
                value: '${state.submittedBranchOrdersCount}',
                icon: Icons.storefront_outlined,
                iconColor: AppColors.secondaryContainer,
                isAlert: state.submittedBranchOrdersCount > 0,
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
