import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/excel/inventory_excel_service.dart';
import '../../../../core/supabase_client.dart';
import '../../../../data/inventory/inventory_api.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _isLoading = false;
  String? _previewMessage;
  bool _isError = false;

  final _excelService = InventoryExcelService();
  final _api = InventoryApi(supabase);

  // ── تصدير نموذج فارغ ──────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final cubit = context.read<InventoryCubit>();
      final catalog = cubit.state.catalog;
      final bytes = _excelService.generateItemsTemplate(
        catalog?.categories ?? [],
        catalog?.units ?? [],
      );
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/items_template.xlsx');
      await file.writeAsBytes(bytes);
      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم حفظ النموذج في: ${file.path}');
      }
    } catch (e) {
      if (mounted) setState(() { _previewMessage = 'خطأ: $e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── استيراد Excel (dry-run ثم commit) ────────────────────────────────────
  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    setState(() { _isLoading = true; _previewMessage = null; });

    try {
      final expectedHeaders = [
        'كود الصنف (SKU)', 'اسم الصنف', 'التصنيف', 'وحدة القياس',
        'الحد الأدنى', 'الرصيد الافتتاحي', 'تكلفة الوحدة', 'متاح للفروع', 'نشط', 'ملاحظات'
      ];
      final rows = await _excelService.readAndNormalize(path, 'الأصناف', expectedHeaders);
      if (rows == null || rows.isEmpty) {
        setState(() { _previewMessage = 'الملف فارغ أو لا يحتوي ورقة "الأصناف"'; _isError = true; });
        return;
      }

      // تحويل إلى صيغة السيرفر
      final items = rows.map((r) => <String, dynamic>{
        'sku':        r['كود الصنف (SKU)'],
        'name':       r['اسم الصنف'],
        'cat_code':   r['التصنيف'],
        'unit_code':  r['وحدة القياس'],
        'min_level':  double.tryParse(r['الحد الأدنى'].toString()) ?? 0,
        'opening':    double.tryParse(r['الرصيد الافتتاحي'].toString()) ?? 0,
        'unit_cost':  double.tryParse(r['تكلفة الوحدة'].toString()),
        'for_branches': (r['متاح للفروع'] as String?) == 'نعم',
        'is_active':  (r['نشط'] as String?) != 'لا',
        'notes':      r['ملاحظات'],
      }).toList();

      // Dry-run: معاينة فقط
      final preview = await _api.importItems(dryRun: true, items: items, categories: []);
      if (!mounted) return;

      final inserted = preview['inserted'] ?? 0;
      final updated  = preview['updated']  ?? 0;
      final errors   = (preview['errors'] as List<dynamic>?) ?? [];

      if (errors.isNotEmpty) {
        setState(() {
          _previewMessage = 'يوجد ${errors.length} خطأ:\n${errors.take(3).join('\n')}';
          _isError = true;
        });
        return;
      }

      setState(() {
        _previewMessage = 'سيتم: إضافة $inserted صنف، تحديث $updated صنف.';
        _isError = false;
      });

      // طلب كلمة مرور المدير
      final password = await _showPasswordDialog();
      if (password == null || !mounted) return;

      final approval = await _api.requestAdminApproval(password, 'import_items');
      final token = approval['token'] as String?;
      if (token == null) {
        setState(() { _previewMessage = 'كلمة المرور خاطئة أو غير مخوّل'; _isError = true; });
        return;
      }

      // Commit
      await _api.importItems(dryRun: false, token: token, items: items, categories: []);
      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم الاستيراد: $inserted جديد، $updated محدّث');
      }
    } catch (e) {
      if (mounted) setState(() { _previewMessage = 'خطأ: $e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showPasswordDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text('تأكيد الإدارة',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'كلمة مرور المدير',
              labelStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('استيراد / تصدير الخامات',
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppColors.primary),
                  title: Text('تنزيل نموذج Excel',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                  subtitle: Text('يشمل التصنيفات والوحدات كمرجع',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant, fontSize: 12)),
                  onTap: _downloadTemplate,
                ),
                const Divider(color: AppColors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: AppColors.secondary),
                  title: Text('استيراد من Excel',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface)),
                  subtitle: Text('يطلب موافقة المدير قبل التطبيق',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant, fontSize: 12)),
                  onTap: _importExcel,
                ),
              ],
              if (_previewMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isError ? AppColors.statusRed : AppColors.statusGreen).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isError ? AppColors.statusRed : AppColors.statusGreen,
                    ),
                  ),
                  child: Text(
                    _previewMessage!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: _isError ? AppColors.statusRed : AppColors.statusGreen,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إغلاق',
                style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
