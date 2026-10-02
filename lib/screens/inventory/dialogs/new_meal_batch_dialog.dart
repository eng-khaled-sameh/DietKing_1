import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';

class NewMealBatchDialog extends StatefulWidget {
  const NewMealBatchDialog({super.key});

  @override
  State<NewMealBatchDialog> createState() => _NewMealBatchDialogState();
}

class _NewMealBatchDialogState extends State<NewMealBatchDialog> {
  final _mealController = TextEditingController();
  final _quantityController = TextEditingController();
  final _productionLineController = TextEditingController();
  
  DateTime _producedAt = DateTime.now();
  late DateTime _expiresAt;

  @override
  void initState() {
    super.initState();
    _expiresAt = _producedAt.add(const Duration(hours: 48));
  }

  @override
  void dispose() {
    _mealController.dispose();
    _quantityController.dispose();
    _productionLineController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _save() {
    final meal = _mealController.text.trim();
    final qtyStr = _quantityController.text.trim();
    final prodLine = _productionLineController.text.trim();

    if (meal.isEmpty || qtyStr.isEmpty) return;
    
    if (_expiresAt.isBefore(_producedAt) || _expiresAt.isAtSameMomentAs(_producedAt)) {
      showInventorySnack(context, 'تاريخ الانتهاء يجب أن يكون بعد تاريخ الإنتاج', isError: true);
      return;
    }

    final quantity = int.tryParse(qtyStr) ?? 0;

    context.read<InventoryCubit>().createKitchenBatch(
          itemId: meal,
          quantity: quantity.toDouble(),
          qualityNote: prodLine.isEmpty ? null : prodLine,
          producedAt: _producedAt,
          expiresAt: _expiresAt,
        );

    Navigator.of(context).pop();
    showInventorySnack(context, 'تم تسجيل دفعة الإنتاج بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          'استلام دفعة إنتاج',
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
                  controller: _mealController,
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'الوجبة المجمعة (المنتج التام)',
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
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'الكمية المستلمة',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _productionLineController,
                        style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'خط الإنتاج / الشيف',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final dt = await _pickDateTime(_producedAt);
                    if (dt != null) {
                      setState(() {
                        _producedAt = dt;
                        _expiresAt = dt.add(const Duration(hours: 48));
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تاريخ ووقت الإنتاج',
                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    ),
                    child: Text(
                      '${_producedAt.year}-${_producedAt.month.toString().padLeft(2, '0')}-${_producedAt.day.toString().padLeft(2, '0')} ${_producedAt.hour.toString().padLeft(2, '0')}:${_producedAt.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final dt = await _pickDateTime(_expiresAt);
                    if (dt != null) {
                      setState(() {
                        _expiresAt = dt;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تاريخ الانتهاء الصلاحية',
                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                    ),
                    child: Text(
                      '${_expiresAt.year}-${_expiresAt.month.toString().padLeft(2, '0')}-${_expiresAt.day.toString().padLeft(2, '0')} ${_expiresAt.hour.toString().padLeft(2, '0')}:${_expiresAt.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                  ),
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
            child: Text('تسجيل الدفعة', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}
