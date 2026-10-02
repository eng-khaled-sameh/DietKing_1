import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../utils/csv_exporter.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/kitchen/kitchen_issues_table.dart';
import '../dialogs/new_kitchen_issue_dialog.dart';
import '../../../../data/inventory/models/kitchen_models.dart';

class KitchenIssueSection extends StatelessWidget {
  const KitchenIssueSection({super.key});

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
                'صرف خامات للمطبخ',
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
                        final rows = cubit.state.kitchenIssues.map((i) => [i.number, i.cookPlan ?? '', '${i.lines.length} خامات', i.chefName, i.shift.arabicLabel, 'تم الصرف']).toList();
                        final path = await CsvExporter.save(
                          baseName: 'KitchenIssues',
                          headers: ['رقم الإذن', 'خطة الإنتاج', 'الخامات', 'الشيف', 'الوردية', 'الحالة'],
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
                      'تصدير السجل',
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
                        builder: (ctx) => const NewKitchenIssueDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, color: AppColors.onPrimary),
                    label: Text(
                      'إصدار صرفية جديدة',
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
          const Expanded(child: KitchenIssuesTable()),
        ],
      ),
    );
  }
}
