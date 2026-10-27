import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// StockAuditExcelService
/// تصدير سجلات جرد المخزون والتدقيق ومطابقة العجز والخصومات لـ Excel
/// ═══════════════════════════════════════════════════════════════════
class StockAuditExcelService {
  StockAuditExcelService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  static const String _cHeaderBg = '#1B365D';    // كحلي داكن رسمي
  static const String _cHeaderFg = '#FFFFFF';
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cTotalFg = '#212529';
  static const String _cAltRow = '#F8FAFC';      // صف متبادل
  static const String _cDeductionBg = '#FCE8E6'; // أحمر فاتح للخصومات
  static const String _cDeductionFg = '#C5221F';
  static const String _cApprovedBg = '#E6F4EA';  // أخضر فاتح للمعتمد
  static const String _cApprovedFg = '#137333';
  static const String _cPendingBg = '#FEF7E0';   // أصفر فاتح لقيد المراجعة
  static const String _cPendingFg = '#B06000';

  static Future<String?> exportStockAuditsReport({
    required List<Map<String, dynamic>> audits,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'سجل جرد المخزون والخصومات';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // ضبط أعراض الأعمدة (A..P)
    final colWidths = [
      6.0,  // م
      16.0, // رقم الجرد
      18.0, // التاريخ والوقت
      12.0, // عدد الأصناف
      14.0, // صافي التعديل
      14.0, // إجمالي التالف
      16.0, // قيمة العجز (ر.س)
      16.0, // قيمة التالف (ر.س)
      18.0, // حالة المراجعة
      12.0, // تم خصم؟
      22.0, // الموظف المخصوم عليه
      18.0, // المسمى الوظيفي
      16.0, // قيمة الخصم (ر.س)
      28.0, // سبب وملاحظات الخصم
      18.0, // اسم المراجع
      26.0, // ملاحظات الجرد
    ];

    for (int i = 0; i < colWidths.length; i++) {
      sh.setColumnWidth(i, colWidths[i]);
    }

    int r = 0;

    // ── 1. ترويسة التقرير الرئيسية ───────────────────────────────────────────
    sh.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
             CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: r));
    _cell(sh, 0, r, 'شركة دي كينج - سجل جرد المخزون ومطابقة الأرصدة والخصومات',
        bg: _cHeaderBg, fg: _cHeaderFg, bold: true, size: 14, align: HorizontalAlign.Center);
    r++;

