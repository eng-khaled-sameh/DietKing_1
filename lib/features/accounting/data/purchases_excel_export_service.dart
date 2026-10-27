import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PurchasesExcelExportService — تصدير تقارير المشتريات وطلبات التوريد
/// ═══════════════════════════════════════════════════════════════════
class PurchasesExcelExportService {
  PurchasesExcelExportService._();

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

  // أعراض الأعمدة (A..K)
  static const List<double> _colWidths = [
    6,  // A: م
    16, // B: رقم طلب التوريد
    20, // C: المورد
    16, // D: هاتف المورد
    12, // E: الأولوية
    16, // F: الحالة
    16, // G: تاريخ الإنشاء
    16, // H: تاريخ التوريد المتوقع
    55, // I: المنتجات والأصناف الموردة والكميات والتكلفة (عرض واسع للنقر والتمدد)
    18, // J: إجمالي التكلفة المقدرة (ر.س)
    25, // K: ملاحظات الطلب
  ];

  static Future<String?> exportPurchasesReport({
    required List<Map<String, dynamic>> orders,
    String? statusFilter,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير المشتريات والتوريد';
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
    const mainTitle = 'تقرير طلبات التوريد والمشتريات للمستودع العام — دايت كنج';

    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 10,
      value: mainTitle,
      bold: true,
      fontSize: 14,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 32,
    );
    row++;

    // ── 2. معلومات التقرير ───────────────────────────────────────
    final statusText = (statusFilter != null && statusFilter.isNotEmpty)
        ? '   |   تصفية الحالة: $statusFilter'
        : '   |   الحالة: جميع الحالات';
    final subTitle =
        'المشتريات العامة (المستودع الرئيسي)   |   تاريخ الاستخراج: ${_dtf.format(DateTime.now())}   |   إجمالي الطلبات: ${orders.length}$statusText';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 10,
      value: subTitle,
      bold: false,
      fontSize: 10,
      bgHex: _cSubHeaderBg,
      fgHex: _cHeaderFg,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت مؤشرات الأداء (KPIs) ────────────────────────────
    int pendingCount = 0;
    int approvedCount = 0;
    int receivedCount = 0;
    int rejectedCount = 0;
    double sumEstimatedCost = 0;

    for (final o in orders) {
      final st = (o['status'] as String? ?? '').toLowerCase();
      if (st == 'pending_review') {
        pendingCount++;
      } else if (st == 'approved') {
        approvedCount++;
      } else if (st == 'received') {
        receivedCount++;
      } else if (st == 'rejected') {
        rejectedCount++;
      }

      final lines = (o['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final l in lines) {
        final q = (l['qty_approved'] ?? l['qty_requested'] as num?)?.toDouble() ?? 0;
        final c = (l['unit_cost'] as num?)?.toDouble() ?? 0;
        sumEstimatedCost += (q * c);
      }
    }

    _styleCell(sh, col: 0, row: row, value: 'المؤشر', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي الطلبات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'قيد المراجعة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'معتمد (بانتظار الاستلام)', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'مستلم بالمستودع', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'مرفوض / ملغى', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 6, row: row, value: 'إجمالي التكلفة المقدرة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    _styleCell(sh, col: 0, row: row, value: 'القيمة', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: '${orders.length} طلب', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: '$pendingCount طلب', bold: true, bgHex: '#FFF3CD', fgHex: '#856404');
    _styleCell(sh, col: 3, row: row, value: '$approvedCount طلب', bold: true, bgHex: '#D1ECF1', fgHex: '#0C5460');
    _styleCell(sh, col: 4, row: row, value: '$receivedCount طلب', bold: true, bgHex: '#D4EDDA', fgHex: '#155724');
    _styleCell(sh, col: 5, row: row, value: '$rejectedCount طلب', bold: true, bgHex: '#F8D7DA', fgHex: '#721C24');
    _styleCell(sh, col: 6, row: row, value: _money.format(sumEstimatedCost), bold: true, bgHex: _cKpiBg);
    row += 2;

    // ── 4. ترويسة جدول طلبات التوريد ────────────────────────────
    final tableHeaders = [
      'م',
      'رقم طلب التوريد',
      'المورد',
      'هاتف المورد',
      'الأولوية',
      'الحالة',
      'تاريخ الإنشاء',
      'تاريخ التوريد المتوقع',
      'المنتجات والأصناف الموردة (انقر على الخلية لعرض التفاصيل الكاملة)',
      'إجمالي التكلفة (ر.س)',
      'ملاحظات الطلب',
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

    // ── 5. تعبئة صفوف طلبات التوريد ─────────────────────────────
    for (int i = 0; i < orders.length; i++) {
      final o = orders[i];
      final bg = i.isEven ? '#FFFFFF' : _cAltRow;

      final number = o['number'] as String? ?? '—';
      final supplier = o['supplier_name'] as String? ?? '—';
      final phone = o['supplier_phone'] as String? ?? '—';
      final priority = o['priority'] == 'urgent' ? 'عاجل ⚠️' : 'عادي';
      final statusRaw = (o['status'] as String? ?? '').toLowerCase();

      String statusLabel;
      String statusFg = '#000000';
      if (statusRaw == 'approved') {
        statusLabel = 'معتمد';
        statusFg = '#0C5460';
      } else if (statusRaw == 'received') {
        statusLabel = 'مستلم';
        statusFg = '#155724';
      } else if (statusRaw == 'rejected') {
        statusLabel = 'مرفوض';
        statusFg = '#721C24';
      } else if (statusRaw == 'cancelled') {
        statusLabel = 'ملغى';
        statusFg = '#8A92A3';
      } else {
        statusLabel = 'قيد المراجعة';
        statusFg = '#856404';
      }

      final createdRaw = DateTime.tryParse(o['created_at'] as String? ?? '');
      final createdStr = createdRaw != null ? _df.format(createdRaw.toLocal()) : '—';

      final expectedRaw = DateTime.tryParse(o['expected_date'] as String? ?? '');
      final expectedStr = expectedRaw != null ? _df.format(expectedRaw.toLocal()) : '—';

      final notes = o['notes'] as String? ?? '—';

      // تجهيز المنتجات والأصناف داخل الخلية مع bullet points والتكلفة
      final lines = (o['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      double orderTotal = 0;

      final formattedLines = lines.map((l) {
        final itemName = l['item_name'] as String? ?? 'صنف';
        final unit = l['unit_code'] ?? l['unit'] ?? '';
        final qReq = l['qty_requested'] ?? 0;
        final qApp = l['qty_approved'];
        final qRec = l['qty_received'];
        final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0;

        final effectiveQty = (qApp ?? qReq as num?)?.toDouble() ?? 0;
        final lineTotal = effectiveQty * cost;
        orderTotal += lineTotal;

        final unitText = unit.toString().isNotEmpty ? ' ($unit)' : '';
        String qtyText = 'مطلوب: $qReq';
        if (qApp != null) qtyText += ' | معتمد: $qApp';
        if (qRec != null) qtyText += ' | مستلم: $qRec';

        final costText = cost > 0 ? ' — التكلفة: ${_money.format(cost)} ر.س' : '';
        final totalText = lineTotal > 0 ? ' (إجمالي: ${_money.format(lineTotal)})' : '';

        return '• $itemName$unitText — $qtyText$costText$totalText';
      }).join('\r\n');

      final itemsCellText = formattedLines.isEmpty ? '—' : formattedLines;

      final rowCells = [
        '${i + 1}',
        number,
        supplier,
        phone,
        priority,
        statusLabel,
        createdStr,
        expectedStr,
        itemsCellText,
        _money.format(orderTotal),
        notes,
      ];

      for (int c = 0; c < rowCells.length; c++) {
        _styleCell(
          sh,
          col: c,
          row: row,
          value: rowCells[c],
          bold: c == 9,
          fontSize: 10,
          bgHex: bg,
          fgHex: c == 5 ? statusFg : (c == 4 && priority.contains('عاجل') ? '#B71C1C' : '#2A2E3D'),
          hAlign: (c == 0 || c == 3 || c == 4 || c == 5 || c == 6 || c == 7)
              ? HorizontalAlign.Center
              : (c == 9 ? HorizontalAlign.Center : HorizontalAlign.Right),
          border: true,
          wrap: c == 8, // التفاف النص لتعدد أسطر المنتجات
        );
      }

      final lineCount = lines.isEmpty ? 1 : lines.length;
      final rowHeight = lineCount > 1 ? (lineCount * 18.0) : 22.0;
      sh.setRowHeight(row, rowHeight);
      row++;
    }

    // ── 6. صف الإجمالي النهائي ────────────────────────────────
    final totalsRow = [
      'الإجمالي',
      '${orders.length} طلب توريد',
      '',
      '',
      '',
      'مستلم: $receivedCount | معتمد: $approvedCount',
      '',
      '',
      '',
      _money.format(sumEstimatedCost),
      '',
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

    final fileName = 'DietKing_مشتريات_المستودع_${_df.format(DateTime.now())}.xlsx';
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
    bool wrap = false,
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
      textWrapping: wrap ? TextWrapping.WrapText : TextWrapping.Clip,
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
        dialogTitle: 'حفظ تقرير المشتريات Excel',
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
