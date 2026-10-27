import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// InventoryProductsExcelService
/// تصدير شيتات Excel الاحترافية للمخزون والمنتجات التامة والوجبات
/// ═══════════════════════════════════════════════════════════════════
class InventoryProductsExcelService {
  InventoryProductsExcelService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // الألوان الرسمية المعتمدة
  static const String _cHeaderBg = '#1B365D';    // نيلي داكن رسمي
  static const String _cHeaderFg = '#FFFFFF';    // أبيض
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cKpiBg = '#EBF3FA';       // خلفية كروت الملخص
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cTotalFg = '#212529';
  static const String _cAltRow = '#F8FAFC';      // صف متبادل
  static const String _cProfitFg = '#155724';    // متوفر / نشط
  static const String _cWarningFg = '#856404';   // منخفض
  static const String _cAlertFg = '#721C24';     // نافد / متوقف

  // ═════════════════════════════════════════════════════════════════
  // 1. تصدير شيت جرد وأرصدة المخزون الرئيسي
  // ═════════════════════════════════════════════════════════════════
  static Future<String?> exportInventoryStockReport({
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? summary,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'مخزون المستودع';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // أعراض الأعمدة (A..J)
    final colWidths = [6.0, 16.0, 26.0, 18.0, 14.0, 16.0, 14.0, 18.0, 20.0, 16.0];
    for (int i = 0; i < colWidths.length; i++) {
      sh.setColumnWidth(i, colWidths[i]);
    }

    int row = 0;

    // ── 1. العنوان الرئيسي ──────────────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 9,
      value: 'شركة دايت كينج — تقرير جرد وأرصدة مخزون المستودع الرئيسي',
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 34,
    );
    row++;

    // ── 2. بيانات الاستخراج والفلترة ────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 4,
      value: 'المستودع الرئيسي | تاريخ الاستخراج: ${_dtf.format(DateTime.now())}',
      bold: true,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    _setMergedCell(
      sh,
      col: 5,
      row: row,
      toCol: 9,
      value: 'إجمالي عدد الأصناف المسجلة: ${items.length} صنف',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت الإجماليات والمؤشرات ────────────────────────────
    double totalStockVal = 0;
    int lowCount = 0;
    int outCount = 0;
    int availableCount = 0;

    for (final it in items) {
      final qty = (it['quantity'] ?? it['qty'] as num?)?.toDouble() ?? 0.0;
      final val = (it['total_value'] ?? it['stock_value'] as num?)?.toDouble() ??
          (qty * ((it['avg_cost'] as num?)?.toDouble() ?? 0.0));
      final isLow = it['is_low_stock'] == true;

      totalStockVal += val;
      if (qty <= 0) {
        outCount++;
      } else if (isLow) {
        lowCount++;
      } else {
        availableCount++;
      }
    }

    // ترويسات كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'المؤشر', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي الأصناف', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'القيمة المالية للمخزون', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'أصناف متوفرة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'أصناف منخفضة (تحت الحد)', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'أصناف نفدت بالكامل', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    // قيم كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'الإحصائية', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: '${items.length} صنف', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: _money.format(totalStockVal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 3, row: row, value: '$availableCount', bold: true, bgHex: _cKpiBg, fgHex: _cProfitFg);
    _styleCell(sh, col: 4, row: row, value: '$lowCount', bold: true, bgHex: _cKpiBg, fgHex: _cWarningFg);
    _styleCell(sh, col: 5, row: row, value: '$outCount', bold: true, bgHex: _cKpiBg, fgHex: _cAlertFg);
    row += 2;

    // ── 4. جدول الأصناف والأرصدة التفصيلي ───────────────────────
    final tableHeaders = [
      'م',
      'رمز الصنف (SKU)',
      'اسم الصنف / الخامة',
      'التصنيف',
      'وحدة القياس',
      'الرصيد الحالي المتوفر',
      'الحد الأدنى',
      'تكلفة الوحدة (ر.س)',
      'إجمالي القيمة (ر.س)',
      'حالة المخزون',
    ];

    for (int c = 0; c < tableHeaders.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: tableHeaders[c],
        bold: true,
        fontSize: 11,
        fgHex: _cHeaderFg,
        bgHex: _cHeaderBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 26);
    row++;

    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final isEven = (i % 2 == 0);
      final bg = isEven ? '#FFFFFF' : _cAltRow;

      final sku = it['sku'] as String? ?? it['code'] as String? ?? '—';
      final name = it['name'] as String? ?? '—';
      final category = it['category'] as String? ?? it['category_name'] as String? ?? '—';
      final unit = it['unit_code'] as String? ?? it['unit'] as String? ?? '—';
      final qty = (it['quantity'] ?? it['qty'] as num?)?.toDouble() ?? 0.0;
      final minLevel = (it['min_level'] as num?)?.toDouble() ?? 0.0;
      final avgCost = (it['avg_cost'] ?? it['cost'] as num?)?.toDouble() ?? 0.0;
      final val = (it['total_value'] ?? it['stock_value'] as num?)?.toDouble() ?? (qty * avgCost);
      final isLow = it['is_low_stock'] == true;

      String statusStr = 'متوفر';
      String statusFg = _cProfitFg;
      if (qty <= 0) {
        statusStr = 'نفد بالكامل';
        statusFg = _cAlertFg;
      } else if (isLow || (minLevel > 0 && qty <= minLevel)) {
        statusStr = 'منخفض (أقل من الحد)';
        statusFg = _cWarningFg;
      }

      final rowCells = [
        '${i + 1}',
        sku,
        name,
        category,
        unit,
        qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2),
        minLevel.toStringAsFixed(minLevel.truncateToDouble() == minLevel ? 0 : 2),
        _money.format(avgCost),
        _money.format(val),
        statusStr,
      ];

      for (int c = 0; c < rowCells.length; c++) {
        _styleCell(
          sh,
          col: c,
          row: row,
          value: rowCells[c],
          bold: c == 2 || c == 8 || c == 9,
          fontSize: 10,
          bgHex: bg,
          fgHex: c == 9 ? statusFg : (c == 8 ? '#000000' : '#2A2E3D'),
          hAlign: (c == 0 || c == 1 || c == 4 || c == 9)
              ? HorizontalAlign.Center
              : (c == 2 || c == 3 ? HorizontalAlign.Right : HorizontalAlign.Center),
          border: true,
        );
      }
      sh.setRowHeight(row, 22);
      row++;
    }

