import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';

class NewKitchenIssueDialog extends StatefulWidget {
  const NewKitchenIssueDialog({super.key});

  @override
  State<NewKitchenIssueDialog> createState() => _NewKitchenIssueDialogState();
}

class _NewKitchenIssueDialogState extends State<NewKitchenIssueDialog> {
  final _planController = TextEditingController();
  final _materialsController = TextEditingController();
  final _chefController = TextEditingController();
  String _shift = 'صباحية';

  @override
  void dispose() {
    _planController.dispose();
    _materialsController.dispose();
    _chefController.dispose();
    super.dispose();
  }

  void _save() {
    final plan = _planController.text.trim();
    final materials = _materialsController.text.trim();
    final chef = _chefController.text.trim();

    if (plan.isEmpty || materials.isEmpty || chef.isEmpty) return;

    context.read<InventoryCubit>().createKitchenIssue(
          cookPlan: plan,
          lines: [{'note': materials}],
          chefName: chef,
          shift: _shift,
        );

    Navigator.of(context).pop();
    showInventorySnack(context, 'تم إصدار صرفية المطبخ بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          'صرف خامات جديدة للمطبخ',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _planController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'خطة الإنتاج المرتبطة',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _materialsController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'الخامات المطلوبة والكميات',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _chefController,
                        style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'الشيف المستلم',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _shift,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        items: ['صباحية', 'مسائية'].map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _shift = v);
                        },
                        decoration: InputDecoration(
                          labelText: 'الوردية',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('إصدار الصرفية', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}
