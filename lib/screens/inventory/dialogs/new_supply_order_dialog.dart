import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';

class NewSupplyOrderDialog extends StatefulWidget {
  const NewSupplyOrderDialog({super.key});

  @override
  State<NewSupplyOrderDialog> createState() => _NewSupplyOrderDialogState();
}

class _NewSupplyOrderDialogState extends State<NewSupplyOrderDialog> {
  final _supplierController = TextEditingController();
  final _itemsController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 1));
  String _priority = 'عادية';

  @override
  void dispose() {
    _supplierController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  void _save() {
    final supplier = _supplierController.text.trim();
    final items = _itemsController.text.trim();

    if (supplier.isEmpty || items.isEmpty) return;

    context.read<InventoryCubit>().createSupplyOrder(
          supplierName: supplier,
          lines: [{'note': items}],
          expectedDate: _expectedDate,
          priority: _priority,
        );

    Navigator.of(context).pop();
    showInventorySnack(context, 'تم إنشاء طلب التوريد بنجاح');
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && context.mounted) {
      setState(() => _expectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          'إنشاء طلب توريد جديد',
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
                  controller: _supplierController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'اسم المورّد',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _itemsController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'الخامات المطلوبة',
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
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ التوريد المتوقع',
                            labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          ),
                          child: Text(
                            '${_expectedDate.year}-${_expectedDate.month.toString().padLeft(2, '0')}-${_expectedDate.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        items: ['عادية', 'عاجلة'].map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _priority = v);
                        },
                        decoration: InputDecoration(
                          labelText: 'الأولوية',
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
            child: Text('إنشاء', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}
