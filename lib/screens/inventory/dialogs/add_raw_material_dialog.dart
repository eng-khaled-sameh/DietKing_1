import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../models/raw_material.dart';
import '../models/enums.dart';
import '../widgets/inventory_snack.dart';

class AddRawMaterialDialog extends StatefulWidget {
  const AddRawMaterialDialog({super.key});

  @override
  State<AddRawMaterialDialog> createState() => _AddRawMaterialDialogState();
}

class _AddRawMaterialDialogState extends State<AddRawMaterialDialog> {
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController(text: 'كجم');
  RawCategory _category = RawCategory.proteins;
  String? _skuError;

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _save() {
    final sku = _skuController.text.trim();
    final name = _nameController.text.trim();
    final stockStr = _stockController.text.trim();
    final unit = _unitController.text.trim();

    if (sku.isEmpty || name.isEmpty || stockStr.isEmpty || unit.isEmpty) {
      return;
    }

    final stock = double.tryParse(stockStr) ?? 0;
    final cubit = context.read<InventoryCubit>();

    final material = RawMaterial(
      sku: sku,
      name: name,
      category: _category,
      categoryLabel: _category.label,
      stock: stock,
      minLevel: 10, // Default minimum level
      icon: Icons.inventory_2, // Default icon
      unit: unit,
    );

    final success = cubit.addRawMaterial(material);

    if (success) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تمت إضافة $name بنجاح');
      }
    } else {
      setState(() {
        _skuError = 'هذا الكود مستخدم بالفعل';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          'إضافة خامة جديدة',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _skuController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'رمز SKU',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    errorText: _skuError,
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  onChanged: (_) {
                    if (_skuError != null) setState(() => _skuError = null);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'اسم الخامة',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RawCategory>(
                  initialValue: _category,
                  dropdownColor: AppColors.surfaceContainerHigh,
                  items: RawCategory.values.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.label, style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'الفئة',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'الرصيد الافتتاحي',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'الوحدة',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
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
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              'إضافة',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
