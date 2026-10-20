import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../../../../data/inventory/models/kitchen_models.dart';
import '../dialogs/new_kitchen_issue_dialog.dart';
import '../widgets/kitchen/kitchen_issues_table.dart';
import '../widgets/inventory_snack.dart';
import '../utils/csv_exporter.dart';
import '../../../../core/utils/file_saved_dialog.dart';
import '../dialogs/export_date_range_dialog.dart';

/// قسم صرف الخامات للمطبخ
class KitchenIssueSection extends StatelessWidget {
  const KitchenIssueSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          const Expanded(child: KitchenIssuesTable()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'صرف خامات للمطبخ',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // تحديث
            Tooltip(
              message: 'تحديث السجل',
              child: IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<InventoryCubit>()
                    ..clearKitchenCache()
                    ..loadKitchenIssues();
                },
              ),
            ),
            const SizedBox(width: 8),
            // تصدير
            OutlinedButton.icon(
              onPressed: () => _exportCsv(context),
              icon: const Icon(
                Icons.file_download_outlined,
                color: AppColors.onSurface,
                size: 18,
              ),
              label: Text(
                'تصدير',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // إصدار صرفية جديدة
            ElevatedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: context.read<InventoryCubit>(),
                  child: const NewKitchenIssueDialog(),
                ),
              ),
              icon: const Icon(Icons.add, color: AppColors.onPrimary),
              label: Text(
                'إصدار صرفية جديدة',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => const ExportDateRangeDialog(title: 'صرف خامات للمطبخ'),
    );
    if (range == null || !context.mounted) return;

    try {
      final state = context.read<InventoryCubit>().state;
      final filtered = state.kitchenIssues.where((i) {
        final d = i.createdAt.toLocal();
        return !d.isBefore(range.start) && !d.isAfter(range.end);
      }).toList();

      if (filtered.isEmpty) {
        if (context.mounted) {
          showInventorySnack(
            context,
            'لا توجد سجلات صرف في الفترة المحددة',
            isError: false,
          );
        }
        return;
      }

      final rows = filtered
          .map(
            (i) => [
              i.number,
              i.cookPlan ?? '',
              '${i.lines.length} خامات',
              i.chefName,
              i.shift.arabicLabel,
              i.notes ?? '',
              i.createdAt.toLocal().toString().substring(0, 16),
            ],
          )
          .toList();
      final path = await CsvExporter.save(
        baseName: 'KitchenIssues',
        headers: [
          'رقم الإذن',
          'خطة الإنتاج',
          'عدد الخامات',
          'الشيف',
          'الوردية',
          'الملاحظات',
          'التاريخ والوقت',
        ],
        rows: rows,
      );
      if (context.mounted) {
        showFileSavedDialog(context, path);
      }
    } catch (e) {
      if (context.mounted) {
        showInventorySnack(context, 'خطأ في التصدير', isError: true);
      }
    }
  }
}
