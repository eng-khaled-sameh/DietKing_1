import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ClosingsExcelExportService — تصدير تقارير الإقفالات والعجوزات إلى Excel
/// ═══════════════════════════════════════════════════════════════════
class ClosingsExcelExportService {
  ClosingsExcelExportService._();

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
  static const String _cDiffDeficit = '#721C24'; // عجز (أحمر)
  static const String _cDiffDeficitBg = '#F8D7DA';
  static const String _cDiffSurplus = '#155724'; // فائض (أخضر)
  static const String _cDiffSurplusBg = '#D4EDDA';

  // أعراض الأعمدة (A..P)
  static const List<double> _colWidths = [
    6,  // A: م
    18, // B: الفرع
    16, // C: الكاشير
    12, // D: الوردية
    18, // E: تاريخ ووقت الإغلاق
    16, // F: إجمالي المبيعات
    15, // G: مبيعات الكاش
    15, // H: مبيعات الشبكة
    14, // I: رصيد الافتتاح
    15, // J: الكاش المتوقع
    15, // K: الكاش الفعلي المعدود
    18, // L: الفرق (عجز/فائض)
    14, // M: حالة المراجعة
    14, // N: إجراء HR
    15, // O: العجز المعتمد
    28, // P: ملاحظات المراجعة
  ];

