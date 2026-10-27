import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../../data/comprehensive_reports_excel_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ComprehensiveReportsScreen — شاشة التقارير المالية والإدارية الشاملة
// ══════════════════════════════════════════════════════════════════════════════

class ComprehensiveReportsScreen extends StatefulWidget {
  final AccountingRepository repo;
  const ComprehensiveReportsScreen({super.key, required this.repo});

  @override
  State<ComprehensiveReportsScreen> createState() =>
      _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState
    extends State<ComprehensiveReportsScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = الشركة كاملة
  String _selectedBranchName = 'الشركة كاملة (جميع الفروع)';

  late DateTimeRange _range;
  String _quickPeriod = 'current_month'; // 'current_month', 'prev_month', 'prev_prev_month', 'last_two_months', 'custom'

  final TextEditingController _actualSalariesCtrl =
      TextEditingController(text: '0');

  bool _loading = false;
  String? _error;
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _warehouseOrders = [];
  Map<String, dynamic> _salesSummary = {};

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);
  static final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _applyQuickPeriod('current_month', reload: false);
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

  void _applyQuickPeriod(String key, {bool reload = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (key) {
      case 'current_month':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'prev_month':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        start = DateTime(prevMonth.year, prevMonth.month, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59); // آخر يوم في الشهر السابق
        break;
      case 'last_two_months':
        final prevMonth2 = DateTime(now.year, now.month - 1, 1);
        start = DateTime(prevMonth2.year, prevMonth2.month, 1);
        end = now;
        break;
      default:
        return;
    }

    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    if (start.isBefore(earliest)) {
      start = earliest;
    }

    setState(() {
      _quickPeriod = key;
      _range = DateTimeRange(start: start, end: end);
    });

    if (reload) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.repo.getComprehensiveFinancialReport(
          from: _range.start,
          to: _range.end,
          branchId: _selectedBranchId,
        ),
        widget.repo.getBranchWarehouseOrders(
          from: _range.start,
          to: _range.end,
          branchId: _selectedBranchId,
        ),
        widget.repo.getSalesSummary(
          from: _range.start,
          to: _range.end,
          branchId: _selectedBranchId,
        ),
      ]);

      if (mounted) {
        setState(() {
          _reportData = results[0];
          _warehouseOrders = List<Map<String, dynamic>>.from(
              results[1]['orders'] as List? ?? []);
          _salesSummary = results[2];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── العمليات الحسابية وصافي الربح ──────────────────────────────────────────
  double get _actualSalaries =>
      double.tryParse(_actualSalariesCtrl.text.trim()) ?? 0.0;

  double get _salesTotal {
    final s = _reportData['sales'] as Map<String, dynamic>?;
    final repSales = (s?['total'] as num?)?.toDouble() ?? 0.0;
    if (repSales > 0) return repSales;
    return (_salesSummary['total_sales'] as num?)?.toDouble() ?? 0.0;
  }

  double get _expensesTotal {
    final e = _reportData['expenses'] as Map<String, dynamic>?;
    return (e?['total'] as num?)?.toDouble() ?? 0.0;
  }

  bool get _isCompany => _selectedBranchId == null;

  double get _suppliesCost {
    if (_isCompany) {
      final p = _reportData['purchases'] as Map<String, dynamic>?;
      return (p?['total'] as num?)?.toDouble() ?? 0.0;
    } else {
      final bo = _reportData['branch_warehouse_orders'] as Map<String, dynamic>?;
      final boTotal = (bo?['total'] as num?)?.toDouble() ?? 0.0;
      if (boTotal > 0) return boTotal;
      double calcBo = 0.0;
      for (final o in _warehouseOrders) {
        calcBo += (o['total_cost'] as num?)?.toDouble() ?? 0.0;
      }
      return calcBo;
    }
  }

  double get _surplusTotal {
    final c = _reportData['closings'] as Map<String, dynamic>?;
    return (c?['surplus'] as num?)?.toDouble() ?? 0.0;
  }

  double get _shortageTotal {
    final c = _reportData['closings'] as Map<String, dynamic>?;
    return (c?['shortage'] as num?)?.toDouble() ?? 0.0;
  }

  double get _netProfit =>
      (_salesTotal + _surplusTotal) -
      (_expensesTotal + _suppliesCost + _actualSalaries);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildScopeSelector(),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 20),
          _buildSalariesCard(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: AppColors.primaryContainer)))
          else if (_error != null)
            AccErrorWidget(message: _error!, onRetry: _load)
          else ...[
            _buildKpisSection(),
            const SizedBox(height: 24),
            _buildPnlTable(),
            const SizedBox(height: 24),
            if (_isCompany) ...[
              _buildBranchSalesBreakdownTable(),
              const SizedBox(height: 24),
            ],
            _buildSalesAndExpensesGrid(),
            const SizedBox(height: 24),
            _buildWarehouseOrdersSection(),
          ],
        ]),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('التقارير المالية والإدارية الشاملة',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('قوائم الدخل الشاملة، تحليل الأرباح والخسائر، واحتساب طلبيات المخزون وفائض الكاشير',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: const Color(0xFF8A92A3))),
        ]),
        const Spacer(),
        AccActionButton(
          icon: Icons.table_view_rounded,
          label: 'تصدير شيت Excel احترافي',
          color: AppColors.tertiary,
          onTap: _exportExcel,
        ),
        const SizedBox(width: 8),
        AccActionButton(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          color: const Color(0xFF8A92A3),
          onTap: _load,
        ),
      ]);

  // ── SCOPE SELECTOR ──────────────────────────────────────────────────────────
  Widget _buildScopeSelector() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScopeButton(
              title: 'التقرير الشامل للشركة كاملة',
              icon: Icons.corporate_fare_rounded,
              isSelected: _isCompany,
              onTap: () {
                if (!_isCompany) {
                  setState(() {
                    _selectedBranchId = null;
                    _selectedBranchName = 'الشركة كاملة (جميع الفروع والمستودع)';
                  });
                  _load();
                }
              },
            ),
            _buildScopeButton(
              title: 'تقرير فرع محدد',
              icon: Icons.store_rounded,
              isSelected: !_isCompany,
              onTap: () {
                if (_isCompany) {
                  final firstBranch = _branches.isNotEmpty ? _branches.first : null;
                  setState(() {
                    _selectedBranchId = firstBranch?['id'] as String?;
                    _selectedBranchName = firstBranch?['name'] as String? ?? 'الفرع';
                  });
                  _load();
                }
              },
            ),
          ],
        ),
      );

  Widget _buildScopeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? AppColors.primaryContainer
                    : const Color(0xFF8A92A3)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF8A92A3),
              ),
            ),
          ]),
        ),
      );

  // ── FILTER BAR ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Branch Selection or Info Badge
            if (!_isCompany)
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedBranchId),
                  initialValue: _selectedBranchId,
                  dropdownColor: const Color(0xFF1A1E26),
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'الفرع المحدد',
                    labelStyle: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF8A92A3), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0B0E14),
                    isDense: true,
                    prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF60A0FF)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                  ),
                  items: _branches
                      .map((b) => DropdownMenuItem<String>(
                            value: b['id'] as String,
                            child: Text(b['name'] as String? ?? '—',
                                style: GoogleFonts.ibmPlexSansArabic(
                                    color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBranchId = val;
                        final b = _branches.firstWhere((br) => br['id'] == val,
                            orElse: () => {'name': 'الفرع'});
                        _selectedBranchName = b['name'] as String? ?? 'الفرع';
                      });
                      _load();
                    }
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A4A).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A4273)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.apartment_rounded, color: Color(0xFF60A0FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'التقرير يشمل كافة الفروع التابعة ومشتريات المستودع الرئيسي',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ]),
              ),

            // Quick Period Chips (شهرين فقط: السابق والحالي)
            ...[
              ('current_month', 'الشهر الحالي'),
              ('prev_month', 'الشهر السابق'),
              ('last_two_months', 'الشهران (السابق والحالي)'),
            ].map((p) {
              final active = _quickPeriod == p.$1;
              return InkWell(
                onTap: () => _applyQuickPeriod(p.$1),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: active
                            ? AppColors.primaryContainer
                            : const Color(0xFF2A2E3A)),
                  ),
                  child: Text(p.$2,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: active
                              ? AppColors.primaryContainer
                              : const Color(0xFF8A92A3),
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }),

            // Custom Range Picker Button
            InkWell(
              onTap: _pickCustomRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _quickPeriod == 'custom'
                        ? AppColors.primaryContainer
                        : const Color(0xFF2A2E3A),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 16, color: Color(0xFF8A92A3)),
                  const SizedBox(width: 8),
                  Text(
                    '${_df.format(_range.start)} — ${_df.format(_range.end)}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: _quickPeriod == 'custom'
                          ? AppColors.primaryContainer
                          : Colors.white,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );

  Future<void> _pickCustomRange() async {
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
      setState(() {
        _quickPeriod = 'custom';
        _range = range;
      });
      _load();
    }
  }

  // ── MANUAL SALARIES ENTRY CARD ──────────────────────────────────────────────
  Widget _buildSalariesCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2F4D)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF60A0FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.badge_outlined,
                color: Color(0xFF60A0FF), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isCompany
                    ? 'قيمة رواتب موظفي الشركة كاملة للفترة (إدخال يدوي مانوال)'
                    : 'قيمة رواتب موظفي فرع $_selectedBranchName الإجمالي للفترة (إدخال يدوي مانوال)',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              Text(
                _isCompany
                    ? 'أدخل القيمة الإجمالية الفعلية لرواتب جميع موظفي الشركة للفترة المحددة، لتُحسب وتُخصم فوراً في نتائج الأرباح والشيت المصدر.'
                    : 'أدخل القيمة الإجمالية الفعلية لرواتب موظفي فرع $_selectedBranchName فقط للفترة المحددة، لتُحسب وتُخصم فوراً في أرباح الفرع والشيت المصدر.',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, color: const Color(0xFF8A92A3)),
              ),
            ]),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _actualSalariesCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF60A0FF)),
              decoration: InputDecoration(
                labelText: _isCompany ? 'إجمالي رواتب الشركة' : 'إجمالي رواتب الفرع',
                labelStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, color: const Color(0xFF8A92A3)),
                suffixText: 'ر.س',
                suffixStyle: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF8A92A3)),
                filled: true,
                fillColor: const Color(0xFF0B0E14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF60A0FF))),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      );

  // ── KPIS SECTION ────────────────────────────────────────────────────────────
  Widget _buildKpisSection() {
    final isProfit = _netProfit >= 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بطاقة صافي الربح الكبرى
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isProfit
              ? const Color(0xFF0E2214)
              : const Color(0xFF261012),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isProfit
                  ? AppColors.tertiary.withValues(alpha: 0.4)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.4),
              width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isProfit
                  ? AppColors.tertiary.withValues(alpha: 0.2)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isProfit
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isProfit ? AppColors.tertiary : const Color(0xFFFF6B6B),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isProfit
                  ? (_isCompany ? 'صافي الربح التشغيلي للشركة كاملة' : 'صافي الربح التشغيلي لفرع $_selectedBranchName')
                  : (_isCompany ? 'صافي الخسارة التشغيلية للشركة' : 'صافي الخسارة التشغيلية لفرع $_selectedBranchName'),
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isProfit ? AppColors.tertiary : const Color(0xFFFF6B6B)),
            ),
            Text(
              _money.format(_netProfit.abs()),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isProfit ? Colors.white : const Color(0xFFFF6B6B)),
            ),
          ]),
          const Spacer(),
          Text(
            isProfit
                ? (_isCompany
                    ? 'المعادلة: (مبيعات جميع الفروع + فائض الكاشير) - (جميع المصروفات + مشتريات المخزون + رواتب الشركة)'
                    : 'المعادلة: (مبيعات الفرع + فائض الكاشير) - (مصروفات الفرع + طلبات المخزون كفلوس + رواتب الفرع)')
                : 'التكاليف والمصروفات والرواتب تتجاوز الإيرادات المحققة في هذه الفترة',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12, color: const Color(0xFF8A92A3)),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // بطاقات المؤشرات الستة
      Row(children: [
        AccKpiCard(
          title: _isCompany ? 'مبيعات جميع الفروع' : 'إجمالي مبيعات الفرع',
          value: _money.format(_salesTotal),
          icon: Icons.point_of_sale_rounded,
          iconColor: AppColors.primaryContainer,
          bgColor: const Color(0xFF1A1200),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: _isCompany ? 'جميع المصروفات المعتمدة' : 'إجمالي مصروفات الفرع',
          value: _money.format(_expensesTotal),
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFFFF6B6B),
          bgColor: const Color(0xFF1A0D0D),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: _isCompany ? 'جميع مشتريات المخزون' : 'طلباته من المخزون كفلوس',
          value: _money.format(_suppliesCost),
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFFFFAA00),
          bgColor: const Color(0xFF1A1400),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: _isCompany ? 'رواتب الشركة كاملة' : 'رواتب موظفي الفرع',
          value: _money.format(_actualSalaries),
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFF60A0FF),
          bgColor: const Color(0xFF0D1225),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: _isCompany ? 'فائض كاشيرات الفروع (+)' : 'فائض كاشير الفرع (+)',
          value: _money.format(_surplusTotal),
          icon: Icons.add_circle_outline_rounded,
          iconColor: AppColors.tertiary,
          bgColor: const Color(0xFF0D1A10),
        ),
      ]),
    ]);
  }

  // ── INCOME STATEMENT TABLE ──────────────────────────────────────────────────
  Widget _buildPnlTable() {
    final rows = [
      (
        _isCompany ? 'مبيعات جميع الفروع الإجمالية' : 'مبيعات الفرع الإجمالية المحققة',
        _salesTotal,
        '100.0%',
        _isCompany ? 'إجمالي إيرادات فواتير المبيعات لكافة الفروع' : 'إيرادات فواتير مبيعات الفرع المكتملة في الفترة',
        const Color(0xFFFFAA00),
      ),
      (
        _isCompany ? 'فائض كاشيرات الفروع (+)' : 'فائض تقفيل كاشير الفرع (+)',
        _surplusTotal,
        _salesTotal > 0
            ? '${(_surplusTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'المبالغ الزائدة المودعة بصناديق الكاشير وتضاف للإيراد',
        AppColors.tertiary,
      ),
      (
        _isCompany
            ? 'مشتريات التوريد للمخزون الرئيسي (-)'
            : 'طلبات الفرع من المخزون كفلوس (بدون مكسب) (-)',
        _suppliesCost,
        _salesTotal > 0
            ? '${(_suppliesCost / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        _isCompany
            ? 'تكلفة طلبات الشراء والتوريد المعتمدة للمستودع من الموردين'
            : 'قيمة المواد والوجبات المسحوبة من المخزن بتكلفة التوريد بدون مكسب',
        const Color(0xFFFF8888),
      ),
      (
        _isCompany ? 'جميع المصروفات التشغيلية المعتمدة (-)' : 'إجمالي مصروفات الفرع المعتمدة (-)',
        _expensesTotal,
        _salesTotal > 0
            ? '${(_expensesTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        _isCompany ? 'كافة سندات وفواتير الصرف لكافة الفروع والإدارة' : 'كافة سندات وفواتير الصرف الخاصة بهذا الفرع',
        const Color(0xFFFF6B6B),
      ),
      (
        _isCompany
            ? 'إجمالي رواتب موظفي الشركة كاملة (إدخال يدوي) (-)'
            : 'قيمة رواتب موظفي الفرع (إدخال يدوي) (-)',
        _actualSalaries,
        _salesTotal > 0
            ? '${(_actualSalaries / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        _isCompany ? 'إجمالي رواتب الشركة الفعلية المدخلة يدوياً للفترة' : 'إجمالي رواتب موظفي الفرع الفعلية المدخلة يدوياً للفترة',
        const Color(0xFF60A0FF),
      ),
      (
        _isCompany ? 'عجز كاشيرات الفروع (للعلم)' : 'عجز كاشير الفرع (للعلم)',
        _shortageTotal,
        _salesTotal > 0
            ? '${(_shortageTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'عجوزات الكاشير المحالة لقسم الـ HR وتخصم من رواتب الكاشيرات',
        const Color(0xFF8A92A3),
      ),
    ];

    return AccSectionCard(
      title: 'جدول قائمة الدخل التفصيلي — $_selectedBranchName',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(3.5),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
            children: ['البند المالي', 'القيمة بالريال (ر.س)', 'النسبة', 'التفاصيل والوصف']
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(h,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A92A3))),
                    ))
                .toList(),
          ),
          ...rows.map((r) => TableRow(
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$1,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(_money.format(r.$2),
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: r.$5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$3,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, color: const Color(0xFF8A92A3))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$4,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, color: const Color(0xFF6C7280))),
                  ),
                ],
              )),
          TableRow(
            decoration: BoxDecoration(
                color: _netProfit >= 0
                    ? const Color(0xFF0E2214)
                    : const Color(0xFF261012)),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text('صافي الدخل التشغيلي النهائي (Net Profit)',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _netProfit >= 0
                            ? AppColors.tertiary
                            : const Color(0xFFFF6B6B))),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(_money.format(_netProfit),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _netProfit >= 0
                            ? AppColors.tertiary
                            : const Color(0xFFFF6B6B))),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  _salesTotal > 0
                      ? '${(_netProfit / _salesTotal * 100).toStringAsFixed(1)}%'
                      : '—',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _netProfit >= 0
                          ? AppColors.tertiary
                          : const Color(0xFFFF6B6B)),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  _netProfit >= 0
                      ? 'صافي ربح محقق بعد خصم كافة المصروفات والمسحوبات والرواتب'
                      : 'عجز في تغطية التكاليف الإجمالية خلال الفترة المحددة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: _netProfit >= 0
                          ? AppColors.tertiary
                          : const Color(0xFFFF6B6B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SALES & EXPENSES BREAKDOWN GRID ─────────────────────────────────────────
  Widget _buildSalesAndExpensesGrid() {
    final sales = (_reportData['sales'] as Map<String, dynamic>?) ?? {};
    final expenses = (_reportData['expenses'] as Map<String, dynamic>?) ?? {};
    final catList = (expenses['by_category'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final cashSales = (sales['cash'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (sales['card'] as num?)?.toDouble() ?? 0.0;
    final taxSales = (sales['tax'] as num?)?.toDouble() ?? 0.0;
    final count = (sales['count'] as num?)?.toInt() ?? 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بطاقة مبيعات وطرق الدفع
      Expanded(
        child: AccSectionCard(
          title: 'تحليل المبيعات وطرق الدفع',
          child: Column(children: [
            _buildDetailRow('مبيعات الكاش (نقدي)', _money.format(cashSales),
                color: AppColors.tertiary),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('مبيعات الشبكة (مدى/بطاقة)', _money.format(cardSales),
                color: const Color(0xFF60A0FF)),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('ضريبة القيمة المضافة المحصلة', _money.format(taxSales),
                color: const Color(0xFFFFAA00)),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('إجمالي عدد الفواتير', '$count فاتورة',
                color: Colors.white),
          ]),
        ),
      ),
      const SizedBox(width: 16),
      // بطاقة تفصيل المصروفات
      Expanded(
        child: AccSectionCard(
          title: 'المصروفات حسب البند (${catList.length})',
          child: catList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد مصروفات مسجلة في هذه الفترة',
                        style: TextStyle(color: Color(0xFF8A92A3))),
                  ),
                )
              : Column(
                  children: catList.map((c) {
                    final catName = c['category']?.toString() ?? 'أخرى';
                    final catTot = (c['total'] as num?)?.toDouble() ?? 0.0;
                    return Column(children: [
                      _buildDetailRow(catName, _money.format(catTot)),
                      const Divider(color: Color(0xFF1E2430), height: 1),
                    ]);
                  }).toList(),
                ),
        ),
      ),
    ]);
  }

  Widget _buildDetailRow(String title, String val, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Text(title,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: Colors.white)),
          const Spacer(),
          Text(val,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? Colors.white)),
        ]),
      );

  // ── WAREHOUSE ORDERS BREAKDOWN ──────────────────────────────────────────────
  Widget _buildWarehouseOrdersSection() {
    return AccSectionCard(
      title: _isCompany
          ? 'طلبيات المستودع للفروع (${_warehouseOrders.length} طلبية)'
          : 'طلبيات هذا الفرع من المستودع الرئيسي (${_warehouseOrders.length} طلبية)',
      child: _warehouseOrders.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('لا توجد طلبيات مسحوبة من المستودع في هذه الفترة',
                    style: TextStyle(color: Color(0xFF8A92A3))),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _warehouseOrders.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Color(0xFF1E2430), height: 1),
              itemBuilder: (_, i) {
                final o = _warehouseOrders[i];
                final lines = (o['lines'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final cost = (o['total_cost'] as num?)?.toDouble() ?? 0.0;
                final dt = DateTime.tryParse(o['created_at']?.toString() ?? '');

                return ExpansionTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFFFFAA00), size: 18),
                  ),
                  title: Row(children: [
                    Text(o['number'] as String? ?? '—',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(width: 10),
                    Text(o['branch_name'] as String? ?? '—',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, color: const Color(0xFF8A92A3))),
                    const Spacer(),
                    Text('القيمة: ${_money.format(cost)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFAA00))),
                  ]),
                  subtitle: Text(
                    'التاريخ: ${dt != null ? _df.format(dt) : '—'}  |  ${lines.length} صنف مسحوب',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11, color: const Color(0xFF8A92A3)),
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0E14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2430)),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.8),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                                color: Color(0xFF1A1E26)),
                            children: ['الصنف', 'الكمية', 'التكلفة بدون مكسب', 'الإجمالي']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      child: Text(h,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF8A92A3))),
                                    ))
                                .toList(),
                          ),
                          ...lines.map((l) => TableRow(
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF1E2430)))),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        '${l['item_name'] ?? '—'} (${l['unit'] ?? ''})',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 12, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text('${l['qty_approved'] ?? '—'}',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        _money.format((l['avg_cost'] as num?)
                                                ?.toDouble() ??
                                            0),
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            color: const Color(0xFF60A0FF))),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        _money.format((l['line_cost'] as num?)
                                                ?.toDouble() ??
                                            0),
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFFFAA00))),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── BRANCH SALES BREAKDOWN TABLE (COMPANY MODE) ───────────────────────────
  Widget _buildBranchSalesBreakdownTable() {
    final byBranch = (_salesSummary['by_branch'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (byBranch.isEmpty) return const SizedBox.shrink();

    return AccSectionCard(
      title: 'مبيعات جميع الفروع وتوزيع الإيرادات (${byBranch.length} فروع)',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(3.0),
          2: FlexColumnWidth(2.0),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
            children: ['م', 'اسم الفرع', 'إجمالي المبيعات (ر.س)', 'عدد الفواتير', 'النسبة من المبيعات']
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(h,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A92A3))),
                    ))
                .toList(),
          ),
          ...byBranch.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final b = entry.value;
            final bName = b['branch_name'] as String? ?? '—';
            final bTotal = (b['total_sales'] as num?)?.toDouble() ?? 0.0;
            final bCount = (b['invoices_count'] as num?)?.toInt() ?? 0;
            final bPct = _salesTotal > 0 ? (bTotal / _salesTotal * 100).toStringAsFixed(1) : '0.0';

            return TableRow(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text('$idx',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: const Color(0xFF8A92A3))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(bName,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(_money.format(bTotal),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFAA00))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text('$bCount فاتورة',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: const Color(0xFF60A0FF))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text('$bPct%',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tertiary)),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── EXPORT EXCEL ────────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    try {
      final byBranchList = (_salesSummary['by_branch'] as List?)
          ?.cast<Map<String, dynamic>>();

      final path = await ComprehensiveReportsExcelService.exportFinancialReport(
        reportData: _reportData,
        actualSalaries: _actualSalaries,
        startDate: _range.start,
        endDate: _range.end,
        branchName: _selectedBranchName,
        warehouseOrders: _warehouseOrders,
        byBranchSales: byBranchList,
      );

      if (!mounted) return;

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير التقرير المالي بنجاح إلى:\n$path'),
            backgroundColor: AppColors.tertiary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تصدير شيت Excel: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }
}
