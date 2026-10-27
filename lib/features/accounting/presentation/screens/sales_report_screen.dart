import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../../data/sales_excel_export_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SalesReportScreen — صفحة المبيعات
// ══════════════════════════════════════════════════════════════════════════════

class SalesReportScreen extends StatefulWidget {
  final AccountingRepository repo;
  const SalesReportScreen({super.key, required this.repo});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  late DateTimeRange _range;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _detail = [];
  bool _showDetail = false;

  // التبويب النشط: 0: ملخص وفواتير، 1: تقرير الوجبات (المنيو)، 2: تقرير الباقات
  int _currentTab = 0;
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _packages = [];

  static final _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)).isBefore(earliest)
          ? earliest
          : now.subtract(const Duration(days: 30)),
      end: now,
    );
    _init();
  }

  Future<void> _init() async {
    try {
      final branches = await widget.repo.listBranches();
      if (mounted) setState(() => _branches = branches);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(
        _range.start.year,
        _range.start.month,
        _range.start.day,
      );
      final to = DateTime(
        _range.end.year,
        _range.end.month,
        _range.end.day,
        23,
        59,
        59,
      );

      final summary = await widget.repo.getSalesSummary(
        from: from,
        to: to,
        branchId: _selectedBranchId,
      );

      List<Map<String, dynamic>> detail = [];
      if (_showDetail && _currentTab == 0) {
        final res = await widget.repo.getSalesDetail(
          from: from,
          to: to,
          branchId: _selectedBranchId,
        );
        detail = List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      }

      List<Map<String, dynamic>> meals = [];
      if (_currentTab == 1) {
        meals = await widget.repo.getMealsReport(
          from: from,
          to: to,
          branchId: _selectedBranchId,
        );
      }

      List<Map<String, dynamic>> packages = [];
      if (_currentTab == 2) {
        packages = await widget.repo.getPackageSales(
          from: from,
          to: to,
          branchId: _selectedBranchId,
        );
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _detail = detail;
          _meals = meals;
          _packages = packages;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTabChanged(int index) {
    if (_currentTab == index) return;
    setState(() => _currentTab = index);
    if ((index == 1 && _meals.isEmpty) || (index == 2 && _packages.isEmpty)) {
      _load();
    }
  }

  Future<void> _pickRange() async {
    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    final latest = AccountingDateUtils.getRetentionLatestDate();

    final safeStart = _range.start.isBefore(earliest) ? earliest : _range.start;
    final safeEnd = _range.end.isAfter(latest) ? latest : _range.end;

    final range = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryContainer,
            onPrimary: Color(0xFF1A1200),
            surface: Color(0xFF1A1E26),
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _range = range);
      _load();
    }
  }

  Future<void> _exportExcel() async {
    // choice: true = تفصيلي، false = ملخص، 'packages' = تقرير الباقات
    final choice = await showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF222938)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B365D).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.table_view_rounded,
                color: Color(0xFF60A0FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تصدير شيت مبيعات Excel',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر نوع تقرير المبيعات المراد تصديره:',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: const Color(0xFF8A92A3),
              ),
            ),
            const SizedBox(height: 16),
            // ── تفصيلي ─────────────────────────────────────────────────────
            InkWell(
              onTap: () => Navigator.pop(ctx, true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2234),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E4064)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF60A0FF),
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصدير تفصيلي (بالفواتير الكاملة)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'شيت شامل لكافة الفواتير صنفاً بصنف مع الأسعار وطرق الدفع وتفاصيل الكاشير',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF60A0FF),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── ملخص ───────────────────────────────────────────────────────
            InkWell(
              onTap: () => Navigator.pop(ctx, false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF12221A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F4A33)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.tertiary,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصدير بدون الفواتير (ملخص وإحصائيات)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ملخص تنفيذي سريع للإجماليات وتوزيع المبيعات وطرق الدفع بدون جدول الفواتير',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.tertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── تقرير الباقات ───────────────────────────────────────────────
            InkWell(
              onTap: () => Navigator.pop(ctx, 'packages'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1508),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4A3010)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFD97706),
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصدير مبيعات الباقات',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اسم الوجبة، الوزن، عدد الوجبات، واسم الفرع لكافة وجبات الباقات (سعر 0 ر.س)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── تقرير الوجبات (المنيو) ───────────────────────────────────────
            InkWell(
              onTap: () => Navigator.pop(ctx, 'meals'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF144D42)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصدير تقرير الوجبات (المنيو)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الكميات المسحوبة من كل فرع والرصيد المالي لكل وجبة مع احتساب الباقات بقيمة 0',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF2DD4BF),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF8A92A3),
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    // ── تقرير الباقات ─────────────────────────────────────────────────────
    if (choice == 'packages') {
      await _exportPackageReport();
      return;
    }

    // ── تقرير الوجبات (المنيو) ─────────────────────────────────────────────
    if (choice == 'meals') {
      await _exportMealsReport();
      return;
    }

    final includeInvoices = choice as bool;

    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    );

    String? branchName;
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': null},
      );
      branchName = b['name'] as String?;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          includeInvoices
              ? 'جاري إعداد شيت Excel التفصيلي بالفواتير...'
              : 'جاري إعداد شيت Excel الملخص...',
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      List<Map<String, dynamic>> salesToExport = _detail;
      if (includeInvoices && salesToExport.isEmpty) {
        final res = await widget.repo.getSalesDetail(
          from: from,
          to: to,
          branchId: _selectedBranchId,
          limit: 200,
        );
        salesToExport = List<Map<String, dynamic>>.from(
          res['items'] as List? ?? [],
        );
      }

      final savedPath = await SalesExcelExportService.exportSalesReport(
        sales: salesToExport,
        startDate: from,
        endDate: to,
        branchName: branchName,
        summary: _summary,
        includeInvoices: includeInvoices,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B365D),
            content: Text(
              'تم تصدير ملف المبيعات (${includeInvoices ? "تفصيلي بالفواتير" : "ملخص بدون فواتير"}) بنجاح إلى:\n$savedPath',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('فشل تصدير Excel: $e'),
          ),
        );
      }
    }
  }

  /// تصدير تقرير مبيعات الباقات إلى Excel
  Future<void> _exportPackageReport() async {
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    );

    String? branchName;
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': null},
      );
      branchName = b['name'] as String?;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إعداد تقرير الباقات...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final packages = await widget.repo.getPackageSales(
        from: from,
        to: to,
        branchId: _selectedBranchId,
      );

      if (packages.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد باقات مسجلة في هذه الفترة'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final totalPkgMeals = packages
          .fold<double>(
            0,
            (s, r) =>
                s +
                ((r['total_qty'] as num?)?.toDouble() ??
                    (r['qty'] as num?)?.toDouble() ??
                    1.0),
          )
          .toInt();

      final savedPath = await SalesExcelExportService.exportPackageSalesReport(
        packages: packages,
        startDate: from,
        endDate: to,
        branchName: branchName,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2D1C08),
            content: Text(
              'تم تصدير تقرير الباقات ($totalPkgMeals وجبة) بنجاح إلى:\n$savedPath',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('فشل تصدير تقرير الباقات: $e'),
          ),
        );
      }
    }
  }

  /// تصدير تقرير الوجبات (المنيو) إلى Excel
  Future<void> _exportMealsReport() async {
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    );

    String? branchName;
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': null},
      );
      branchName = b['name'] as String?;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إعداد تقرير الوجبات والمنيو...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final meals = await widget.repo.getMealsReport(
        from: from,
        to: to,
        branchId: _selectedBranchId,
      );

      if (meals.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد مبيعات وجبات مسجلة في هذه الفترة'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final savedPath = await SalesExcelExportService.exportMealsReport(
        meals: meals,
        startDate: from,
        endDate: to,
        branchName: branchName,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D332D),
            content: Text(
              'تم تصدير تقرير الوجبات (${meals.length} صنف) بنجاح إلى:\n$savedPath',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('فشل تصدير تقرير الوجبات: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      );
    }
    if (_error != null) {
      return AccErrorWidget(message: _error!, onRetry: _load);
    }

    final byBranch =
        (_summary['by_branch'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 24),
            if (_currentTab == 0) ...[
              _buildKpiRow(),
              const SizedBox(height: 24),
              if (byBranch.isNotEmpty) ...[
                _buildBranchTable(byBranch),
                const SizedBox(height: 24),
              ],
              _buildDetailToggle(),
              if (_showDetail && _detail.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailList(),
              ],
            ] else if (_currentTab == 1) ...[
              _buildMealsReportView(),
            ] else ...[
              _buildPackagesReportView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Row(
        children: [
          _buildTabItem(
            0,
            'ملخص المبيعات والفواتير',
            Icons.bar_chart_rounded,
            const Color(0xFF60A0FF),
          ),
          const SizedBox(width: 6),
          _buildTabItem(
            1,
            'تقرير الوجبات (المنيو)',
            Icons.restaurant_menu_rounded,
            const Color(0xFF2DD4BF),
          ),
          const SizedBox(width: 6),
          _buildTabItem(
            2,
            'تقرير مبيعات الباقات',
            Icons.card_giftcard_rounded,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabChanged(index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : const Color(0xFF8A92A3),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF8A92A3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealsReportView() {
    double sumTotalQty = 0;
    double sumTotalCost = 0;
    double sumRevenue = 0;
    double sumProfit = 0;

    for (final row in _meals) {
      final q = (row['total_qty'] as num?)?.toDouble() ?? 0;
      final c =
          (row['total_cost'] as num?)?.toDouble() ??
          (q * ((row['unit_cost'] as num?)?.toDouble() ?? 0));
      final r = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      final p = (row['net_profit'] as num?)?.toDouble() ?? (r - c);

      sumTotalQty += q;
      sumTotalCost += c;
      sumRevenue += r;
      sumProfit += p;
    }

    final isAllBranches = _selectedBranchId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير الوجبات والمنيو — ${isAllBranches ? "كافة الفروع" : "الفرع المحدد"}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAllBranches
                      ? 'الكميات المسحوبة مجمعة لكافة الفروع مع التكلفة وصافي الأرباح (الباقات بسعر 0 ر.س)'
                      : 'الكميات المسحوبة للفرع المحدد مع التكلفة وصافي الأرباح (الباقات بسعر 0 ر.س)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: const Color(0xFF8A92A3),
                  ),
                ),
              ],
            ),
            const Spacer(),
            AccActionButton(
              icon: Icons.file_download_outlined,
              label: 'تصدير شيت الوجبات',
              onTap: _exportMealsReport,
              color: const Color(0xFF2DD4BF),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AccKpiCard(
              title: 'إجمالي الكميات المسحوبة',
              value: '${sumTotalQty.toInt()} وجبة',
              icon: Icons.lunch_dining_rounded,
              iconColor: const Color(0xFF2DD4BF),
              bgColor: const Color(0xFF0F2B26),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'إجمالي التكلفة (قبل المكسب)',
              value: _money.format(sumTotalCost),
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFF2B200F),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'إجمالي المبيعات المحصلة',
              value: _money.format(sumRevenue),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF60A0FF),
              bgColor: const Color(0xFF14243B),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'صافي الأرباح والمكسب',
              value: _money.format(sumProfit),
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.tertiary,
              bgColor: const Color(0xFF12221A),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AccSectionCard(
          title: isAllBranches
              ? 'تفاصيل استهلاك الوجبات لكافة الفروع (${_meals.length} صنف)'
              : 'تفاصيل استهلاك الوجبات بالفرع (${_meals.length} صنف)',
          child: _meals.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'لا توجد بيانات وجبات مسجلة في الفترة المحددة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: const Color(0xFF8A92A3),
                    ),
                  ),
                )
              : Table(
                  columnWidths: isAllBranches
                      ? const {
                          0: FlexColumnWidth(0.6),
                          1: FlexColumnWidth(2.8),
                          2: FlexColumnWidth(1.6),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1.7),
                          5: FlexColumnWidth(1.8),
                          6: FlexColumnWidth(1.8),
                          7: FlexColumnWidth(1.8),
                        }
                      : const {
                          0: FlexColumnWidth(0.6),
                          1: FlexColumnWidth(2.5),
                          2: FlexColumnWidth(1.4),
                          3: FlexColumnWidth(1.6),
                          4: FlexColumnWidth(1.4),
                          5: FlexColumnWidth(1.6),
                          6: FlexColumnWidth(1.7),
                          7: FlexColumnWidth(1.7),
                          8: FlexColumnWidth(1.7),
                        },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1E2430)),
                        ),
                      ),
                      children: isAllBranches
                          ? const [
                              AccTableHeader('م'),
                              AccTableHeader('اسم الوجبة / المنتج'),
                              AccTableHeader('الوزن / الحجم'),
                              AccTableHeader('الكمية المسحوبة'),
                              AccTableHeader('سعر التكلفة'),
                              AccTableHeader('إجمالي التكلفة'),
                              AccTableHeader('الرصيد المحصل'),
                              AccTableHeader('صافي المكسب'),
                            ]
                          : const [
                              AccTableHeader('م'),
                              AccTableHeader('اسم الوجبة / المنتج'),
                              AccTableHeader('الوزن / الحجم'),
                              AccTableHeader('الفرع'),
                              AccTableHeader('الكمية'),
                              AccTableHeader('سعر التكلفة'),
                              AccTableHeader('إجمالي التكلفة'),
                              AccTableHeader('الرصيد المحصل'),
                              AccTableHeader('صافي المكسب'),
                            ],
                    ),
                    ...List.generate(_meals.length, (i) {
                      final m = _meals[i];
                      final totQ = (m['total_qty'] as num?)?.toDouble() ?? 0;
                      final uCost = (m['unit_cost'] as num?)?.toDouble() ?? 0;
                      final tCost =
                          (m['total_cost'] as num?)?.toDouble() ??
                          (totQ * uCost);
                      final rev = (m['total_revenue'] as num?)?.toDouble() ?? 0;
                      final profit =
                          (m['net_profit'] as num?)?.toDouble() ??
                          (rev - tCost);

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF1E2430)),
                          ),
                        ),
                        children: isAllBranches
                            ? [
                                AccTableCell('${i + 1}'),
                                AccTableCell(
                                  m['product_name'] as String? ?? '—',
                                  isName: true,
                                ),
                                AccTableCell(
                                  m['variant_label'] as String? ?? '—',
                                ),
                                AccTableCell(
                                  '${totQ.toInt()}',
                                  color: Colors.white,
                                ),
                                AccTableCell(
                                  _money.format(uCost),
                                  color: const Color(0xFFF59E0B),
                                ),
                                AccTableCell(_money.format(tCost)),
                                AccTableCell(
                                  _money.format(rev),
                                  color: const Color(0xFF60A0FF),
                                ),
                                AccTableCell(
                                  _money.format(profit),
                                  color: profit >= 0
                                      ? AppColors.tertiary
                                      : Colors.redAccent,
                                ),
                              ]
                            : [
                                AccTableCell('${i + 1}'),
                                AccTableCell(
                                  m['product_name'] as String? ?? '—',
                                  isName: true,
                                ),
                                AccTableCell(
                                  m['variant_label'] as String? ?? '—',
                                ),
                                AccTableCell(
                                  m['branch_name'] as String? ?? '—',
                                ),
                                AccTableCell(
                                  '${totQ.toInt()}',
                                  color: Colors.white,
                                ),
                                AccTableCell(
                                  _money.format(uCost),
                                  color: const Color(0xFFF59E0B),
                                ),
                                AccTableCell(_money.format(tCost)),
                                AccTableCell(
                                  _money.format(rev),
                                  color: const Color(0xFF60A0FF),
                                ),
                                AccTableCell(
                                  _money.format(profit),
                                  color: profit >= 0
                                      ? AppColors.tertiary
                                      : Colors.redAccent,
                                ),
                              ],
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPackagesReportView() {
    double totalPkgMeals = 0;
    for (final row in _packages) {
      totalPkgMeals +=
          (row['total_qty'] as num?)?.toDouble() ??
          (row['qty'] as num?)?.toDouble() ??
          1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير مبيعات الباقات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'اسم الوجبة، الوزن، عدد الوجبات، واسم الفرع (سعر 0 ر.س)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: const Color(0xFF8A92A3),
                  ),
                ),
              ],
            ),
            const Spacer(),
            AccActionButton(
              icon: Icons.file_download_outlined,
              label: 'تصدير شيت الباقات',
              onTap: _exportPackageReport,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AccKpiCard(
              title: 'إجمالي عدد وجبات الباقات',
              value: '${totalPkgMeals.toInt()} وجبة',
              icon: Icons.card_giftcard_rounded,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFF2B200F),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'عدد أصناف الباقات المسجلة',
              value: '${_packages.length} صنف',
              icon: Icons.layers_rounded,
              iconColor: const Color(0xFF60A0FF),
              bgColor: const Color(0xFF14243B),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'القيمة المالية المسجلة',
              value: '0.00 ر.س (باقات)',
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.tertiary,
              bgColor: const Color(0xFF12221A),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AccSectionCard(
          title:
              'قائمة وجبات الباقات حسب الوجبة والوزن والفرع (${_packages.length} صنف)',
          child: _packages.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'لا توجد وجبات باقات مسجلة في الفترة المحددة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: const Color(0xFF8A92A3),
                    ),
                  ),
                )
              : Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(3.0),
                    2: FlexColumnWidth(2.0),
                    3: FlexColumnWidth(1.8),
                    4: FlexColumnWidth(2.5),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1E2430)),
                        ),
                      ),
                      children: [
                        AccTableHeader('م'),
                        AccTableHeader('اسم الوجبة'),
                        AccTableHeader('الوزن'),
                        AccTableHeader('عدد الوجبات'),
                        AccTableHeader('اسم الفرع'),
                      ],
                    ),
                    ...List.generate(_packages.length, (i) {
                      final p = _packages[i];
                      final q =
                          (p['total_qty'] as num?)?.toDouble() ??
                          (p['qty'] as num?)?.toDouble() ??
                          1.0;

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF1E2430)),
                          ),
                        ),
                        children: [
                          AccTableCell('${i + 1}'),
                          AccTableCell(
                            p['product_name'] as String? ?? '—',
                            isName: true,
                          ),
                          AccTableCell(p['variant_label'] as String? ?? '—'),
                          AccTableCell(
                            '${q.toInt()} وجبة',
                            color: const Color(0xFFF59E0B),
                          ),
                          AccTableCell(p['branch_name'] as String? ?? '—'),
                        ],
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تقرير المبيعات',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'مراجعة إيرادات الفروع والفواتير وحفظ السجلات المالية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: const Color(0xFF8A92A3),
            ),
          ),
        ],
      ),
      const Spacer(),
      AccActionButton(
        icon: Icons.file_download_outlined,
        label: 'تصدير Excel',
        onTap: _exportExcel,
        color: AppColors.tertiary,
      ),
      const SizedBox(width: 8),
      AccActionButton(
        icon: Icons.refresh_rounded,
        label: 'تحديث',
        onTap: _load,
        color: const Color(0xFF8A92A3),
      ),
    ],
  );

  Widget _buildFilters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF141720),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E2430)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الفرع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: const Color(0xFF8A92A3),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _selectedBranchId,
                dropdownColor: const Color(0xFF1A1E26),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: Color(0xFF1A1E26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الفروع')),
                  ..._branches.map(
                    (b) => DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(b['name'] as String? ?? ''),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedBranchId = v);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الفترة الزمنية',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: const Color(0xFF8A92A3),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: Color(0xFF8A92A3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(_range.start)} — ${DateFormat('dd/MM/yyyy').format(_range.end)}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildKpiRow() {
    final total = (_summary['total_sales'] as num?)?.toDouble() ?? 0;
    final cost = (_summary['total_cost'] as num?)?.toDouble() ?? 0;
    final profit =
        (_summary['gross_profit'] as num?)?.toDouble() ?? (total - cost);
    final discount = (_summary['total_discount'] as num?)?.toDouble() ?? 0;
    final vat = (_summary['total_vat'] as num?)?.toDouble() ?? 0;
    final cash = (_summary['cash_sales'] as num?)?.toDouble() ?? 0;
    final card = (_summary['card_sales'] as num?)?.toDouble() ?? 0;
    final count = (_summary['invoices_count'] as int?) ?? 0;

    return Column(
      children: [
        Row(
          children: [
            AccKpiCard(
              title: 'إجمالي المبيعات',
              value: _money.format(total),
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.tertiary,
              bgColor: const Color(0xFF0D1A10),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'إجمالي التكلفة (قبل المكسب)',
              value: _money.format(cost),
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFF1F1708),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'مجمل الربح / المكسب',
              value: _money.format(profit),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF2DD4BF),
              bgColor: const Color(0xFF0F2622),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'صافي المبيعات (بعد الخصم)',
              value: _money.format(total - discount),
              icon: Icons.attach_money_rounded,
              iconColor: const Color(0xFF60A0FF),
              bgColor: const Color(0xFF0D1225),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AccKpiCard(
              title: 'إجمالي الخصم',
              value: _money.format(discount),
              icon: Icons.local_offer_outlined,
              iconColor: const Color(0xFFFFAA00),
              bgColor: const Color(0xFF1A1400),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'ضريبة القيمة المضافة',
              value: _money.format(vat),
              icon: Icons.receipt_outlined,
              iconColor: const Color(0xFFCC66FF),
              bgColor: const Color(0xFF150D1A),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'مبيعات الكاش',
              value: _money.format(cash),
              icon: Icons.money_rounded,
              iconColor: AppColors.tertiary,
              bgColor: const Color(0xFF0D1A10),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'مبيعات الشبكة',
              value: _money.format(card),
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFF60A0FF),
              bgColor: const Color(0xFF0D1225),
            ),
            const SizedBox(width: 12),
            AccKpiCard(
              title: 'عدد الفواتير',
              value: '$count',
              icon: Icons.confirmation_number_outlined,
              iconColor: const Color(0xFF8A92A3),
              bgColor: const Color(0xFF141720),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBranchTable(
    List<Map<String, dynamic>> byBranch,
  ) => AccSectionCard(
    title: 'توزيع المبيعات بالفروع',
    child: Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
          children: [
            AccTableHeader('الفرع'),
            AccTableHeader('إجمالي المبيعات'),
            AccTableHeader('صافي المبيعات'),
            AccTableHeader('إجمالي الخصم'),
            AccTableHeader('عدد الفواتير'),
          ],
        ),
        ...byBranch.map((b) {
          final sales = (b['total_sales'] as num?)?.toDouble() ?? 0;
          final disc = (b['total_discount'] as num?)?.toDouble() ?? 0;
          final cnt = (b['invoices_count'] as int?) ?? 0;
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E2430))),
            ),
            children: [
              AccTableCell(b['branch_name'] as String? ?? '—', isName: true),
              AccTableCell(_money.format(sales), color: AppColors.tertiary),
              AccTableCell(
                _money.format(sales - disc),
                color: const Color(0xFF60A0FF),
              ),
              AccTableCell(_money.format(disc), color: const Color(0xFFFFAA00)),
              AccTableCell(cnt.toString()),
            ],
          );
        }),
      ],
    ),
  );

  Widget _buildDetailToggle() => Row(
    children: [
      Text(
        'تفاصيل الفواتير',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      Switch.adaptive(
        value: _showDetail,
        activeTrackColor: AppColors.primaryContainer,
        onChanged: (v) {
          setState(() => _showDetail = v);
          _load();
        },
      ),
      if (_showDetail) ...[
        const Spacer(),
        Text(
          '${_detail.length} فاتورة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            color: const Color(0xFF8A92A3),
          ),
        ),
      ],
    ],
  );

  Widget _buildDetailList() => AccSectionCard(
    title: 'الفواتير',
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 450),
      child: ListView.separated(
        itemCount: _detail.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) {
          final s = _detail[i];
          final total = (s['total'] as num?)?.toDouble() ?? 0;
          final soldAt = DateTime.tryParse(s['sold_at'] as String? ?? '');
          final method = s['payment_method'] as String? ?? '';
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              hoverColor: const Color(0xFF1E2430),
              onTap: () => _showInvoiceDialog(s),
              title: Row(
                children: [
                  Text(
                    s['invoice_number'] as String? ?? '—',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _methodColor(method).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _methodLabel(method),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: _methodColor(method),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Tooltip(
                    message: 'انقر لعرض محتويات الفاتورة',
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF636E7E),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${s['branch_name'] ?? ''} — ${s['cashier_name'] ?? ''}${soldAt != null ? ' — ${DateFormat('dd/MM/yyyy HH:mm').format(soldAt.toLocal())}' : ''}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: const Color(0xFF8A92A3),
                ),
              ),
              trailing: Text(
                _money.format(total),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tertiary,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  void _showInvoiceDialog(Map<String, dynamic> s) {
    final items = List<Map<String, dynamic>>.from(s['items'] as List? ?? []);
    final soldAt = DateTime.tryParse(s['sold_at'] as String? ?? '');
    final subtotal = (s['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (s['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final vat = (s['vat_amount'] as num?)?.toDouble() ?? 0.0;
    final total = (s['total'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF141720),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF262C3A)),
          ),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 650),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل الفاتورة #${s['invoice_number'] ?? '—'}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s['branch_name'] ?? 'فرع غير محدد'} • الكاشير: ${s['cashier_name'] ?? '—'}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8A92A3),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF222735)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFF8A92A3),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            soldAt != null
                                ? DateFormat(
                                    'yyyy/MM/dd HH:mm',
                                  ).format(soldAt.toLocal())
                                : '—',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'طريقة الدفع: ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _methodColor(
                                s['payment_method'] ?? '',
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _methodLabel(s['payment_method'] ?? ''),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _methodColor(s['payment_method'] ?? ''),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'محتويات الفاتورة (${items.length}):',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF222735)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'لا توجد أصناف مسجلة في هذه الفاتورة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: const Color(0xFF8A92A3),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── رأس جدول الأصناف ──
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF191F2C),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(7),
                                    topRight: Radius.circular(7),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFF222735)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'الصنف / الوجبة',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'الوزن / الحجم',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'الكمية',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'السعر',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'الإجمالي',
                                        textAlign: TextAlign.left,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ── سطور الأصناف ──
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    color: Color(0xFF1E2430),
                                    height: 1,
                                  ),
                                  itemBuilder: (_, idx) {
                                    final it = items[idx];
                                    final pName = it['product_name'] ?? 'صنف';
                                    String vLabel = (it['variant_label'] as String?)?.trim() ?? '';
                                    if (vLabel.isEmpty) {
                                      final match = RegExp(r'\(([^)]+)\)').firstMatch(pName.toString());
                                      if (match != null) {
                                        vLabel = match.group(1)?.trim() ?? '';
                                      }
                                    }

                                    final qty = (it['qty'] as num?)?.toDouble() ?? 1.0;
                                    final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                                    final isPkg = (it['is_package'] == true) || price == 0;
                                    final lineTotal = isPkg
                                        ? 0.0
                                        : ((it['line_total'] as num?)?.toDouble() ?? (qty * price));

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              pName,
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: vLabel.isNotEmpty
                                                  ? Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF1E2838),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: const Color(0xFF2A3A54),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        vLabel,
                                                        style: GoogleFonts.ibmPlexSansArabic(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF60A0FF),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      '—',
                                                      style: GoogleFonts.ibmPlexSansArabic(
                                                        fontSize: 11,
                                                        color: const Color(0xFF636E7E),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '×${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 12,
                                                color: const Color(0xFF8A92A3),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: isPkg
                                                ? Center(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF33200A),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'باقة',
                                                        style: GoogleFonts.ibmPlexSansArabic(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFFF59E0B),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    _money.format(price),
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.spaceGrotesk(
                                                      fontSize: 12,
                                                      color: const Color(0xFF8A92A3),
                                                    ),
                                                  ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _money.format(lineTotal),
                                              textAlign: TextAlign.left,
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isPkg
                                                    ? const Color(0xFFF59E0B)
                                                    : AppColors.tertiary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF222735)),
                  ),
                  child: Column(
                    children: [
                      _dialogSummaryRow(
                        'المجموع قبل الضريبة',
                        _money.format(subtotal),
                      ),
                      if (discount > 0)
                        _dialogSummaryRow(
                          'الخصم',
                          '- ${_money.format(discount)}',
                          color: Colors.orangeAccent,
                        ),
                      _dialogSummaryRow(
                        'ضريبة القيمة المضافة (15%)',
                        _money.format(vat),
                      ),
                      const Divider(color: Color(0xFF262C3A), height: 16),
                      _dialogSummaryRow(
                        'الإجمالي النهائي',
                        _money.format(total),
                        isBold: true,
                        color: AppColors.tertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold ? Colors.white : const Color(0xFF8A92A3),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (isBold ? Colors.white : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Color _methodColor(String m) => switch (m) {
    'cash' => AppColors.tertiary,
    'card' => const Color(0xFF60A0FF),
    _ => const Color(0xFFFFAA00),
  };

  String _methodLabel(String m) => switch (m) {
    'cash' => 'كاش',
    'card' => 'شبكة',
    _ => 'أخرى',
  };
}
