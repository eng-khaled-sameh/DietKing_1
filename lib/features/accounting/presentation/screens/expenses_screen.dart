import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../../data/expenses_excel_export_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// فئات / تصنيفات المصروفات (مطابقة للكاشير)
const _kExpenseCategories = [
  'مستلزمات تشغيل',
  'نظافة',
  'كهرباء ومياه',
  'مواصلات',
  'مرتجعات',
  'أخرى',
];

// ══════════════════════════════════════════════════════════════════════════════
// ExpensesScreen — صفحة المصروفات
// ══════════════════════════════════════════════════════════════════════════════

class ExpensesScreen extends StatefulWidget {
  final AccountingRepository repo;
  const ExpensesScreen({super.key, required this.repo});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String? _selectedCategory;
  String _selectedStatus = 'all'; // 'all' | 'pending' | 'approved' | 'rejected'
  late DateTimeRange _range;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];

  static final _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س ',
    decimalDigits: 2,
  );

  // تُجمع فئات المصروفات الفريدة من البيانات الواردة
  Set<String> get _categories {
    return _expenses
        .map((e) => e['category'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  String _resolveExpenseStatus(Map<String, dynamic> e) {
    final s = e['status']?.toString().toLowerCase();
    final isBranch = e['branch_id'] != null &&
        e['branch_id'] != '' &&
        e['branch_id'] != 'HQ' &&
        e['branch_name'] != 'الفرع الرئيسي' &&
        e['branch_code'] != 'HQ';

    if (isBranch) {
      if (s == 'approved') return 'approved';
      if (s == 'rejected') return 'rejected';
      return 'pending';
    }

    if (s == 'rejected') return 'rejected';
    return 'approved';
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((e) {
      if (_selectedCategory != null && e['category'] != _selectedCategory) {
        return false;
      }
      final s = _resolveExpenseStatus(e);
      if (_selectedStatus == 'pending' && s != 'pending') return false;
      if (_selectedStatus == 'approved' && s != 'approved') return false;
      if (_selectedStatus == 'rejected' && s != 'rejected') return false;
      return true;
    }).toList();
  }

  int get _pendingCount =>
      _expenses.where((e) => _resolveExpenseStatus(e) == 'pending').length;
  int get _approvedCount =>
      _expenses.where((e) => _resolveExpenseStatus(e) == 'approved').length;
  int get _rejectedCount =>
      _expenses.where((e) => _resolveExpenseStatus(e) == 'rejected').length;

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
      final result = await widget.repo.getAllExpenses(
        from: from,
        to: to,
        branchId: _selectedBranchId,
      );
      final items = (result['items'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _expenses = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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


  // ── Computed KPIs ─────────────────────────────────────────────────────────────
  double get _totalVat => _expenses.fold(
    0.0,
    (s, e) => s + ((e['vat_amount'] as num?)?.toDouble() ?? 0),
  );
  double get _totalNet => _expenses.fold(
    0.0,
    (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0),
  );
  double get _totalCash => _expenses
      .where((e) => e['payment_method'] == 'cash')
      .fold(0.0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));

  Map<String, double> get _byCategory {
    final m = <String, double>{};
    for (final e in _expenses) {
      final cat = e['category'] as String? ?? 'أخرى';
      m[cat] = (m[cat] ?? 0) + ((e['total'] as num?)?.toDouble() ?? 0);
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
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
            const SizedBox(height: 24),
            Row(
              children: [
                AccKpiCard(
                  title: 'إجمالي المصروفات',
                  value: _money.format(_totalNet),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFFFF6B6B),
                  bgColor: const Color(0xFF1A0D0D),
                ),
                const SizedBox(width: 12),
                AccKpiCard(
                  title: 'مدفوع كاش',
                  value: _money.format(_totalCash),
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.tertiary,
                  bgColor: const Color(0xFF0D1A10),
                ),
                const SizedBox(width: 12),
                AccKpiCard(
                  title: 'ضريبة المصروفات',
                  value: _money.format(_totalVat),
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFFFAA00),
                  bgColor: const Color(0xFF1A1400),
                ),
                const SizedBox(width: 12),
                AccKpiCard(
                  title: 'عدد المصروفات',
                  value: '${_expenses.length}',
                  icon: Icons.list_alt_outlined,
                  iconColor: const Color(0xFF8A92A3),
                  bgColor: const Color(0xFF141720),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_byCategory.isNotEmpty) ...[
              _buildCategoryBreakdown(),
              const SizedBox(height: 24),
            ],
            _buildExpensesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة المصروفات',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'مراجعة مصروفات الفروع واعتمادها، وإضافة مصروفات المقر الرئيسي',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: const Color(0xFF8A92A3),
            ),
          ),
        ],
      ),
      const Spacer(),
      AccActionButton(
        icon: Icons.table_view_rounded,
        label: 'تصدير Excel',
        onTap: _exportExcel,
        color: const Color(0xFF107C41),
      ),
      const SizedBox(width: 8),
      AccActionButton(
        icon: Icons.add_circle_outline_rounded,
        label: 'إضافة مصروف',
        onTap: _showAddExpenseDialog,
        color: AppColors.primaryContainer,
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

  Future<void> _exportExcel() async {
    final from = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);

    String? branchName;
    if (_selectedBranchId != null) {
      if (_selectedBranchId == 'HQ') {
        branchName = 'الفرع الرئيسي (الإدارة العامة)';
      } else {
        final b = _branches.firstWhere(
          (b) => b['id'] == _selectedBranchId,
          orElse: () => {'name': null},
        );
        branchName = b['name'] as String?;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إعداد شيت Excel للمصروفات...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final path = await ExpensesExcelExportService.exportExpensesReport(
        expenses: _filteredExpenses,
        startDate: from,
        endDate: to,
        branchName: branchName,
        categoryFilter: _selectedCategory,
      );

      if (!mounted) return;

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF107C41),
            content: Text('تم تصدير شيت Excel بنجاح:\n$path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text('فشل تصدير Excel: $e'),
        ),
      );
    }
  }

  Widget _buildFilters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF141720),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E2430)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Branch
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedBranchId,
                dropdownColor: const Color(0xFF1A1E26),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Color(0xFF1A1E26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الفروع')),
                  const DropdownMenuItem(
                    value: 'HQ',
                    child: Text('🏢 الفرع الرئيسي (الإدارة العامة)'),
                  ),
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
            ),
            const SizedBox(width: 12),
            // Category
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedCategory,
                dropdownColor: const Color(0xFF1A1E26),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Color(0xFF1A1E26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الفئات')),
                  ..._categories.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedCategory = v);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            // Date range
            InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                      '${DateFormat('dd/MM').format(_range.start)} — ${DateFormat('dd/MM/yyyy').format(_range.end)}',
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
        const SizedBox(height: 14),
        // تبويبات فلترة الحالة: الكل / قيد المراجعة / المعتمدة / المرفوضة
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusFilterChip(
              label: 'كل المصروفات',
              count: _expenses.length,
              statusKey: 'all',
              activeColor: AppColors.primaryContainer,
            ),
            _statusFilterChip(
              label: 'قيد المراجعة',
              count: _pendingCount,
              statusKey: 'pending',
              activeColor: const Color(0xFFFFAA00),
            ),
            _statusFilterChip(
              label: 'تم الاعتماد',
              count: _approvedCount,
              statusKey: 'approved',
              activeColor: AppColors.tertiary,
            ),
            _statusFilterChip(
              label: 'مرفوضة',
              count: _rejectedCount,
              statusKey: 'rejected',
              activeColor: const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusFilterChip({
    required String label,
    required int count,
    required String statusKey,
    required Color activeColor,
  }) {
    final isSelected = _selectedStatus == statusKey;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = statusKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF1A1E26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF262C3A),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF8A92A3),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.25)
                    : const Color(0xFF262C3A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF8A92A3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() => AccSectionCard(
    title: 'توزيع المصروفات بالفئة',
    child: Column(
      children: _byCategory.entries.take(10).map((e) {
        final pct = _totalNet > 0 ? e.value / _totalNet : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    e.key,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _money.format(e.value),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: const Color(0xFF8A92A3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.toDouble(),
                  minHeight: 5,
                  backgroundColor: const Color(0xFF1E2430),
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildExpensesList() {
    final list = _filteredExpenses;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _selectedStatus == 'pending'
                    ? Icons.check_circle_outline_rounded
                    : Icons.receipt_long_outlined,
                size: 44,
                color: const Color(0xFF8A92A3).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedStatus == 'pending'
                    ? 'لا توجد مصروفات بانتظار المراجعة والاعتماد'
                    : 'لا توجد مصروفات مطابقة للبحث في هذه الفترة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  color: const Color(0xFF8A92A3),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AccSectionCard(
      title: 'المصروفات (${list.length})',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) => _ExpenseTile(
          expense: list[i],
          repo: widget.repo,
          onRefresh: _load,
          money: _money,
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    String? selectedCategory = _kExpenseCategories.first;
    final payeeCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final vatCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String? selectedBranchId = 'HQ';
    String paymentMethod = 'cash';
    var expenseDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Dialog(
            backgroundColor: const Color(0xFF141720),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF262C3A)),
            ),
            child: Container(
              width: 540,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // رأس الديالوج
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1E26),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF262C3A)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إضافة مصروف جديد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'يمكن تسجيل مصروف للفرع الرئيسي أو أحد الفروع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  color: const Color(0xFF8A92A3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8A92A3)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  // محتوى قابل للتمرير
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الفرع
                          _DlgLabel('الفرع *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            dropdownColor: const Color(0xFF1A1E26),
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: _dlgInputDecoration(),
                            initialValue: selectedBranchId,
                            items: [
                              const DropdownMenuItem(
                                value: 'HQ',
                                child: Text('🏢 الفرع الرئيسي (الإدارة العامة)'),
                              ),
                              ..._branches.map(
                                (b) => DropdownMenuItem(
                                  value: b['id'] as String,
                                  child: Text(b['name'] as String? ?? ''),
                                ),
                              ),
                            ],
                            onChanged: (v) => setDlg(() => selectedBranchId = v),
                          ),
                          const SizedBox(height: 16),

                          // الفئة / التصنيف
                          _DlgLabel('الفئة / التصنيف *'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _kExpenseCategories.map((cat) {
                              final isSelected = selectedCategory == cat;
                              return InkWell(
                                onTap: () => setDlg(() => selectedCategory = cat),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryContainer.withValues(alpha: 0.18)
                                        : const Color(0xFF1A1E26),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryContainer
                                          : const Color(0xFF2E3545),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 13,
                                          color: AppColors.primaryContainer,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        cat,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primaryContainer
                                              : const Color(0xFFC0C7D5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // الجهة المدفوع لها
                          AccDlgField(
                            'الجهة المدفوع لها (اختياري)',
                            hint: 'مثال: شركة المياه، مؤجر العقار',
                            ctrl: payeeCtrl,
                          ),
                          const SizedBox(height: 10),
                          AccDlgField(
                            'الوصف (اختياري)',
                            hint: 'وصف المصروف',
                            ctrl: descriptionCtrl,
                          ),
                          const SizedBox(height: 10),

                          // المبلغ و الضريبة
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _DlgLabel('المبلغ *'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: amountCtrl,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _dlgInputDecoration(
                                        hint: '0.00',
                                        prefix: Text(
                                          'ر.س  ',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: const Color(0xFF8A92A3),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _DlgLabel('ضريبة القيمة المضافة'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: vatCtrl,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _dlgInputDecoration(
                                        hint: '0.00',
                                        prefix: Text(
                                          'ر.س  ',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: const Color(0xFF8A92A3),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // طريقة الدفع
                          _DlgLabel('طريقة الدفع'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _PayMethodChip(
                                label: 'نقدي (Cash)',
                                icon: Icons.payments_rounded,
                                selected: paymentMethod == 'cash',
                                onTap: () => setDlg(() => paymentMethod = 'cash'),
                              ),
                              const SizedBox(width: 8),
                              _PayMethodChip(
                                label: 'آخر',
                                icon: Icons.credit_card_rounded,
                                selected: paymentMethod == 'other',
                                onTap: () => setDlg(() => paymentMethod = 'other'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // تاريخ المصروف
                          _DlgLabel('تاريخ المصروف'),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: expenseDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                                locale: const Locale('ar'),
                              );
                              if (picked != null) setDlg(() => expenseDate = picked);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1E26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2E3545)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: AppColors.primaryContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('EEEE, dd MMMM yyyy', 'ar').format(expenseDate),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF8A92A3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ملاحظات
                          AccDlgField(
                            'ملاحظات (اختياري)',
                            hint: 'أي تفاصيل إضافية',
                            ctrl: notesCtrl,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ذيل الديالوج مع أزرار الحفظ
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1E26),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(color: Color(0xFF262C3A)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: Color(0xFF8A92A3)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: const Color(0xFF0D0D0D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            'حفظ المصروف',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () async {
                            final cat = selectedCategory ?? '';
                            final amt = double.tryParse(amountCtrl.text);
                            if (selectedBranchId == null ||
                                cat.isEmpty ||
                                amt == null ||
                                amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF8B2500),
                                  content: Text(
                                    'يرجى اختيار الفرع والفئة وإدخال المبلغ بشكل صحيح',
                                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                                  ),
                                ),
                              );
                              return;
                            }
                            final vat = double.tryParse(vatCtrl.text) ?? 0;
                            Navigator.pop(ctx);
                            try {
                              final isHq = selectedBranchId == 'HQ';
                              await widget.repo.createExpense({
                                'client_id': const Uuid().v4(),
                                'session_id': isHq ? null : const Uuid().v4(),
                                'branch_id': isHq ? null : selectedBranchId,
                                'branch_name': isHq ? 'الفرع الرئيسي' : null,
                                'category': cat,
                                'payee': payeeCtrl.text.trim().isEmpty
                                    ? null
                                    : payeeCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim().isEmpty
                                    ? null
                                    : descriptionCtrl.text.trim(),
                                'amount': amt,
                                'vat_amount': vat,
                                'payment_method': paymentMethod,
                                'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
                                'notes': notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                                'status': isHq ? 'approved' : 'pending',
                              });
                              await _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF1B365D),
                                    content: Text(
                                      isHq
                                          ? 'تم تسجيل مصروف الفرع الرئيسي واعتماده بنجاح'
                                          : 'تم إضافة المصروف بنجاح وسيخضع لمراجعة المحاسب',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade800,
                                    content: Text('خطأ: $e'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Expense Tile with status badge and approve/reject actions ─────────────────
class _ExpenseTile extends StatefulWidget {
  final Map<String, dynamic> expense;
  final AccountingRepository repo;
  final VoidCallback onRefresh;
  final NumberFormat money;
  const _ExpenseTile({
    required this.expense,
    required this.repo,
    required this.onRefresh,
    required this.money,
  });

  @override
  State<_ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<_ExpenseTile> {
  bool _busy = false;

  Map<String, dynamic> get e => widget.expense;

  Future<void> _decide(String status) async {
    String? reason;
    if (status == 'rejected') {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF141720),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF262C3A)),
            ),
            title: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                Text(
                  'سبب رفض المصروف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            content: AccDlgField(
              'ملاحظات الرفض',
              hint: 'اكتب سبب رفض الفاتورة ليظهر للكاشير في الفرع',
              ctrl: ctrl,
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'تراجع',
                  style: TextStyle(color: Color(0xFF8A92A3)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد الرفض'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      reason = ctrl.text.trim();
    }

    setState(() => _busy = true);
    try {
      final id = (e['id'] ?? e['client_id']).toString();
      final branchId = e['branch_id'] as String?;
      final invNum = e['invoice_number'] as String? ?? e['number'] as String?;
      final total = (e['total'] as num?)?.toDouble();

      await widget.repo.decideExpense(
        expenseId: id,
        status: status,
        reason: reason,
        branchId: branchId,
        invoiceNumber: invNum,
        total: total,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: status == 'approved'
                ? const Color(0xFF1B365D)
                : const Color(0xFF8B2500),
            content: Text(
              status == 'approved'
                  ? 'تم اعتماد فاتورة المصروف وإشعار الفرع بنجاح'
                  : 'تم رفض فاتورة المصروف وإشعار الفرع بالسبب',
            ),
          ),
        );
        widget.onRefresh();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء المعالجة: $err'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (e['total'] as num?)?.toDouble() ?? 0;
    final method = e['payment_method'] as String? ?? '';
    final date = DateTime.tryParse(e['expense_date'] as String? ?? '');
    final rawStatus = e['status']?.toString().toLowerCase();
    final isBranch = e['branch_id'] != null &&
        e['branch_id'] != '' &&
        e['branch_id'] != 'HQ' &&
        e['branch_name'] != 'الفرع الرئيسي' &&
        e['branch_code'] != 'HQ';
    final String status;
    if (isBranch) {
      if (rawStatus == 'approved') {
        status = 'approved';
      } else if (rawStatus == 'rejected') {
        status = 'rejected';
      } else {
        status = 'pending';
      }
    } else {
      status = (rawStatus == 'rejected') ? 'rejected' : 'approved';
    }
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final branchName = e['branch_name'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // رقم المصروف
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e['number'] as String? ??
                      e['invoice_number'] as String? ??
                      '—',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // الفئة
              Expanded(
                child: Text(
                  e['category'] as String? ?? '—',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              // الشارة الحالة
              _StatusBadge(status: status),
              const SizedBox(width: 10),
              // المبلغ
              Text(
                widget.money.format(total),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isRejected
                      ? const Color(0xFF8A92A3)
                      : const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.store_outlined,
                size: 13,
                color: Color(0xFF8A92A3),
              ),
              const SizedBox(width: 4),
              Text(
                branchName ?? 'المقر الرئيسي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: const Color(0xFF8A92A3),
                ),
              ),
              if (e['payee'] != null) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: Color(0xFF8A92A3),
                ),
                const SizedBox(width: 4),
                Text(
                  e['payee'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: const Color(0xFF8A92A3),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: Color(0xFF8A92A3),
              ),
              const SizedBox(width: 4),
              Text(
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '—',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: const Color(0xFF8A92A3),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      (method == 'cash'
                              ? AppColors.tertiary
                              : const Color(0xFFFFAA00))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method == 'cash' ? 'كاش' : 'آخر',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: method == 'cash'
                        ? AppColors.tertiary
                        : const Color(0xFFFFAA00),
                  ),
                ),
              ),
            ],
          ),
          if (e['notes'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.notes_outlined,
                  size: 13,
                  color: Color(0xFF636E7E),
                ),
                const SizedBox(width: 4),
                Text(
                  e['notes'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: const Color(0xFF636E7E),
                  ),
                ),
              ],
            ),
          ],
          if (isRejected &&
              (e['decision_notes'] != null &&
                  e['decision_notes'].toString().isNotEmpty)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: Color(0xFFFF6B6B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سبب الرفض: ${e['decision_notes']}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending && !_busy) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary.withValues(alpha: 0.15),
                    foregroundColor: AppColors.tertiary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('اعتماد', style: TextStyle(fontSize: 12)),
                  onPressed: () => _decide('approved'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFFF6B6B,
                    ).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFFF6B6B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('رفض', style: TextStyle(fontSize: 12)),
                  onPressed: () => _decide('rejected'),
                ),
              ],
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'قيد المراجعة';
        color = const Color(0xFFFFAA00);
        break;
      case 'approved':
      case 'posted':
        label = 'تم الاعتماد';
        color = AppColors.tertiary;
        break;
      case 'rejected':
        label = 'مرفوضة';
        color = const Color(0xFFFF6B6B);
        break;
      default:
        label = status;
        color = const Color(0xFF8A92A3);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Dialog helpers ─────────────────────────────────────────────────────────────

/// تسمية حقل داخل ديالوج الإضافة
class _DlgLabel extends StatelessWidget {
  final String text;
  const _DlgLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF8A92A3),
        letterSpacing: 0.3,
      ),
    );
  }
}

/// زر اختيار طريقة الدفع
class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer.withValues(alpha: 0.15)
              : const Color(0xFF1A1E26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryContainer : const Color(0xFF2E3545),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primaryContainer : const Color(0xFF8A92A3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primaryContainer : const Color(0xFFC0C7D5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// decoration موحد لحقول الإدخال في ديالوج الإضافة
InputDecoration _dlgInputDecoration({String? hint, Widget? prefix}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: GoogleFonts.spaceGrotesk(
      color: const Color(0xFF4A5265),
      fontSize: 13,
    ),
    prefix: prefix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: const Color(0xFF1A1E26),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2E3545)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2E3545)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
    ),
  );
}