    final dateStr = (startDate != null && endDate != null)
        ? 'الفترة: ${DateFormat('yyyy-MM-dd').format(startDate)} إلى ${DateFormat('yyyy-MM-dd').format(endDate)}'
        : 'كافة عمليات الجرد المسجلة';
    sh.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
             CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: r));
    _cell(sh, 0, r, '$dateStr | تاريخ الاستخراج: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        bg: _cSubHeaderBg, fg: '#FFFFFF', size: 10, align: HorizontalAlign.Center);
    r += 2;

    // ── 2. صندوق الإحصائيات الموجزة ─────────────────────────────────────────
    int totalAudits = audits.length;
    int reviewedCount = 0;
    int pendingCount = 0;
    int withDeductionsCount = 0;
    double totalShortageVal = 0.0;
    double totalDamageVal = 0.0;
    double totalDeductionsVal = 0.0;

    for (final a in audits) {
      final status = a['review_status'] ?? 'pending_review';
      if (status == 'approved') reviewedCount++;
      if (status == 'approved_with_deduction') {
        reviewedCount++;
        withDeductionsCount++;
      }
      if (status == 'pending_review') pendingCount++;

      totalShortageVal += (a['shortage_value'] as num?)?.toDouble() ?? 0.0;
      totalDamageVal += (a['damage_value'] as num?)?.toDouble() ?? 0.0;
      totalDeductionsVal += (a['deduction_amount'] as num?)?.toDouble() ?? 0.0;
    }

    sh.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
             CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: r));
    _cell(sh, 0, r, 'ملخص مؤشرات جرد المخزون والتدقيق المالي',
        bg: _cSubHeaderBg, fg: '#FFFFFF', bold: true, size: 11, align: HorizontalAlign.Right);
    r++;

    final statHeaders = [
      'إجمالي عمليات الجرد',
      'معتمدة ومراجعة',
      'بانتظار المراجعة',
      'عمليات بها خصومات',
      'إجمالي قيمة العجز (ر.س)',
      'إجمالي قيمة التالف (ر.س)',
      'إجمالي الخصومات المفروضة (ر.س)',
    ];

    final statValues = [
      '$totalAudits عملية',
      '$reviewedCount',
      '$pendingCount',
      '$withDeductionsCount',
      _money.format(totalShortageVal),
      _money.format(totalDamageVal),
      _money.format(totalDeductionsVal),
    ];

    for (int i = 0; i < statHeaders.length; i++) {
      _cell(sh, i * 2, r, statHeaders[i], bg: '#E2E8F0', bold: true, size: 9, align: HorizontalAlign.Center);
      _cell(sh, i * 2 + 1, r, statValues[i], bg: '#FFFFFF', bold: true, size: 10, align: HorizontalAlign.Center);
    }
    r += 2;

    // ── 3. جدول تفاصيل الجرودات ─────────────────────────────────────────────
    final headers = [
      'م',
      'رقم الجرد',
      'التاريخ والوقت',
      'عدد الأصناف',
      'صافي التعديل',
      'إجمالي التالف',
      'قيمة العجز (ر.س)',
      'قيمة التالف (ر.س)',
      'حالة المراجعة',
      'تم خصم؟',
      'الموظف المخصوم عليه',
      'المسمى الوظيفي',
      'قيمة الخصم (ر.س)',
      'سبب وملاحظات الخصم',
      'اسم المراجع',
      'ملاحظات الجرد',
    ];

    for (int i = 0; i < headers.length; i++) {
      _cell(sh, i, r, headers[i], bg: _cHeaderBg, fg: _cHeaderFg, bold: true, size: 10, align: HorizontalAlign.Center);
    }
    r++;

    int idx = 1;
    for (final a in audits) {
      final isEven = idx % 2 == 0;
      final rowBg = isEven ? _cAltRow : '#FFFFFF';

      final dtStr = a['created_at'] != null ? _df.format(DateTime.parse(a['created_at'].toString()).toLocal()) : '';
      final itemsCount = (a['total_items'] as num?)?.toInt() ?? 0;
      final adjustQty = (a['total_adjust'] as num?)?.toDouble() ?? 0.0;
      final damageQty = (a['total_damage'] as num?)?.toDouble() ?? 0.0;
      final shortageVal = (a['shortage_value'] as num?)?.toDouble() ?? 0.0;
      final damageVal = (a['damage_value'] as num?)?.toDouble() ?? 0.0;
      final status = a['review_status'] ?? 'pending_review';
      final deductAmount = (a['deduction_amount'] as num?)?.toDouble() ?? 0.0;
      final empName = a['deduction_employee_name'] ?? '-';
      final empRole = _roleLabel(a['deduction_employee_role']);
      final notes = a['review_notes'] ?? '-';
      final reviewer = a['reviewer_name'] ?? '-';
      final stNotes = a['notes'] ?? '-';

      String statusText = 'قيد المراجعة';
      String statusBg = _cPendingBg;
      String statusFg = _cPendingFg;
      if (status == 'approved') {
        statusText = 'معتمد (بدون خصم)';
        statusBg = _cApprovedBg;
        statusFg = _cApprovedFg;
      } else if (status == 'approved_with_deduction') {
        statusText = 'معتمد (مع خصم)';
        statusBg = _cDeductionBg;
        statusFg = _cDeductionFg;
      }

      _cell(sh, 0, r, idx.toString(), bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 1, r, a['number'] ?? '-', bg: rowBg, bold: true, align: HorizontalAlign.Center);
      _cell(sh, 2, r, dtStr, bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 3, r, itemsCount.toString(), bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 4, r, (adjustQty > 0 ? '+' : '') + adjustQty.toStringAsFixed(1), bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 5, r, damageQty.toStringAsFixed(1), bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 6, r, _money.format(shortageVal), bg: rowBg, bold: shortageVal > 0, align: HorizontalAlign.Right);
      _cell(sh, 7, r, _money.format(damageVal), bg: rowBg, align: HorizontalAlign.Right);
      _cell(sh, 8, r, statusText, bg: statusBg, fg: statusFg, bold: true, align: HorizontalAlign.Center);
      _cell(sh, 9, r, deductAmount > 0 ? 'نعم' : 'لا', bg: deductAmount > 0 ? _cDeductionBg : rowBg,
          fg: deductAmount > 0 ? _cDeductionFg : '#000000', bold: deductAmount > 0, align: HorizontalAlign.Center);
      _cell(sh, 10, r, empName, bg: rowBg, bold: deductAmount > 0, align: HorizontalAlign.Right);
      _cell(sh, 11, r, empRole, bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 12, r, deductAmount > 0 ? _money.format(deductAmount) : '-', bg: deductAmount > 0 ? _cDeductionBg : rowBg,
          fg: deductAmount > 0 ? _cDeductionFg : '#000000', bold: deductAmount > 0, align: HorizontalAlign.Right);
      _cell(sh, 13, r, notes, bg: rowBg, align: HorizontalAlign.Right);
      _cell(sh, 14, r, reviewer, bg: rowBg, align: HorizontalAlign.Center);
      _cell(sh, 15, r, stNotes, bg: rowBg, align: HorizontalAlign.Right);

      r++;
      idx++;
    }

    // ── 4. صف الإجماليات ────────────────────────────────────────────────────
    sh.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
             CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r));
    _cell(sh, 0, r, 'الإجمالي العام لكافة الجرودات والخصومات:',
        bg: _cTotalBg, fg: _cTotalFg, bold: true, size: 10, align: HorizontalAlign.Center);

    _cell(sh, 6, r, _money.format(totalShortageVal), bg: _cTotalBg, fg: _cTotalFg, bold: true, align: HorizontalAlign.Right);
    _cell(sh, 7, r, _money.format(totalDamageVal), bg: _cTotalBg, fg: _cTotalFg, bold: true, align: HorizontalAlign.Right);
    _cell(sh, 8, r, '$totalAudits عملية', bg: _cTotalBg, fg: _cTotalFg, bold: true, align: HorizontalAlign.Center);
    _cell(sh, 9, r, '$withDeductionsCount خصم', bg: _cTotalBg, fg: _cTotalFg, bold: true, align: HorizontalAlign.Center);
    _cell(sh, 10, r, '-', bg: _cTotalBg, fg: _cTotalFg, align: HorizontalAlign.Center);
    _cell(sh, 11, r, '-', bg: _cTotalBg, fg: _cTotalFg, align: HorizontalAlign.Center);
    _cell(sh, 12, r, _money.format(totalDeductionsVal), bg: _cTotalBg, fg: _cTotalFg, bold: true, align: HorizontalAlign.Right);
    _cell(sh, 13, r, '-', bg: _cTotalBg, fg: _cTotalFg, align: HorizontalAlign.Center);
    _cell(sh, 14, r, '-', bg: _cTotalBg, fg: _cTotalFg, align: HorizontalAlign.Center);
    _cell(sh, 15, r, '-', bg: _cTotalBg, fg: _cTotalFg, align: HorizontalAlign.Center);

    // ── 5. الحفظ واختيار المسار ─────────────────────────────────────────────
    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final defaultFileName = 'جرد_المخزون_والخصومات_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    String? outputPath;
    try {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ شيت جرد المخزون والخصومات Excel',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
    } catch (_) {}

    if (outputPath == null || outputPath.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      outputPath = '${dir.path}${Platform.pathSeparator}$defaultFileName';
    }

    if (!outputPath.endsWith('.xlsx')) {
      outputPath = '$outputPath.xlsx';
    }

    final file = File(outputPath);
    await file.writeAsBytes(fileBytes, flush: true);
    return outputPath;
  }

  static String _roleLabel(String? role) {
    return switch (role) {
      'kitchen_worker' => 'عامل مطبخ',
      'chef'           => 'طاهي / شيف',
      'storekeeper'    => 'أمين مخزن',
      'worker'         => 'عامل تشغيل / مخزن',
      _                => role ?? '-',
    };
  }

  static void _cell(
    Sheet sh,
    int col,
    int row,
    String text, {
    String? bg,
    String? fg,
    bool bold = false,
    double size = 10,
    HorizontalAlign align = HorizontalAlign.Right,
  }) {
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(text);

    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: size.toInt(),
      fontColorHex: fg != null ? ExcelColor.fromHexString(fg) : ExcelColor.black,
      backgroundColorHex: bg != null ? ExcelColor.fromHexString(bg) : ExcelColor.white,
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D0D7DE')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D0D7DE')),
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D0D7DE')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D0D7DE')),
    );
  }
}
