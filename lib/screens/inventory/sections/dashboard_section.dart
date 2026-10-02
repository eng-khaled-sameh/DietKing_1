import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../utils/csv_exporter.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/dashboard/kpi_card.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final lowStock = state.visibleRawMaterials.where((m) => m.stockQty < m.item.minLevel).toList();
                        final rows = lowStock.map((m) => [m.item.sku, m.item.name, m.stockQty, m.item.minLevel]).toList();
                        final path = await CsvExporter.save(
                          baseName: 'LowStock',
                          headers: ['رمز SKU', 'الاسم', 'الرصيد', 'الحد الأدنى'],
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
                      'تصدير نواقص المخزون',
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
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.5,
                children: [
                  KPICard(
                    title: 'إجمالي الأصناف',
                    value: '${state.catalog?.items.length ?? 0}',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.primary,
                  ),
                  KPICard(
                    title: 'أصناف منخفضة المخزون',
                    value: '${state.lowStockCount}',
                    subtitle: 'تتطلب إعادة طلب',
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
                    title: 'طلبات فروع معلقة',
                    value: '${state.activeBranchOrdersCount}',
                    icon: Icons.storefront_outlined,
                    iconColor: AppColors.secondaryContainer,
                  ),
                  KPICard(
                    title: 'تصنيفات نشطة',
                    value: '${state.catalog?.categories.where((c) => c.isActive).length ?? 0}',
                    icon: Icons.category_outlined,
                    iconColor: AppColors.tertiary,
                  ),
                  KPICard(
                    title: 'حالة المزامنة',
                    value: state.isLoading ? 'جارٍ...' : 'محدّث',
                    icon: state.isLoading ? Icons.sync : Icons.cloud_done_outlined,
                    iconColor: state.isLoading ? AppColors.onSurfaceVariant : AppColors.statusGreen,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
