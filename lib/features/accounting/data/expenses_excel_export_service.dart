import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ExpensesExcelExportService — تصدير تقارير المصروفات إلى Excel
/// ═══════════════════════════════════════════════════════════════════
class ExpensesExcelExportService {
  ExpensesExcelExportService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // الألوان الرسمية
  static const String _cHeaderBg = '#1B365D';    // نيلي داكن
  static const String _cHeaderFg = '#FFFFFF';    // أبيض
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cKpiBg = '#EBF3FA';       // خلفية كروت الملخص
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cAltRow = '#F8FAFC';      // صف متبادل

  // أعراض الأعمدة (A..L)
  static const List<double> _colWidths = [
    6,  // A: م
    16, // B: رقم الفاتورة / السند
    18, // C: الفرع
    18, // D: التصنيف / البند
    28, // E: البيان / الوصف
    16, // F: تم الصرف بواسطة
    14, // G: طريقة الدفع
    18, // H: التاريخ والوقت
    16, // I: المبلغ قبل الضريبة
    14, // J: ضريبة القيمة المضافة
    18, // K: الإجمالي شامل الضريبة
    14, // L: الحالة
  ];

  static Future<String?> exportExpensesReport({
    required List<Map<String, dynamic>> expenses,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
    String? categoryFilter,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير المصروفات';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // ضبط أعراض الأعمدة
    for (int i = 0; i < _colWidths.length; i++) {
      sh.setColumnWidth(i, _colWidths[i]);
    }

    int row = 0;

    // ── 1. العنوان الرئيسي ──────────────────────────────────────
    final effectiveBranch = (branchName != null && branchName.trim().isNotEmpty)
        ? branchName.trim()
        : 'جميع الفروع';
    final mainTitle = 'تقرير المصروفات — دايت كنج ($effectiveBranch)';

    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 11,
      value: mainTitle,
      bold: true,
      fontSize: 14,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 32,
    );
    row++;

    // ── 2. الفترة الزمنية ومعلومات التقرير ───────────────────────
    final catInfo = (categoryFilter != null && categoryFilter.isNotEmpty)
        ? '   |   التصنيف: $categoryFilter'
        : '';
    final subTitle =
        'الفترة: من ${_df.format(startDate)} إلى ${_df.format(endDate)}   |   تاريخ الاستخراج: ${_dtf.format(DateTime.now())}   |   إجمالي الفواتير: ${expenses.length}$catInfo';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 11,
      value: subTitle,
      bold: false,
      fontSize: 10,
      bgHex: _cSubHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت مؤشرات الأداء المالي (KPIs) ──────────────────────
    double sumTotal = 0;
    double sumSubtotal = 0;
    double sumVat = 0;
    double sumCash = 0;
    double sumCard = 0;
    int approvedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;

    for (final e in expenses) {
      final t = (e['total'] as num?)?.toDouble() ?? 0;
      final v = (e['vat_amount'] as num?)?.toDouble() ?? 0;
      final sub = (e['subtotal'] as num?)?.toDouble() ?? (t - v);
      final st = (e['status'] as String? ?? 'pending').toLowerCase();
      final m = (e['payment_method'] as String? ?? '').toLowerCase();

      final isCash = m.contains('cash') || m.contains('كاش') || m.contains('نقد');
      final isCard = m.contains('card') || m.contains('visa') || m.contains('شبك') || m.contains('مدى') || m.contains('pos') || m.contains('بنك') || m.contains('bank');

      sumTotal += t;
      sumSubtotal += sub;
      sumVat += v;

      if (isCash) {
        sumCash += t;
      } else if (isCard) {
        sumCard += t;
      }

      if (st == 'approved' || st == 'posted') {
        approvedCount++;
      } else if (st == 'rejected') {
        rejectedCount++;
      } else {
        pendingCount++;
      }
    }

    _styleCell(sh, col: 0, row: row, value: 'المؤشر', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي المصروفات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'المجموع قبل الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'إجمالي الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'مصروفات كاش', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'مصروفات شبكة/بنكي', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 6, row: row, value: 'معتمد', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 7, row: row, value: 'معلق', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 8, row: row, value: 'مرفوض', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    _styleCell(sh, col: 0, row: row, value: 'القيمة', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: _money.format(sumTotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumSubtotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 3, row: row, value: _money.format(sumVat), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 4, row: row, value: _money.format(sumCash), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 5, row: row, value: _money.format(sumCard), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 6, row: row, value: '$approvedCount مصروف', bold: true, bgHex: '#D4EDDA', fgHex: '#155724');
    _styleCell(sh, col: 7, row: row, value: '$pendingCount معلق', bold: true, bgHex: '#FFF3CD', fgHex: '#856404');
    _styleCell(sh, col: 8, row: row, value: '$rejectedCount مرفوض', bold: true, bgHex: '#F8D7DA', fgHex: '#721C24');
    row += 2;

    // ── 4. ترويسة جدول المصروفات ─────────────────────────────────
    final tableHeaders = [
      'م',
      'رقم الفاتورة / السند',
      'الفرع',
      'التصنيف / البند',
      'البيان / الوصف',
      'تم الصرف بواسطة',
      'طريقة الدفع',
      'التاريخ والوقت',
      'قبل الضريبة',
      'ضريبة القيمة المضافة',
      'الإجمالي (ر.س)',
      'الحالة',
    ];

    for (int c = 0; c < tableHeaders.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: tableHeaders[c],
        bold: true,
        fontSize: 10,
        bgHex: _cHeaderBg,
        fgHex: _cHeaderFg,
        border: true,
      );
    }
    sh.setRowHeight(row, 26);
    row++;

    // ── 5. تعبئة صفوف المصروفات ──────────────────────────────────
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final bg = i.isEven ? '#FFFFFF' : _cAltRow;

      final invoiceNum = e['invoice_number'] as String? ?? e['number'] as String? ?? '—';
      final branch = e['branch_name'] as String? ?? 'الفرع الرئيسي';
      final category = e['category'] as String? ?? 'أخرى';
      final desc = e['description'] as String? ?? e['notes'] as String? ?? '—';
      final creator = e['creator_name'] as String? ?? e['user_name'] as String? ?? '—';

      final method = (e['payment_method'] as String? ?? '').toLowerCase();
      final isCash = method.contains('cash') || method.contains('كاش') || method.contains('نقد');
      final isCard = method.contains('card') || method.contains('visa') || method.contains('شبك') || method.contains('مدى') || method.contains('بنك');
      final methodLabel = isCash ? 'كاش' : isCard ? 'شبكة / بنكي' : (method.isNotEmpty ? method : '—');

      final dateRaw = DateTime.tryParse(e['expense_date'] as String? ?? e['created_at'] as String? ?? '');
      final dateStr = dateRaw != null ? _dtf.format(dateRaw.toLocal()) : '—';

      final total = (e['total'] as num?)?.toDouble() ?? 0;
      final vat = (e['vat_amount'] as num?)?.toDouble() ?? 0;
      final subtotal = (e['subtotal'] as num?)?.toDouble() ?? (total - vat);

      final statusRaw = (e['status'] as String? ?? 'pending').toLowerCase();
      String statusLabel;
      String statusFg = '#000000';
      if (statusRaw == 'approved' || statusRaw == 'posted') {
        statusLabel = 'معتمد';
        statusFg = '#155724';
      } else if (statusRaw == 'rejected') {
        statusLabel = 'مرفوض';
        statusFg = '#721C24';
      } else {
        statusLabel = 'قيد المراجعة';
        statusFg = '#856404';
      }

      final rowCells = [
        '${i + 1}',
        invoiceNum,
        branch,
        category,
        desc,
        creator,
        methodLabel,
        dateStr,
        _money.format(subtotal),
        _money.format(vat),
        _money.format(total),
        statusLabel,
      ];

      for (int c = 0; c < rowCells.length; c++) {
        _styleCell(
          sh,
          col: c,
          row: row,
          value: rowCells[c],
          bold: c == 10,
          fontSize: 10,
          bgHex: bg,
          fgHex: c == 11 ? statusFg : (c == 10 ? '#000000' : '#2A2E3D'),
          hAlign: (c == 0 || c == 6 || c == 7 || c == 11)
              ? HorizontalAlign.Center
              : (c >= 8 && c <= 10 ? HorizontalAlign.Center : HorizontalAlign.Right),
          border: true,
        );
      }
      sh.setRowHeight(row, 22);
      row++;
    }

    // ── 6. صف الإجمالي النهائي ────────────────────────────────
    final totalsRow = [
      'الإجمالي',
      '${expenses.length} مصروف',
      '',
      '',
      '',
      '',
      '',
      '',
      _money.format(sumSubtotal),
      _money.format(sumVat),
      _money.format(sumTotal),
      'معتمد: $approvedCount | معلق: $pendingCount',
    ];

    for (int c = 0; c < totalsRow.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: totalsRow[c],
        bold: true,
        fontSize: 10,
        bgHex: _cTotalBg,
        fgHex: '#000000',
        hAlign: HorizontalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 24);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل تحويل ملف Excel إلى بايتات');

    final safeBranch = effectiveBranch.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
    final fileName =
        'DietKing_مصروفات_${safeBranch}_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _saveFile(bytes, fileName);
  }