  static Future<String?> exportClosingsReport({
    required List<Map<String, dynamic>> closings,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير الإقفالات والعجوزات';
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
    final mainTitle = 'تقرير إقفالات الصناديق والعجوزات — دايت كنج ($effectiveBranch)';

    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 15,
      value: mainTitle,
      bold: true,
      fontSize: 14,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 32,
    );
    row++;

    // ── 2. الفترة الزمنية ومعلومات التقرير ───────────────────────
    final subTitle =
        'الفترة: من ${_df.format(startDate)} إلى ${_df.format(endDate)}   |   تاريخ الاستخراج: ${_dtf.format(DateTime.now())}   |   إجمالي الإقفالات: ${closings.length}';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 15,
      value: subTitle,
      bold: false,
      fontSize: 10,
      bgHex: _cSubHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت مؤشرات الأداء المالي (KPIs) ──────────────────────
    double sumTotalSales = 0;
    double sumCashSales = 0;
    double sumCardSales = 0;
    double sumDeficits = 0;
    double sumSurpluses = 0;
    int reviewedCount = 0;
    int hrPendingCount = 0;

    for (final c in closings) {
      final tot = (c['total_sales'] as num?)?.toDouble() ?? 0;
      final cash = (c['cash_sales'] as num?)?.toDouble() ?? 0;
      final card = (c['card_sales'] as num?)?.toDouble() ?? 0;
      final diff = (c['difference'] as num?)?.toDouble() ?? 0;
      final rev = c['review'] as Map<String, dynamic>?;

      sumTotalSales += tot;
      sumCashSales += cash;
      sumCardSales += card;

      if (diff < 0) sumDeficits += diff.abs();
      if (diff > 0) sumSurpluses += diff;

      if (rev != null) {
        reviewedCount++;
        final dedStatus = rev['deduction_status'] as String?;
        if (dedStatus == 'pending') hrPendingCount++;
      }
    }

    _styleCell(sh, col: 0, row: row, value: 'المؤشر', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي المبيعات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'مبيعات الكاش', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'مبيعات الشبكة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'مجموع العجوزات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'مجموع الفوائض', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 6, row: row, value: 'مراجعة محاسبياً', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 7, row: row, value: 'معلق بانتظار HR', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    _styleCell(sh, col: 0, row: row, value: 'القيمة', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: _money.format(sumTotalSales), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumCashSales), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 3, row: row, value: _money.format(sumCardSales), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 4, row: row, value: _money.format(sumDeficits), bold: true, bgHex: _cDiffDeficitBg, fgHex: _cDiffDeficit);
    _styleCell(sh, col: 5, row: row, value: _money.format(sumSurpluses), bold: true, bgHex: _cDiffSurplusBg, fgHex: _cDiffSurplus);
    _styleCell(sh, col: 6, row: row, value: '$reviewedCount من ${closings.length}', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 7, row: row, value: '$hrPendingCount إقفال', bold: true, bgHex: _cKpiBg);
    row += 2;

    // ── 4. ترويسة جدول الإقفالات ─────────────────────────────────
    final tableHeaders = [
      'م',
      'الفرع',
      'الكاشير',
      'الوردية',
      'تاريخ الإغلاق',
      'إجمالي المبيعات',
      'مبيعات الكاش',
      'مبيعات الشبكة',
      'رصيد الافتتاح',
      'الكاش المتوقع',
      'الكاش الفعلي',
      'الفرق (عجز / فائض)',
      'حالة المراجعة',
      'إجراء HR',
      'العجز المعتمد',
      'ملاحظات / سبب المراجعة',
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

    // ── 5. تعبئة صفوف الإقفالات ──────────────────────────────────
    for (int i = 0; i < closings.length; i++) {
      final c = closings[i];
      final bg = i.isEven ? '#FFFFFF' : _cAltRow;

      final branch = c['branch_name'] as String? ?? '—';
      final cashier = c['cashier_name'] as String? ?? '—';
      final shift = c['shift'] as String? ?? '—';
      final closedAtRaw = DateTime.tryParse(c['closed_at'] as String? ?? '');
      final closedAtStr = closedAtRaw != null ? _dtf.format(closedAtRaw.toLocal()) : '—';

      final totalSales = (c['total_sales'] as num?)?.toDouble() ?? 0;
      final cashSales = (c['cash_sales'] as num?)?.toDouble() ?? 0;
      final cardSales = (c['card_sales'] as num?)?.toDouble() ?? 0;
      final openingCash = (c['opening_cash'] as num?)?.toDouble() ?? 0;
      final expectedCash = (c['expected_cash'] as num?)?.toDouble() ?? 0;
      final countedCash = (c['counted_cash'] as num?)?.toDouble() ?? 0;
      final diff = (c['difference'] as num?)?.toDouble() ?? 0;

      final review = c['review'] as Map<String, dynamic>?;
      final reviewed = review != null;
      final dedStatus = review?['deduction_status'] as String?;
      final reviewedDiff = (review?['reviewed_difference'] as num?)?.toDouble();
      final notes = review?['accountant_notes'] as String? ?? review?['review_reason'] as String? ?? '—';

      String diffStr;
      String diffFg = '#000000';
      if (diff == 0) {
        diffStr = 'متوازن (0.00)';
        diffFg = '#2E7D32';
      } else if (diff < 0) {
        diffStr = 'عجز -${_money.format(diff.abs())}';
        diffFg = _cDiffDeficit;
      } else {
        diffStr = 'فائض +${_money.format(diff)}';
        diffFg = _cDiffSurplus;
      }

      String reviewLabel = reviewed ? 'مراجَع' : 'غير مراجَع';
      String hrLabel = '—';
      if (dedStatus == 'approved') {
        hrLabel = 'خصم معتمد';
      } else if (dedStatus == 'pending') {
        hrLabel = 'معلق HR';
      } else if (dedStatus == 'rejected') {
        hrLabel = 'خصم مرفوض';
      }

      final rowCells = [
        '${i + 1}',
        branch,
        cashier,
        shift,
        closedAtStr,
        _money.format(totalSales),
        _money.format(cashSales),
        _money.format(cardSales),
        _money.format(openingCash),
        _money.format(expectedCash),
        _money.format(countedCash),
        diffStr,
        reviewLabel,
        hrLabel,
        reviewedDiff != null ? _money.format(reviewedDiff) : '—',
        notes,
      ];

      for (int colIdx = 0; colIdx < rowCells.length; colIdx++) {
        _styleCell(
          sh,
          col: colIdx,
          row: row,
          value: rowCells[colIdx],
          bold: colIdx == 11,
          fontSize: 10,
          bgHex: bg,
          fgHex: colIdx == 11 ? diffFg : '#2A2E3D',
          hAlign: (colIdx == 0 || colIdx == 3 || colIdx == 4 || colIdx >= 12)
              ? HorizontalAlign.Center
              : (colIdx >= 5 && colIdx <= 11 ? HorizontalAlign.Center : HorizontalAlign.Right),
          border: true,
        );
      }
      sh.setRowHeight(row, 22);
      row++;
    }

    // ── 6. صف الإجماليات النهائية ───────────────────────────────
    final totalsRow = [
      'الإجمالي',
      '${closings.length} إقفال',
      '',
      '',
      '',
      _money.format(sumTotalSales),
      _money.format(sumCashSales),
      _money.format(sumCardSales),
      '',
      '',
      '',
      'عجز: -${_money.format(sumDeficits)} | فائض: +${_money.format(sumSurpluses)}',
      '$reviewedCount مراجع',
      '$hrPendingCount معلق',
      '',
      '',
    ];

    for (int colIdx = 0; colIdx < totalsRow.length; colIdx++) {
      _styleCell(
        sh,
        col: colIdx,
        row: row,
        value: totalsRow[colIdx],
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
        'DietKing_إقفالات_${safeBranch}_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
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
        dialogTitle: 'حفظ تقرير الإقفالات Excel',
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