    // ── 5. صف الإجمالي النهائي ────────────────────────────────
    final totalsRow = [
      'الإجمالي',
      '${items.length} صنف',
      '',
      '',
      '',
      '',
      '',
      '',
      _money.format(totalStockVal),
      '',
    ];

    for (int c = 0; c < totalsRow.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: totalsRow[c],
        bold: true,
        fontSize: 11,
        fgHex: _cTotalFg,
        bgHex: _cTotalBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 28);

    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName = 'DietKing_مخزون_المستودع_${_df.format(DateTime.now())}.xlsx';
    return _saveFile(bytes, fileName, 'حفظ شيت مخزون المستودع');
  }

  // ═════════════════════════════════════════════════════════════════
  // 2. تصدير شيت المنتجات التامة وقائمة الوجبات والأسعار والتفاصيل
  // ═════════════════════════════════════════════════════════════════
  static Future<String?> exportFinishedProductsAndMealsReport({
    required List<Map<String, dynamic>> products,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'المنتجات التامة والوجبات';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // أعراض الأعمدة (A..I)
    final colWidths = [6.0, 16.0, 28.0, 18.0, 18.0, 20.0, 16.0, 38.0, 14.0];
    for (int i = 0; i < colWidths.length; i++) {
      sh.setColumnWidth(i, colWidths[i]);
    }

    int row = 0;

    // ── 1. العنوان الرئيسي ──────────────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 8,
      value: 'شركة دايت كينج — قائمة المنتجات التامة والوجبات والأسعار والتكاليف',
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 34,
    );
    row++;

    // ── 2. بيانات الاستخراج والفلترة ────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 4,
      value: 'قائمة الأصناف المعروضة | تاريخ الاستخراج: ${_dtf.format(DateTime.now())}',
      bold: true,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    _setMergedCell(
      sh,
      col: 5,
      row: row,
      toCol: 8,
      value: 'إجمالي عدد المنتجات والوجبات: ${products.length} منتج',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت الإجماليات والمؤشرات ────────────────────────────
    int activeCount = 0;
    int withVariantsCount = 0;
    int singlePriceCount = 0;

    for (final p in products) {
      final isActive = p['is_active'] != false;
      final hasVariants = p['has_variants'] == true;
      if (isActive) activeCount++;
      if (hasVariants) {
        withVariantsCount++;
      } else {
        singlePriceCount++;
      }
    }

    _styleCell(sh, col: 0, row: row, value: 'المؤشر', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي المنتجات/الوجبات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'منتجات نشطة بالمنيو', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'وجبات متعددة الأوزان/الخيارات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'أصناف ذات سعر موحد', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    _styleCell(sh, col: 0, row: row, value: 'الإحصائية', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: '${products.length}', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: '$activeCount', bold: true, bgHex: _cKpiBg, fgHex: _cProfitFg);
    _styleCell(sh, col: 3, row: row, value: '$withVariantsCount', bold: true, bgHex: _cKpiBg, fgHex: _cSubHeaderBg);
    _styleCell(sh, col: 4, row: row, value: '$singlePriceCount', bold: true, bgHex: _cKpiBg);
    row += 2;

    // ── 4. جدول المنتجات والوجبات ───────────────────────────────
    final tableHeaders = [
      'م',
      'كود الصنف (SKU)',
      'اسم المنتج / الوجبة',
      'التصنيف',
      'سعر البيع الأساسي (ر.س)',
      'تكلفة الوجبة (بدون مكسب) (ر.س)',
      'هامش الربح التقديري',
      'تفاصيل الأوزان والخيارات والأسعار (Variants)',
      'الحالة',
    ];

    for (int c = 0; c < tableHeaders.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: tableHeaders[c],
        bold: true,
        fontSize: 11,
        fgHex: _cHeaderFg,
        bgHex: _cHeaderBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 26);
    row++;

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final isEven = (i % 2 == 0);
      final bg = isEven ? '#FFFFFF' : _cAltRow;

      final sku = p['sku'] as String? ?? '—';
      final name = p['name'] as String? ?? '—';
      final category = p['category_name'] as String? ?? '—';
      final hasVariants = p['has_variants'] == true;
      final price = (p['price'] as num?)?.toDouble();
      final cost = (p['cost'] as num?)?.toDouble() ?? 0.0;
      final isActive = p['is_active'] != false;
      final variants = (p['variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      String priceStr = '—';
      String costStr = cost > 0 ? _money.format(cost) : '0.00';
      String marginStr = '—';

      if (hasVariants && variants.isNotEmpty) {
        final prices = variants.map((v) => (v['price'] as num?)?.toDouble() ?? 0.0).toList();
        final minP = prices.reduce((a, b) => a < b ? a : b);
        final maxP = prices.reduce((a, b) => a > b ? a : b);
        priceStr = minP == maxP ? _money.format(minP) : '${_money.format(minP)} ~ ${_money.format(maxP)}';
        marginStr = 'متعدد حسب الوزن';
      } else if (price != null && price > 0) {
        priceStr = _money.format(price);
        if (cost > 0 && price > cost) {
          final margin = ((price - cost) / price * 100);
          marginStr = '${margin.toStringAsFixed(1)}%';
        } else if (cost == 0) {
          marginStr = '100%';
        }
      }

      String variantsStr = 'سعر موحد';
      if (hasVariants && variants.isNotEmpty) {
        variantsStr = variants.map((v) {
          final label = v['label'] ?? 'خيار';
          final vPrice = (v['price'] as num?)?.toDouble() ?? 0.0;
          final vCost = (v['cost'] as num?)?.toDouble() ?? 0.0;
          if (vCost > 0) {
            return '• $label: ${_money.format(vPrice)} ر.س (تكلفة: ${_money.format(vCost)})';
          }
          return '• $label: ${_money.format(vPrice)} ر.س';
        }).join('\r\n');
      }

      final rowCells = [
        '${i + 1}',
        sku.isEmpty ? '—' : sku,
        name,
        category,
        priceStr,
        costStr,
        marginStr,
        variantsStr,
        isActive ? 'نشط' : 'متوقف',
      ];

      for (int c = 0; c < rowCells.length; c++) {
        _styleCell(
          sh,
          col: c,
          row: row,
          value: rowCells[c],
          bold: c == 2 || c == 4,
          fontSize: 10,
          bgHex: bg,
          fgHex: c == 8
              ? (isActive ? _cProfitFg : _cAlertFg)
              : (c == 4 ? '#1B365D' : '#2A2E3D'),
          hAlign: (c == 0 || c == 1 || c == 8)
              ? HorizontalAlign.Center
              : (c == 2 || c == 3 ? HorizontalAlign.Right : HorizontalAlign.Center),
          border: true,
          wrap: c == 7,
        );
      }

      final numLines = variants.length;
      final rowHeight = (hasVariants && numLines > 1) ? (numLines * 18.0) : 22.0;
      sh.setRowHeight(row, rowHeight);
      row++;
    }

    // صف ملخص
    _styleCell(sh, col: 0, row: row, value: 'Σ', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 1, row: row, value: 'الإجمالي', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 2, row: row, value: '${products.length} منتج ووجبة', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 3, row: row, value: '', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 4, row: row, value: '', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 5, row: row, value: '', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 6, row: row, value: '', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 7, row: row, value: '', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 8, row: row, value: '$activeCount نشط', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    sh.setRowHeight(row, 28);

    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName = 'DietKing_قائمة_المنتجات_والوجبات_${_df.format(DateTime.now())}.xlsx';
    return _saveFile(bytes, fileName, 'حفظ شيت المنتجات التامة والوجبات');
  }

  // ── أدوات المساعدة في التنسيق ─────────────────────────────────
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
      topBorder: cellBorder,
      bottomBorder: cellBorder,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      textWrapping: wrap ? TextWrapping.WrapText : TextWrapping.Clip,
    );
  }

  static void _setMergedCell(
    Sheet sh, {
    required int col,
    required int row,
    required int toCol,
    required String value,
    bool bold = false,
    double fontSize = 12,
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

  static Future<String?> _saveFile(List<int> bytes, String fileName, String dialogTitle) async {
    try {
      String? outputPath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
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
    } catch (e) {
      rethrow;
    }
  }
}
