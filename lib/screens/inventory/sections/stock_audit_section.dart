import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../utils/csv_exporter.dart';
import '../widgets/audit/audit_table.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/confirm_dialog.dart';

class StockAuditSection extends StatelessWidget {
  const StockAuditSection({super.key});

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
                'جرد ومطابقة المخزون',
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
                        final rows = cubit.state.auditRows.map((r) => [r.sku, r.name, r.systemQty, r.actualQty, r.difference, r.note]).toList();
                        final path = await CsvExporter.save(
                          baseName: 'StockAudit',
                          headers: ['رمز SKU', 'الصنف', 'الرصيد الدفتري', 'الرصيد الفعلي', 'الفارق', 'الملاحظات'],
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
                      'تصدير قائمة الجرد',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final cubit = context.read<InventoryCubit>();
                      // 1. Dry-run: معاينة الفروقات
                      try {
                        final preview = await cubit.applyStocktake(dryRun: true);
                        if (!context.mounted) return;

                        final diffs = (preview['diffs'] as List<dynamic>?) ?? [];
                        final diffText = diffs.isEmpty
                            ? 'لا يوجد فروقات — الجرد مطابق للنظام'
                            : 'عدد الأصناف ذات الفروقات: ${diffs.length}';

                        // 2. تأكيد
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: AlertDialog(
                              backgroundColor: AppColors.surfaceContainer,
                              title: Text('تأكيد التسوية',
                                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                              content: Text(diffText,
                                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد')),
                              ],
                            ),
                          ),
                        );
                        if (confirm != true || !context.mounted) return;

                        // 3. كلمة مرور المدير
                        final ctrl = TextEditingController();
                        final password = await showDialog<String>(
                          context: context,
                          builder: (ctx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: AlertDialog(
                              backgroundColor: AppColors.surfaceContainer,
                              title: Text('صلاحية الإدارة',
                                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                              content: TextField(controller: ctrl, obscureText: true,
                                  decoration: const InputDecoration(labelText: 'كلمة المرور')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('تأكيد')),
                              ],
                            ),
                          ),
                        );
                        if (password == null || !context.mounted) return;

                        // 4. Commit
                        await cubit.applyStocktake(dryRun: false, notes: 'جرد دوري');
                        if (context.mounted) {
                          showInventorySnack(context, 'تمت تسوية فروقات الجرد بنجاح ✓');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showInventorySnack(context, 'خطأ: $e', isError: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.onPrimary),
                    label: Text(
                      'اعتماد وتسوية فروقات الجرد',
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
          const Expanded(child: AuditTable()),
        ],
      ),
    );
  }
}
