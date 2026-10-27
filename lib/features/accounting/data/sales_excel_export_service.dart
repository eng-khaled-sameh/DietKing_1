import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// SalesExcelExportService — تصدير تقارير مبيعات الفروع بتنسيق Excel احترافي
/// ═══════════════════════════════════════════════════════════════════
class SalesExcelExportService {
  SalesExcelExportService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // الألوان الرسمية
  static const String _cHeaderBg = '#1B365D';    // نيلي داكن
  static const String _cHeaderFg = '#FFFFFF';    // أبيض
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cKpiBg = '#EBF3FA';       // خلفية كروت الملخص
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cTotalFg = '#212529';
  static const String _cAltRow = '#F8FAFC';      // صف متبادل
  static const String _cCashFg = '#155724';      // كاش
  static const String _cCardFg = '#0C5460';      // شبكة

  // أعراض الأعمدة (A..J)
  static const List<double> _colWidths = [
    6,  // A: م
    16, // B: رقم الفاتورة
    18, // C: الفرع
    16, // D: الكاشير
    12, // E: طريقة الدفع
    18, // F: التاريخ والوقت
    35, // G: الأصناف والكميات
    16, // H: قبل الضريبة
    14, // I: ضريبة القيمة المضافة
    18, // J: الإجمالي (ر.س)
  ];