  // ── أدوات تنسيق الخلايا ───────────────────────────────────────
  static void _styleCell(
    Sheet sh, {
    required int col,
    required int row,
    required String value,
    bool bold = false,
    double fontSize = 10,
    String fgHex = '#000000',
    String bgHex = '#FFFFFF',
    HorizontalAlign hAlign = HorizontalAlign.Center,
    VerticalAlign vAlign = VerticalAlign.Center,
    bool border = false,
  }) {
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);

    final cellBorder = border
        ? Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#D0D5DD'),
          )
        : null;

    cell.cellStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      bold: bold,
      fontSize: fontSize.toInt(),
      fontColorHex: ExcelColor.fromHexString(fgHex),
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      horizontalAlign: hAlign,
      verticalAlign: vAlign,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );
  }

  static void _setMergedCell(
    Sheet sh, {
    required int col,
    required int row,
    required int toCol,
    required String value,
    bool bold = false,
    double fontSize = 11,
    String fgHex = '#FFFFFF',
    String bgHex = '#1B365D',
    HorizontalAlign hAlign = HorizontalAlign.Center,
    VerticalAlign vAlign = VerticalAlign.Center,
    double? rowHeight,
  }) {
    if (toCol > col) {
      sh.merge(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
      );
    }
    _styleCell(
      sh,
      col: col,
      row: row,
      value: value,
      bold: bold,
      fontSize: fontSize,
      fgHex: fgHex,
      bgHex: bgHex,
      hAlign: hAlign,
      vAlign: vAlign,
      border: true,
    );
    if (rowHeight != null) {
      sh.setRowHeight(row, rowHeight);
    }
  }

  static Future<String?> _saveFile(List<int> bytes, String fileName) async {
    String? outputPath;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير المصروفات Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
    }

    if (outputPath == null || outputPath.trim().isEmpty) {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();
      outputPath = '${dir.path}${Platform.pathSeparator}$fileName';
    }

    if (!outputPath.toLowerCase().endsWith('.xlsx')) {
      outputPath += '.xlsx';
    }

    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
    return outputPath;
  }
}