  static Future<String?> exportSalesReport({
    required List<Map<String, dynamic>> sales,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
    Map<String, dynamic>? summary,
    bool includeInvoices = true,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = includeInvoices ? 'تقرير المبيعات التفصيلي' : 'ملخص المبيعات التنفيذي';
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
    final titleText = includeInvoices
        ? 'شركة دايت كينج — تقرير مبيعات الفروع المالي التفصيلي'
        : 'شركة دايت كينج — التقرير التنفيذي لملخص وإحصائيات المبيعات';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 9,
      value: titleText,
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 34,
    );
    row++;

    // ── 2. بيانات التقرير والفلترة ──────────────────────────────
    final targetBranch = (branchName != null && branchName.isNotEmpty)
        ? branchName
        : 'كافة الفروع';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 4,
      value: 'الفرع: $targetBranch | الفترة: ${_df.format(startDate)} إلى ${_df.format(endDate)}',
      bold: true,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    final invCount = summary != null && summary['invoices_count'] != null
        ? (summary['invoices_count'] as num).toInt()
        : sales.length;
    _setMergedCell(
      sh,
      col: 5,
      row: row,
      toCol: 9,
      value: 'تاريخ الاستخراج: ${_dtf.format(DateTime.now())}  |  عدد الفواتير: $invCount',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت الإجماليات والملخص ─────────────────────────────
    double sumTotal = (summary != null && summary['total_sales'] != null)
        ? (summary['total_sales'] as num).toDouble()
        : 0;
    double sumVat = (summary != null && summary['total_vat'] != null)
        ? (summary['total_vat'] as num).toDouble()
        : 0;
    double sumSubtotal = (summary != null && summary['gross_sales'] != null)
        ? (summary['gross_sales'] as num).toDouble()
        : 0;
    double sumCash = (summary != null && summary['cash_sales'] != null)
        ? (summary['cash_sales'] as num).toDouble()
        : 0;
    double sumCard = (summary != null && summary['card_sales'] != null)
        ? (summary['card_sales'] as num).toDouble()
        : 0;

    if (sales.isNotEmpty && (sumTotal == 0 && sumVat == 0 && sumSubtotal == 0)) {
      for (final s in sales) {
        final t = (s['total'] as num?)?.toDouble() ?? 0;
        final v = (s['vat_amount'] as num?)?.toDouble() ?? 0;
        final sub = (s['subtotal'] as num?)?.toDouble() ?? (t - v);
        final m = (s['payment_method'] as String? ?? '').toLowerCase();

        final isCash = m.contains('cash') || m.contains('كاش') || m.contains('نقد');
        final isCard = m.contains('card') || m.contains('visa') || m.contains('شبك') || m.contains('مدى') || m.contains('pos');

        sumTotal += t;
        sumVat += v;
        sumSubtotal += sub;
        if (isCash) {
          sumCash += t;
        } else if (isCard) {
          sumCard += t;
        }
      }
    } else if (sumSubtotal == 0 && sumTotal > 0) {
      sumSubtotal = sumTotal - sumVat;
    }

    double sumCost = (summary != null && summary['total_cost'] != null)
        ? (summary['total_cost'] as num).toDouble()
        : 0;
    double sumGrossProfit = (summary != null && summary['gross_profit'] != null)
        ? (summary['gross_profit'] as num).toDouble()
        : 0;

    if (sumCost == 0 && sales.isNotEmpty) {
      for (final s in sales) {
        final items = (s['items'] as List? ?? []);
        for (final it in items) {
          final q = (it['qty'] as num?)?.toDouble() ?? 1.0;
          final c = (it['unit_cost'] as num?)?.toDouble() ?? 0.0;
          sumCost += (q * c);
        }
      }
    }
    if (sumGrossProfit == 0 && sumTotal > 0) {
      sumGrossProfit = sumTotal - sumCost;
    }
    final profitMarginPct = sumTotal > 0 ? (sumGrossProfit / sumTotal * 100).toStringAsFixed(1) : '0.0';

    // ترويسات كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'المؤشر المالي', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي المبيعات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'إجمالي التكلفة (قبل المكسب)', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'مجمل الربح / المكسب', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'نسبة الربح', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'المجموع قبل الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 6, row: row, value: 'إجمالي الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 7, row: row, value: 'مبيعات الكاش', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 8, row: row, value: 'مبيعات الشبكة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    // قيم كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'القيمة (ر.س)', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: _money.format(sumTotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumCost), bold: true, bgHex: _cKpiBg, fgHex: '#B45309');
    _styleCell(sh, col: 3, row: row, value: _money.format(sumGrossProfit), bold: true, bgHex: _cKpiBg, fgHex: '#059669');
    _styleCell(sh, col: 4, row: row, value: '$profitMarginPct%', bold: true, bgHex: _cKpiBg, fgHex: '#059669');
    _styleCell(sh, col: 5, row: row, value: _money.format(sumSubtotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 6, row: row, value: _money.format(sumVat), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 7, row: row, value: _money.format(sumCash), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 8, row: row, value: _money.format(sumCard), bold: true, bgHex: _cKpiBg);
    row += 2;

    // ── جدول تحليل طرق الدفع ──────────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 4,
      value: 'تحليل وسائل وطرق الدفع',
      bold: true,
      fontSize: 12,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 24,
    );
    row++;

    _styleCell(sh, col: 0, row: row, value: 'م', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'وسيلة الدفع', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'إجمالي المبلغ (ر.س)', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'النسبة من المبيعات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'ملاحظات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    final cashPct = sumTotal > 0 ? (sumCash / sumTotal * 100).toStringAsFixed(1) : '0.0';
    final cardPct = sumTotal > 0 ? (sumCard / sumTotal * 100).toStringAsFixed(1) : '0.0';
    final otherSales = sumTotal - (sumCash + sumCard);
    final otherPct = sumTotal > 0 && otherSales > 0 ? (otherSales / sumTotal * 100).toStringAsFixed(1) : '0.0';

    _styleCell(sh, col: 0, row: row, value: '1', border: true);
    _styleCell(sh, col: 1, row: row, value: 'نقدي (كاش)', border: true, fgHex: _cCashFg, bold: true);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumCash), border: true);
    _styleCell(sh, col: 3, row: row, value: '$cashPct%', border: true);
    _styleCell(sh, col: 4, row: row, value: 'مقبوضات نقدية بالصندوق', border: true);
    row++;

    _styleCell(sh, col: 0, row: row, value: '2', border: true, bgHex: _cAltRow);
    _styleCell(sh, col: 1, row: row, value: 'شبكة / مدى / بطاقة', border: true, bgHex: _cAltRow, fgHex: _cCardFg, bold: true);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumCard), border: true, bgHex: _cAltRow);
    _styleCell(sh, col: 3, row: row, value: '$cardPct%', border: true, bgHex: _cAltRow);
    _styleCell(sh, col: 4, row: row, value: 'مدفوعات نقاط البيع الإلكترونية', border: true, bgHex: _cAltRow);
    row++;

    if (otherSales > 0.01) {
      _styleCell(sh, col: 0, row: row, value: '3', border: true);
      _styleCell(sh, col: 1, row: row, value: 'طرق أخرى / آجل', border: true, bold: true);
      _styleCell(sh, col: 2, row: row, value: _money.format(otherSales), border: true);
      _styleCell(sh, col: 3, row: row, value: '$otherPct%', border: true);
      _styleCell(sh, col: 4, row: row, value: '—', border: true);
      row++;
    }

    _styleCell(sh, col: 0, row: row, value: 'Σ', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 1, row: row, value: 'الإجمالي الكلي', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumTotal), bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 3, row: row, value: '100.0%', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    _styleCell(sh, col: 4, row: row, value: '$invCount فاتورة', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
    row += 2;

    // ── جدول مبيعات الفروع إذا وجد بالملخص ─────────────────────
    final byBranch = (summary?['by_branch'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (byBranch.isNotEmpty) {
      _setMergedCell(
        sh,
        col: 0,
        row: row,
        toCol: 4,
        value: 'توزيع المبيعات حسب الفروع',
        bold: true,
        fontSize: 12,
        fgHex: _cHeaderFg,
        bgHex: _cSubHeaderBg,
        hAlign: HorizontalAlign.Center,
        rowHeight: 24,
      );
      row++;

      _styleCell(sh, col: 0, row: row, value: 'م', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
      _styleCell(sh, col: 1, row: row, value: 'اسم الفرع', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
      _styleCell(sh, col: 2, row: row, value: 'إجمالي المبيعات (ر.س)', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
      _styleCell(sh, col: 3, row: row, value: 'عدد الفواتير', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
      _styleCell(sh, col: 4, row: row, value: 'النسبة من الإجمالي', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
      row++;

      int bIdx = 1;
      for (final b in byBranch) {
        final bName = b['branch_name'] as String? ?? '—';
        final bTotal = (b['total_sales'] as num?)?.toDouble() ?? 0.0;
        final bCount = (b['invoices_count'] as num?)?.toInt() ?? 0;
        final bPct = sumTotal > 0 ? (bTotal / sumTotal * 100).toStringAsFixed(1) : '0.0';
        final isEven = (bIdx % 2 == 0);
        final bg = isEven ? _cAltRow : '#FFFFFF';

        _styleCell(sh, col: 0, row: row, value: '$bIdx', border: true, bgHex: bg);
        _styleCell(sh, col: 1, row: row, value: bName, border: true, bgHex: bg, bold: true, hAlign: HorizontalAlign.Right);
        _styleCell(sh, col: 2, row: row, value: _money.format(bTotal), border: true, bgHex: bg);
        _styleCell(sh, col: 3, row: row, value: '$bCount', border: true, bgHex: bg);
        _styleCell(sh, col: 4, row: row, value: '$bPct%', border: true, bgHex: bg);
        row++;
        bIdx++;
      }

      _styleCell(sh, col: 0, row: row, value: 'Σ', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
      _styleCell(sh, col: 1, row: row, value: 'إجمالي الفروع', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
      _styleCell(sh, col: 2, row: row, value: _money.format(sumTotal), bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
      _styleCell(sh, col: 3, row: row, value: '$invCount', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
      _styleCell(sh, col: 4, row: row, value: '100.0%', bold: true, bgHex: _cTotalBg, fgHex: _cTotalFg);
      row += 2;
    }

    // ── إذا كان بدون فواتير، نكتفي بالملخص ونحفظ ──────────────────
    if (includeInvoices) {
      // ── 4. جدول الفواتير التفصيلي ──────────────────────────────
      final tableHeaders = [
        'م',
        'رقم الفاتورة',
        'الفرع',
        'الكاشير',
        'طريقة الدفع',
        'التاريخ والوقت',
        'الأصناف والكميات',
        'قبل الضريبة',
        'الضريبة',
        'الإجمالي (ر.س)',
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

      // سطور الفواتير
      for (int i = 0; i < sales.length; i++) {
        final s = sales[i];
        final isEven = (i % 2 == 0);
        final bg = isEven ? '#FFFFFF' : _cAltRow;

        final invoiceNum = s['invoice_number'] as String? ?? '—';
        final branch = s['branch_name'] as String? ?? '—';
        final cashier = s['cashier_name'] as String? ?? '—';
        final method = s['payment_method'] as String? ?? '—';
        final mLower = method.toLowerCase();
        final isCash = mLower.contains('cash') || mLower.contains('كاش') || mLower.contains('نقد');
        final isCard = mLower.contains('card') || mLower.contains('visa') || mLower.contains('شبك') || mLower.contains('مدى') || mLower.contains('pos');
        final methodLabel = isCash
            ? 'كاش'
            : isCard
                ? 'شبكة'
                : (method.isNotEmpty ? method : '—');

        final soldAtRaw = DateTime.tryParse(s['sold_at'] as String? ?? '');
        final soldAtStr = soldAtRaw != null
            ? _dtf.format(soldAtRaw.toLocal())
            : '—';

        final items = (s['items'] as List? ?? []);
        final itemsSummary = items.map((it) {
          final name = (it['product_name'] ?? '').toString().trim();
          final vLabel = (it['variant_label'] ?? '').toString().trim();
          final qty = it['qty'] ?? 1;
          final unitPrice = (it['unit_price'] as num?)?.toDouble();

          final target = '$name $vLabel'.toLowerCase();
          String? pType;
          if (target.contains('لحم') || target.contains('لحوم')) {
            pType = 'لحم';
          } else if (target.contains('دجاج') || target.contains('فراخ')) {
            pType = 'دجاج';
          } else if (target.contains('سمك') || target.contains('أسماك') || target.contains('بحري')) {
            pType = 'سمك';
          }

          String itemLabel;
          if (pType != null) {
            itemLabel = vLabel.isNotEmpty ? '$pType ($vLabel)' : pType;
          } else if (name.contains('متكامل') || name.contains('متكاملة')) {
            itemLabel = vLabel.isNotEmpty ? 'وجبة ($vLabel)' : 'وجبة';
          } else if (vLabel.isNotEmpty && !name.contains(vLabel)) {
            itemLabel = '$name ($vLabel)';
          } else {
            itemLabel = name;
          }

          if (unitPrice != null && unitPrice > 0) {
            return '• $itemLabel  (كمية: $qty | سعر: ${_money.format(unitPrice)})';
          }
          return '• $itemLabel  (كمية: $qty)';
        }).join('\r\n');

        final total = (s['total'] as num?)?.toDouble() ?? 0;
        final vat = (s['vat_amount'] as num?)?.toDouble() ?? 0;
        final subtotal = (s['subtotal'] as num?)?.toDouble() ?? (total - vat);

        final rowCells = [
          '${i + 1}',
          invoiceNum,
          branch,
          cashier,
          methodLabel,
          soldAtStr,
          itemsSummary.isEmpty ? '—' : itemsSummary,
          _money.format(subtotal),
          _money.format(vat),
          _money.format(total),
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
            fgHex: c == 4
                ? (method == 'cash' ? _cCashFg : _cCardFg)
                : (c == 9 ? '#000000' : '#2A2E3D'),
            hAlign: (c == 0 || c == 4 || c == 5)
                ? HorizontalAlign.Center
                : (c >= 7 ? HorizontalAlign.Center : HorizontalAlign.Right),
            border: true,
            wrap: c == 6, // تمكين التفاف النص لظهور الأصناف عند النقر أو التمدد
          );
        }
        final numLines = items.isEmpty ? 1 : items.length;
        final rowHeight = numLines > 1 ? (numLines * 18.0) : 22.0;
        sh.setRowHeight(row, rowHeight);
        row++;
      }

      // ── 5. صف الإجمالي النهائي ────────────────────────────────
      final totalsRow = [
        'الإجمالي',
        '${sales.length} فاتورة',
        '',
        '',
        '',
        '',
        '',
        _money.format(sumSubtotal),
        _money.format(sumVat),
        _money.format(sumTotal),
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
    }

    // الحفظ على القرص الصلب
    final bytes = excel.encode();
    if (bytes == null) return null;

    final typeSuffix = includeInvoices ? 'تفصيلي_بالفواتير' : 'ملخص_بدون_فواتير';
    final fileName =
        'DietKing_مبيعات_${typeSuffix}_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
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
    try {
      String? outputPath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ تقرير مبيعات Excel',
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

  // ═══════════════════════════════════════════════════════════════════
  // تصدير تقرير مبيعات الباقات
  // ═══════════════════════════════════════════════════════════════════

  /// يُصدِّر تقرير مبيعات الباقات (مجمّع: اسم الوجبة، وزنها، عدد الوجبات، اسم الفرع)
  static Future<String?> exportPackageSalesReport({
    required List<Map<String, dynamic>> packages,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير الباقات';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    try {
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
    } catch (_) {}
    sheet.isRTL = true;

    const String cPkgHeader = '#B45309'; // بني/ذهبي داكن
    const String cPkgFg = '#FFFFFF';
    const String cPkgRow = '#FEF3C7'; // أصفر فاتح

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString(cPkgFg),
      backgroundColorHex: ExcelColor.fromHexString(cPkgHeader),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // حساب إجمالي عدد الوجبات
    double totalMealsCount = 0;
    for (final row in packages) {
      final q = (row['total_qty'] as num?)?.toDouble() ??
          (row['qty'] as num?)?.toDouble() ??
          1.0;
      totalMealsCount += q;
    }

    final periodLabel = '${_df.format(startDate)} — ${_df.format(endDate)}';
    final branchLabel = branchName ?? 'جميع الفروع';

    // ── عنوان التقرير (صف 1-2) ──────────────────────────────────────
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('تقرير مبيعات وجبات الباقات — دايت كنج');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString(cPkgHeader),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));

    final subCell = sheet.cell(CellIndex.indexByString('A2'));
    subCell.value = TextCellValue(
        'الفترة: $periodLabel | الفرع: $branchLabel | إجمالي عدد وجبات الباقات: ${totalMealsCount.toInt()} وجبة (سعر 0 ر.س)');
    subCell.cellStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#6B3A00'),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('E2'));

    // ── صف رؤوس الأعمدة (صف 4) ──────────────────────────────────────
    const headers = [
      'م',
      'اسم الوجبة',
      'الوزن',
      'عدد الوجبات',
      'اسم الفرع',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // ضبط عرض الأعمدة
    final colWs = [6.0, 32.0, 18.0, 18.0, 24.0];
    for (var i = 0; i < colWs.length; i++) {
      sheet.setColumnWidth(i, colWs[i]);
    }
    sheet.setRowHeight(3, 24);

    // ── صفوف البيانات ─────────────────────────────────────────────────
    for (var idx = 0; idx < packages.length; idx++) {
      final row = packages[idx];
      final rowIdx = idx + 4;
      final isAlt = idx.isOdd;

      void addCell(int col, dynamic value, {bool isBold = false, String? fgHex}) {
        final c = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
        );
        if (value is int || value is double) {
          final d = value is double ? value : (value as int).toDouble();
          if (d == d.roundToDouble()) {
            c.value = IntCellValue(d.toInt());
          } else {
            c.value = DoubleCellValue(d);
          }
        } else {
          c.value = TextCellValue(value?.toString() ?? '—');
        }
        c.cellStyle = CellStyle(
          bold: isBold,
          fontColorHex: ExcelColor.fromHexString(fgHex ?? '#1E293B'),
          backgroundColorHex: ExcelColor.fromHexString(isAlt ? cPkgRow : '#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      final qty = (row['total_qty'] as num?)?.toDouble() ??
          (row['qty'] as num?)?.toDouble() ??
          1.0;

      addCell(0, idx + 1);
      addCell(1, row['product_name'] ?? '—', isBold: true);
      addCell(2, row['variant_label'] ?? '—');
      addCell(3, qty, isBold: true, fgHex: '#B45309');
      addCell(4, row['branch_name'] ?? '—');
    }

    // ── صف الإجمالي ──────────────────────────────────────────────────
    final totalRow = packages.length + 5;
    final totCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow),
    );
    totCell.value = TextCellValue(
        'الإجمالي الكلي: ${totalMealsCount.toInt()} وجبة باقة — القيمة: 0.00 ر.س');
    totCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString(cPkgFg),
      backgroundColorHex: ExcelColor.fromHexString(cPkgHeader),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow),
    );

    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName =
        'packages_report_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _saveFile(bytes, fileName);
  }

  /// يُصدِّر تقرير الوجبات (المنيو) — الكميات المسحوبة مع التكلفة (قبل المكسب) والمبيعات والأرباح
  /// عند اختيار "كل الفروع" لا يظهر عمود الفرع وتُجمع الكميات للأصناف
  static Future<String?> exportMealsReport({
    required List<Map<String, dynamic>> meals,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير الوجبات والمنيو';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    try {
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
    } catch (_) {}
    sheet.isRTL = true;

    final isAllBranches = (branchName == null || branchName.isEmpty || branchName == 'جميع الفروع');

    const String cHeaderBg = '#0F766E'; // Teal داكن فاخر
    const String cHeaderFg = '#FFFFFF';
    const String cAltRow   = '#F0FDFA'; // خفيف جداً
    const String cRevFg    = '#059669'; // أخضر / مبيعات
    const String cCostFg   = '#B45309'; // بني برتقالي / تكلفة

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString(cHeaderFg),
      backgroundColorHex: ExcelColor.fromHexString(cHeaderBg),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // حساب الإجماليات
    double sumTotalQty = 0;
    double sumTotalCost = 0;
    double sumRevenue = 0;
    double sumProfit = 0;

    for (final row in meals) {
      final q = (row['total_qty'] as num?)?.toDouble() ?? 0;
      final c = (row['total_cost'] as num?)?.toDouble() ??
          (q * ((row['unit_cost'] as num?)?.toDouble() ?? 0));
      final r = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      final p = (row['net_profit'] as num?)?.toDouble() ?? (r - c);

      sumTotalQty += q;
      sumTotalCost += c;
      sumRevenue += r;
      sumProfit += p;
    }

    final overallMargin = sumRevenue > 0
        ? (sumProfit / sumRevenue * 100).toStringAsFixed(1)
        : '0.0';

    final periodLabel = '${_df.format(startDate)} — ${_df.format(endDate)}';
    final branchLabel = isAllBranches ? 'كافة الفروع' : branchName;

    // رؤوس الأعمدة حسب ما إذا كان التقرير لكل الفروع أو لفرع محدد
    final headers = isAllBranches
        ? [
            'م',
            'اسم الوجبة / المنتج',
            'الوزن / الحجم',
            'إجمالي الكمية المسحوبة',
            'سعر التكلفة للوحدة (ر.س)',
            'إجمالي التكلفة (ر.س)',
            'الرصيد المحصل / الإيراد (ر.س)',
            'صافي المكسب / الربح (ر.س)',
            'نسبة الربح %',
          ]
        : [
            'م',
            'اسم الوجبة / المنتج',
            'الوزن / الحجم',
            'اسم الفرع',
            'إجمالي الكمية المسحوبة',
            'سعر التكلفة للوحدة (ر.س)',
            'إجمالي التكلفة (ر.س)',
            'الرصيد المحصل / الإيراد (ر.س)',
            'صافي المكسب / الربح (ر.س)',
            'نسبة الربح %',
          ];

    final colWs = isAllBranches
        ? [6.0, 32.0, 16.0, 18.0, 18.0, 18.0, 20.0, 20.0, 14.0]
        : [6.0, 28.0, 15.0, 20.0, 18.0, 18.0, 18.0, 20.0, 20.0, 14.0];

    final endColLetter = isAllBranches ? 'I' : 'J';

    // ── عنوان التقرير (صف 1-2) ──────────────────────────────────────
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
        'تقرير مبيعات الوجبات والمنيو — دايت كنج (${isAllBranches ? "كافة الفروع" : branchLabel})');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString(cHeaderBg),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('${endColLetter}1'));

    final subCell = sheet.cell(CellIndex.indexByString('A2'));
    subCell.value = TextCellValue(
        'الفترة: $periodLabel | $branchLabel | إجمالي الأصناف: ${meals.length} | إجمالي الكميات: ${sumTotalQty.toInt()} وجبة | إجمالي التكلفة: ${_money.format(sumTotalCost)} | إجمالي المبيعات: ${_money.format(sumRevenue)} | صافي الربح: ${_money.format(sumProfit)} ($overallMargin%)');
    subCell.cellStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#134E4A'),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('${endColLetter}2'));

    // ── صف رؤوس الأعمدة (صف 4) ──────────────────────────────────────
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // ضبط عرض الأعمدة
    for (var i = 0; i < colWs.length; i++) {
      sheet.setColumnWidth(i, colWs[i]);
    }
    sheet.setRowHeight(3, 26);

    // ── صفوف البيانات ─────────────────────────────────────────────────
    for (var idx = 0; idx < meals.length; idx++) {
      final row = meals[idx];
      final rowIdx = idx + 4;
      final isAlt = idx.isOdd;

      void addCell(int col, dynamic value, {bool isBold = false, String? fgHex, bool isNumber = false}) {
        final c = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
        );
        if (value is int || value is double) {
          final d = value is double ? value : (value as int).toDouble();
          if (isNumber) {
            c.value = DoubleCellValue(d);
          } else if (d == d.roundToDouble()) {
            c.value = IntCellValue(d.toInt());
          } else {
            c.value = DoubleCellValue(d);
          }
        } else {
          c.value = TextCellValue(value?.toString() ?? '—');
        }
        c.cellStyle = CellStyle(
          bold: isBold,
          fontColorHex: ExcelColor.fromHexString(fgHex ?? '#1E293B'),
          backgroundColorHex: ExcelColor.fromHexString(isAlt ? cAltRow : '#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      final totQ = (row['total_qty'] as num?)?.toDouble() ?? 0;
      final uCost = (row['unit_cost'] as num?)?.toDouble() ?? 0;
      final tCost = (row['total_cost'] as num?)?.toDouble() ?? (totQ * uCost);
      final rev   = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      final profit = (row['net_profit'] as num?)?.toDouble() ?? (rev - tCost);
      final margin = (row['profit_margin'] as num?)?.toDouble() ??
          (rev > 0 ? (profit / rev * 100) : 0);

      int cIdx = 0;
      addCell(cIdx++, idx + 1);
      addCell(cIdx++, row['product_name'] ?? '—', isBold: true);
      addCell(cIdx++, row['variant_label'] ?? '—');
      if (!isAllBranches) {
        addCell(cIdx++, row['branch_name'] ?? branchLabel);
      }
      addCell(cIdx++, totQ, isBold: true);
      addCell(cIdx++, uCost, fgHex: cCostFg, isNumber: true);
      addCell(cIdx++, tCost, fgHex: cCostFg, isNumber: true);
      addCell(cIdx++, rev, isBold: true, fgHex: cRevFg, isNumber: true);
      addCell(cIdx++, profit, isBold: true, fgHex: profit >= 0 ? cRevFg : '#DC2626', isNumber: true);
      addCell(cIdx++, '${margin.toStringAsFixed(1)}%', isBold: true);
    }

    // ── صف الإجمالي ──────────────────────────────────────────────────
    final totalRow = meals.length + 5;
    void addTotCell(int col, dynamic val, {bool isBold = true, String? fgHex}) {
      final c = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totalRow),
      );
      if (val is int || val is double) {
        final d = val is double ? val : (val as int).toDouble();
        c.value = TextCellValue(_money.format(d));
      } else {
        c.value = TextCellValue(val.toString());
      }
      c.cellStyle = CellStyle(
        bold: isBold,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString(fgHex ?? cHeaderFg),
        backgroundColorHex: ExcelColor.fromHexString(cHeaderBg),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    int tIdx = 0;
    addTotCell(tIdx++, 'Σ');
    addTotCell(tIdx++, 'الإجمالي الكلي');
    addTotCell(tIdx++, '—');
    if (!isAllBranches) {
      addTotCell(tIdx++, branchLabel);
    }
    addTotCell(tIdx++, '${sumTotalQty.toInt()} وجبة');
    addTotCell(tIdx++, '—');
    addTotCell(tIdx++, sumTotalCost, fgHex: '#FDE68A');
    addTotCell(tIdx++, sumRevenue);
    addTotCell(tIdx++, sumProfit, fgHex: '#A7F3D0');
    addTotCell(tIdx++, '$overallMargin%');

    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName = isAllBranches
        ? 'meals_report_all_branches_${_df.format(startDate)}_${_df.format(endDate)}.xlsx'
        : 'meals_report_${branchLabel}_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _saveFile(bytes, fileName);
  }
}



