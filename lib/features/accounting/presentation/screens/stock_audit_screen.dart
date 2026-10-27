import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_saved_dialog.dart';
import '../../data/accounting_repository.dart';
import '../../data/stock_audit_excel_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// StockAuditScreen — جرد المخزون ومراجعة وتدقيق الجرودات وتطبيق خصومات العمالة
// ══════════════════════════════════════════════════════════════════════════════

class StockAuditScreen extends StatefulWidget {
  final AccountingRepository repo;
  const StockAuditScreen({super.key, required this.repo});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _audits = [];

  // فلاتر
  int _selectedPeriod = 2; // 0=اليوم, 1=الأسبوع, 2=الشهر, 3=الكل, 4=مخصص
  DateTimeRange? _customRange;
  String _statusFilter = 'all'; // 'all' | 'pending_review' | 'approved' | 'approved_with_deduction'
  String _searchQuery = '';

  static final _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س ',
    decimalDigits: 2,
  );
  static final _df = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTimeRange? get _activeRange {
    final now = DateTime.now();
    return switch (_selectedPeriod) {
      0 => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      1 => DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      2 => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      3 => null, // الكل
      4 => _customRange,
      _ => null,
    };
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final range = _activeRange;
      final results = await widget.repo.getStocktakeAudits(
        from: range?.start,
        to: range?.end,
      );

      if (mounted) {
        setState(() {
          _audits = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAudits {
    return _audits.where((a) {
      // فلتر الحالة
      final status = a['review_status'] ?? 'pending_review';
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      // البحث
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final num = (a['number'] ?? '').toString().toLowerCase();
        final empName = (a['deduction_employee_name'] ?? '').toString().toLowerCase();
        final notes = (a['notes'] ?? '').toString().toLowerCase();
        final reviewer = (a['reviewer_name'] ?? '').toString().toLowerCase();
        if (!num.contains(q) && !empName.contains(q) && !notes.contains(q) && !reviewer.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ── KPI Getters ─────────────────────────────────────────────────────────────
  int get _totalCount => _audits.length;
  int get _pendingCount => _audits.where((a) => (a['review_status'] ?? 'pending_review') == 'pending_review').length;
  int get _approvedCount => _audits.where((a) => a['review_status'] == 'approved').length;
  int get _deductionCount => _audits.where((a) => a['review_status'] == 'approved_with_deduction').length;

  double get _totalShortageVal => _audits.fold(0.0, (sum, a) => sum + ((a['shortage_value'] as num?)?.toDouble() ?? 0.0));
  double get _totalDeductionVal => _audits.fold(0.0, (sum, a) => sum + ((a['deduction_amount'] as num?)?.toDouble() ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopHeader(),
            const SizedBox(height: 16),
            _buildKpiCards(),
            const SizedBox(height: 16),
            _buildFilterBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? AccErrorWidget(message: _error!, onRetry: _loadData)
                      : _filteredAudits.isEmpty
                          ? _buildEmptyState()
                          : _buildAuditsList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header ──────────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.fact_check, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جرد المخزون والتدقيق المالي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'تسجيل عمليات الجرد، تدقيق الفروقات، ومراجعتها مع إمكانية تحديد خصم لعمال المطبخ والمخزون وإرساله لـ HR',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // زر تصدير Excel
            OutlinedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.download, size: 18, color: Color(0xFF38BDF8)),
              label: Text(
                'تصدير Excel',
                style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7)),
                backgroundColor: const Color(0xFF0369A1).withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 10),
            // زر تسجيل جرد جديد
            FilledButton.icon(
              onPressed: _showNewStocktakeDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'تسجيل عملية جرد جديدة',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 10),
            // زر التحديث
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
              tooltip: 'تحديث البيانات',
            ),
          ],
        ),
      ],
    );
  }

  // ── KPI Summary Cards ───────────────────────────────────────────────────────
  Widget _buildKpiCards() {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'إجمالي الجرودات',
            value: '$_totalCount عملية',
            sub: '$_approvedCount معتمدة | $_pendingCount بانتظار المراجعة',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            title: 'بانتظار المراجعة والتدقيق',
            value: '$_pendingCount عملية',
            sub: 'تحتاج مراجعة المحاسب واعتمادها',
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            title: 'إجمالي قيمة العجز المالي',
            value: _money.format(_totalShortageVal),
            sub: 'القيمة المالية للأصناف الناقصة',
            icon: Icons.trending_down_outlined,
            color: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            title: 'خصومات محولة لـ HR',
            value: _money.format(_totalDeductionVal),
            sub: '$_deductionCount عملية تم تطبيق خصم لعمالها',
            icon: Icons.badge_outlined,
            color: const Color(0xFFA855F7),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // فترة التاريخ
          _periodChip('اليوم', 0),
          const SizedBox(width: 6),
          _periodChip('الأسبوع', 1),
          const SizedBox(width: 6),
          _periodChip('الشهر', 2),
          const SizedBox(width: 6),
          _periodChip('الكل', 3),
          const SizedBox(width: 6),
          _periodChip('مخصص', 4),
          const SizedBox(width: 16),
          Container(height: 24, width: 1, color: const Color(0xFF334155)),
          const SizedBox(width: 16),

          // فلتر الحالة
          DropdownButton<String>(
            value: _statusFilter,
            dropdownColor: const Color(0xFF1E293B),
            underline: const SizedBox(),
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
              DropdownMenuItem(value: 'pending_review', child: Text('قيد المراجعة فقط')),
              DropdownMenuItem(value: 'approved', child: Text('معتمد بدون خصم')),
              DropdownMenuItem(value: 'approved_with_deduction', child: Text('معتمد مع خصم عمالة')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _statusFilter = val);
            },
          ),
          const Spacer(),

          // حقل البحث
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'بحث برقم الجرد، العامل، أو الملاحظة...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return InkWell(
      onTap: () async {
        if (index == 4) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2023),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDateRange: _customRange ?? DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
          );
          if (picked != null) {
            setState(() {
              _customRange = picked;
              _selectedPeriod = 4;
            });
            _loadData();
          }
          return;
        }

        setState(() => _selectedPeriod = index);
        _loadData();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── Audits List View ────────────────────────────────────────────────────────
  Widget _buildAuditsList() {
    final list = _filteredAudits;
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = list[index];
        return _buildAuditCard(a);
      },
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> a) {
    final stId = a['id'].toString();
    final number = a['number'] ?? 'STK-0000';
    final dtStr = a['created_at'] != null ? _df.format(DateTime.parse(a['created_at'].toString()).toLocal()) : '';
    final itemsCount = (a['total_items'] as num?)?.toInt() ?? 0;
    final adjustQty = (a['total_adjust'] as num?)?.toDouble() ?? 0.0;
    final damageQty = (a['total_damage'] as num?)?.toDouble() ?? 0.0;
    final shortageVal = (a['shortage_value'] as num?)?.toDouble() ?? 0.0;
    final status = a['review_status'] ?? 'pending_review';
    final deductAmount = (a['deduction_amount'] as num?)?.toDouble() ?? 0.0;
    final empName = a['deduction_employee_name'];
    final empRole = a['deduction_employee_role'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'معتمد ومراجع (بدون خصومات)';
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'approved_with_deduction') {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'معتمد مع خصم عمالة';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'قيد المراجعة والتدقيق';
      statusIcon = Icons.hourglass_top_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'pending_review' ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      number,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dtStr,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          const SizedBox(height: 12),

          // Details Row
          Row(
            children: [
              _metricBlock('عدد الأصناف', '$itemsCount صنف', Icons.list_alt),
              _metricBlock('صافي التعديل (كمية)', '${adjustQty > 0 ? '+' : ''}${adjustQty.toStringAsFixed(1)}', Icons.tune,
                  color: adjustQty >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              _metricBlock('إجمالي التالف (كمية)', damageQty.toStringAsFixed(1), Icons.delete_outline,
                  color: damageQty > 0 ? const Color(0xFFEF4444) : AppColors.onSurfaceVariant),
              _metricBlock('قيمة العجز المالي', _money.format(shortageVal), Icons.monetization_on_outlined,
                  color: shortageVal > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), bold: true),
            ],
          ),

          // الخصم إن وجد
          if (status == 'approved_with_deduction' && deductAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_remove_outlined, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text(
                    'تم تسجيل خصم بقيمة ${_money.format(deductAmount)} على العامل: $empName (${_roleLabel(empRole)}) وإرساله إلى HR',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
          ],

          if (a['review_notes'] != null && a['review_notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'ملاحظات المراجعة: ${a['review_notes']}',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: 12),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // زر عرض الأصناف
              OutlinedButton.icon(
                onPressed: () => _showAuditDetailsDialog(stId, number),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(
                  'عرض ومطابقة الأصناف',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 10),
              // زر مراجعة الجرد والخصم
              FilledButton.icon(
                onPressed: () => _showReviewAndDeductDialog(a),
                icon: Icon(
                  status == 'pending_review' ? Icons.rate_review_outlined : Icons.edit_note,
                  size: 16,
                ),
                label: Text(
                  status == 'pending_review' ? 'مراجعة واعتماد الجرد / تحديد خصم' : 'تعديل المراجعة أو الخصم',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: status == 'pending_review' ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock(String label, String value, IconData icon, {Color? color, bool bold = false}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: AppColors.onSurfaceVariant),
              ),
              Text(
                value,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialog: عرض ومطابقة أصناف الجرد ──────────────────────────────────────
  Future<void> _showAuditDetailsDialog(String stocktakeId, String number) async {
    showDialog(
      context: context,
      builder: (ctx) => _AuditDetailsDialog(
        stocktakeId: stocktakeId,
        number: number,
        repo: widget.repo,
      ),
    );
  }

  // ── Dialog: مراجعة واعتماد الجرد وتحديد الخصم ─────────────────────────────
  Future<void> _showReviewAndDeductDialog(Map<String, dynamic> audit) async {
    final stId = audit['id'].toString();
    final number = audit['number'] ?? 'STK';
    final shortageVal = (audit['shortage_value'] as num?)?.toDouble() ?? 0.0;

    await showDialog(
      context: context,
      builder: (ctx) => _ReviewAuditDialog(
        audit: audit,
        stocktakeId: stId,
        number: number,
        shortageValue: shortageVal,
        repo: widget.repo,
        onSuccess: _loadData,
      ),
    );
  }

  // ── Dialog: تسجيل عملية جرد جديدة ────────────────────────────────────────
  Future<void> _showNewStocktakeDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _NewStocktakeDialog(
        repo: widget.repo,
        onSuccess: _loadData,
      ),
    );
  }

  // ── Export Excel ────────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    final list = _filteredAudits;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عمليات جرد لتصديرها')),
      );
      return;
    }

    try {
      final path = await StockAuditExcelService.exportStockAuditsReport(
        audits: list,
        startDate: _activeRange?.start,
        endDate: _activeRange?.end,
      );

      if (path != null && mounted) {
        showFileSavedDialog(context, path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التصدير: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'لا توجد عمليات جرد مسجلة في هذا النطاق',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _showNewStocktakeDialog,
            icon: const Icon(Icons.add),
            label: const Text('تسجيل أول عملية جرد الآن'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String? role) {
    return switch (role) {
      'kitchen_worker' => 'عامل مطبخ',
      'chef'           => 'طاهي / شيف',
      'storekeeper'    => 'أمين مخزن',
      'worker'         => 'عامل تشغيل / مخزن',
      _                => role ?? 'عامل',
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog: عرض تفاصيل سطور الجرد ومطابقة الأصناف
// ══════════════════════════════════════════════════════════════════════════════

class _AuditDetailsDialog extends StatefulWidget {
  final String stocktakeId;
  final String number;
  final AccountingRepository repo;

  const _AuditDetailsDialog({
    required this.stocktakeId,
    required this.number,
    required this.repo,
  });

  @override
  State<_AuditDetailsDialog> createState() => _AuditDetailsDialogState();
}

class _AuditDetailsDialogState extends State<_AuditDetailsDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lines = [];

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  Future<void> _loadLines() async {
    try {
      final lines = await widget.repo.getStocktakeLines(widget.stocktakeId);
      if (mounted) {
        setState(() {
          _lines = lines;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131924),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 850,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.compare_arrows, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'مطابقة وتفاصيل أصناف الجرد: ${widget.number}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!_loading)
                      IconButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _loadLines();
                        },
                        icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
                        tooltip: 'إعادة التحميل',
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF1E293B)),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'حدث خطأ أثناء تحميل البنود',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.red.shade300),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() { _loading = true; _error = null; });
                                  _loadLines();
                                },
                                icon: const Icon(Icons.refresh),
                                label: Text('إعادة المحاولة', style: GoogleFonts.ibmPlexSansArabic()),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                              ),
                            ],
                          ),
                        )
                      : _lines.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد بنود مسجلة لهذا الجرد',
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : _buildTable(),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3), // الصنف
          1: FlexColumnWidth(1.2), // الرصيد النظامي
          2: FlexColumnWidth(1.2), // الفعلي
          3: FlexColumnWidth(1.2), // الفرق
          4: FlexColumnWidth(1.2), // التالف
          5: FlexColumnWidth(1.5), // تكلفة الوحدة
          6: FlexColumnWidth(1.8), // قيمة العجز
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            children: [
              _th('الصنف (SKU)'),
              _th('النظامي'),
              _th('الفعلي'),
              _th('الفرق'),
              _th('التالف'),
              _th('التكلفة'),
              _th('قيمة العجز'),
            ],
          ),
          ..._lines.map((l) {
            final name = l['name'] ?? '-';
            final sku = l['sku'] ?? '';
            final unit = l['unit_code'] ?? '';
            final sys = (l['system_qty'] as num?)?.toDouble() ?? 0.0;
            final cnt = (l['counted_qty'] as num?)?.toDouble() ?? 0.0;
            final adj = (l['adjust_qty'] as num?)?.toDouble() ?? 0.0;
            final dmg = (l['damaged_qty'] as num?)?.toDouble() ?? 0.0;
            final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0.0;
            final shortage = (l['shortage_value'] as num?)?.toDouble() ?? 0.0;

            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('$sku • $unit', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                _td('${sys.toStringAsFixed(1)} $unit'),
                _td('${cnt.toStringAsFixed(1)} $unit'),
                _td('${adj > 0 ? '+' : ''}${adj.toStringAsFixed(1)}',
                    color: adj < 0 ? Colors.red : (adj > 0 ? Colors.green : Colors.white)),
                _td(dmg > 0 ? dmg.toStringAsFixed(1) : '-', color: dmg > 0 ? Colors.red : null),
                _td(_money.format(cost)),
                _td(shortage > 0 ? _money.format(shortage) : '-',
                    color: shortage > 0 ? Colors.red : Colors.white, bold: shortage > 0),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(t, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _td(String t, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(t, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: color ?? Colors.white, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog: مراجعة الجرد وتحديد خصم على عمال المطبخ أو المخزون فقط
// ══════════════════════════════════════════════════════════════════════════════

class _ReviewAuditDialog extends StatefulWidget {
  final Map<String, dynamic> audit;
  final String stocktakeId;
  final String number;
  final double shortageValue;
  final AccountingRepository repo;
  final VoidCallback onSuccess;

  const _ReviewAuditDialog({
    required this.audit,
    required this.stocktakeId,
    required this.number,
    required this.shortageValue,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<_ReviewAuditDialog> createState() => _ReviewAuditDialogState();
}

class _ReviewAuditDialogState extends State<_ReviewAuditDialog> {
  bool _loading = false;
  bool _loadingWorkers = true;
  bool _applyDeduction = false; // هل يريد تطبيق خصم أم اعتماد دون خصم
  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _workers = [];
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _reviewerCtrl = TextEditingController(text: 'المحاسب');

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _applyDeduction = widget.audit['review_status'] == 'approved_with_deduction' || widget.shortageValue > 0;
    if (widget.shortageValue > 0) {
      _amountCtrl.text = widget.shortageValue.toStringAsFixed(2);
      _notesCtrl.text = 'خصم عجز ناتج عن جرد المخزون رقم ${widget.number} بقيمة ${_money.format(widget.shortageValue)}';
    } else {
      _notesCtrl.text = 'مطابق ومعتمد من المحاسب';
    }

    if (widget.audit['deduction_amount'] != null && (widget.audit['deduction_amount'] as num) > 0) {
      _amountCtrl.text = (widget.audit['deduction_amount'] as num).toDouble().toStringAsFixed(2);
    }
    if (widget.audit['deduction_employee_id'] != null) {
      _selectedEmployeeId = widget.audit['deduction_employee_id'].toString();
    }
    if (widget.audit['review_notes'] != null) {
      _notesCtrl.text = widget.audit['review_notes'].toString();
    }

    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _loadingWorkers = true);
    final list = await widget.repo.getKitchenAndWarehouseEmployees();
    if (mounted) {
      setState(() {
        _workers = list;
        _loadingWorkers = false;
        if (_selectedEmployeeId == null && list.isNotEmpty) {
          _selectedEmployeeId = list.first['id'].toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _reviewerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    if (!_applyDeduction) {
      // اعتماد دون خصم
      final res = await widget.repo.approveStocktakeWithoutDeduction(
        stocktakeId: widget.stocktakeId,
        notes: _notesCtrl.text.trim(),
        reviewerName: _reviewerCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _loading = false);
        if (res['success'] == true) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتماد الجرد بنجاح بدون خصومات'), backgroundColor: Color(0xFF10B981)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: ${res['error'] ?? 'فشلت العملية'}'), backgroundColor: AppColors.error),
          );
        }
      }
    } else {
      // اعتماد مع خصم لعمال المطبخ والمخزون
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      if (amount <= 0) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال مبلغ خصم صحيح أكبر من الصفر'), backgroundColor: AppColors.error),
        );
        return;
      }

      if (_selectedEmployeeId == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار عامل من عمال المطبخ أو المخزون'), backgroundColor: AppColors.error),
        );
        return;
      }

      final res = await widget.repo.submitStocktakeDeduction(
        stocktakeId: widget.stocktakeId,
        employeeId: _selectedEmployeeId!,
        amount: amount,
        notes: _notesCtrl.text.trim(),
        reviewerName: _reviewerCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _loading = false);
        if (res['success'] == true) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم اعتماد الجرد وإرسال طلب الخصم بنجاح إلى الموارد البشرية HR'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: ${res['error'] ?? 'فشلت العملية'}'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131924),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'مراجعة وتدقيق الجرد: ${widget.number}',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFF1E293B)),
              const SizedBox(height: 16),

              // بطاقة ملخص العجز
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.shortageValue > 0 ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.shortageValue > 0 ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.shortageValue > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: widget.shortageValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.shortageValue > 0 ? 'يوجد عجز مالي في هذا الجرد' : 'لا يوجد عجز مالي مسجل في هذا الجرد',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: widget.shortageValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            'القيمة التقديرية للعجز: ${_money.format(widget.shortageValue)}',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // خيار نوع الاعتماد
              Text(
                'قرار المحاسب:',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),

              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _applyDeduction,
                      activeColor: const Color(0xFF10B981),
                      title: Text(
                        'اعتماد الجرد دون تطبيق أي خصومات (الفروقات مقبولة أو مسواة)',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
                      ),
                      onChanged: (val) => setState(() => _applyDeduction = val!),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _applyDeduction,
                      activeColor: const Color(0xFFEF4444),
                      title: Text(
                        'اعتماد الجرد وتحديد خصم لعمال المطبخ / المخزون وإرساله لـ HR',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onChanged: (val) => setState(() => _applyDeduction = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // إذا اختار تطبيق خصم
              if (_applyDeduction) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Text(
                            'تحديد العامل المخصوم عليه (عمال المطبخ والمخزون حصراً):',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dropdown الموظفين
                      if (_loadingWorkers)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'جاري تحميل عمال المطبخ والمخزون...',
                              style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        )
                      else if (_workers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'لم يتم العثور على عمال محددين بدور (مطبخ / مخزون) في النظام.',
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.amber),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () async {
                                  setState(() => _loadingWorkers = true);
                                  final all = await widget.repo.getEmployeesSalaries(status: 'active', limit: 200);
                                  final items = List<Map<String, dynamic>>.from(all['items'] as List? ?? []);
                                  if (mounted) {
                                    setState(() {
                                      _workers = items;
                                      _loadingWorkers = false;
                                      if (items.isNotEmpty) _selectedEmployeeId = items.first['id']?.toString();
                                    });
                                  }
                                },
                                icon: const Icon(Icons.people, size: 14),
                                label: const Text('عرض جميع موظفي الشركة للاختيار منهم'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedEmployeeId,
                          dropdownColor: const Color(0xFF1E293B),
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'اختر العامل المسئول',
                            prefixIcon: Icon(Icons.person, color: Color(0xFFEF4444)),
                          ),
                          items: _workers.map((w) {
                            final role = _StockAuditScreenState._roleLabel(w['job_role']);
                            final branch = w['branch_name'] != null ? ' - ${w['branch_name']}' : '';
                            return DropdownMenuItem(
                              value: w['id'].toString(),
                              child: Text('${w['full_name']} ($role$branch)'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedEmployeeId = val),
                        ),
                      const SizedBox(height: 12),

                      // قيمة الخصم
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'قيمة الخصم المطلوبة (ر.س)',
                          prefixIcon: Icon(Icons.money_off, color: Color(0xFFEF4444)),
                          suffixText: 'ر.س',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // سبب الخصم أو ملاحظات المراجعة
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: _applyDeduction ? 'سبب الخصم وملاحظات الإرسال للـ HR' : 'ملاحظات اعتماد الجرد',
                  hintText: 'اكتب تفاصيل قرار المراجعة...',
                ),
              ),
              const SizedBox(height: 12),

              // اسم المراجع
              TextField(
                controller: _reviewerCtrl,
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'اسم المحاسب / المراجع',
                  prefixIcon: Icon(Icons.badge, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_applyDeduction ? Icons.send : Icons.check),
                    label: Text(
                      _applyDeduction ? 'إرسال الخصم لـ HR واعتماد الجرد' : 'اعتماد الجرد دون خصم',
                      style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _applyDeduction ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog: تسجيل عملية جرد جديدة وإدخال الأصناف
// ══════════════════════════════════════════════════════════════════════════════

class _NewStocktakeDialog extends StatefulWidget {
  final AccountingRepository repo;
  final VoidCallback onSuccess;

  const _NewStocktakeDialog({
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<_NewStocktakeDialog> createState() => _NewStocktakeDialogState();
}

class _NewStocktakeDialogState extends State<_NewStocktakeDialog> {
  bool _loadingCatalog = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _catalog = [];
  final List<_AuditEntryRow> _lines = [];
  final TextEditingController _notesCtrl = TextEditingController();

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final res = await widget.repo.getInventoryOverview();
      final items = List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      if (mounted) {
        setState(() {
          _catalog = items;
          _loadingCatalog = false;
          // إضافة صنف مبدئي
          if (items.isNotEmpty) {
            _addRow();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  void _addRow() {
    if (_catalog.isEmpty) return;
    final item = _catalog.first;
    setState(() {
      _lines.add(_AuditEntryRow(
        itemId: item['id']?.toString() ?? '',
        sku: item['sku'] ?? '',
        name: item['name'] ?? '',
        unit: item['unit_code'] ?? '',
        systemQty: (item['current_stock'] as num?)?.toDouble() ?? 0.0,
        unitCost: (item['cost'] as num?)?.toDouble() ?? 0.0,
        countedCtrl: TextEditingController(text: ((item['current_stock'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)),
        damagedCtrl: TextEditingController(text: '0'),
      ));
    });
  }

  void _removeRow(int idx) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[idx].dispose();
      _lines.removeAt(idx);
    });
  }

  double get _totalAdjustQty => _lines.fold(0.0, (sum, l) => sum + l.adjustQty);
  double get _totalDamagedQty => _lines.fold(0.0, (sum, l) => sum + l.damagedQty);
  double get _totalShortageVal => _lines.fold(0.0, (sum, l) => sum + l.shortageValue);

  Future<void> _submit() async {
    if (_lines.isEmpty) return;

    setState(() => _submitting = true);

    final payload = _lines.map((l) {
      return {
        'item_id': l.itemId,
        'system_qty': l.systemQty,
        'counted_qty': l.countedQty,
        'damaged_qty': l.damagedQty,
        'unit_cost': l.unitCost,
        'note': l.note,
      };
    }).toList();

    final res = await widget.repo.createStocktakeAudit(
      lines: payload,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل عملية الجرد برقم ${res['number']} بنجاح - الحالة: قيد المراجعة والتدقيق'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${res['error'] ?? 'تعذر حفظ الجرد'}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131924),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_task, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'تسجيل عملية جرد جديدة لمستودع المخزون',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF1E293B)),
            const SizedBox(height: 12),

            // شريط إحصائي لايف
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('الأصناف المجرودة: ${_lines.length}', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12)),
                  Text(
                    'صافي الفرق: ${_totalAdjustQty > 0 ? '+' : ''}${_totalAdjustQty.toStringAsFixed(1)}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: _totalAdjustQty >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text('إجمالي التالف: ${_totalDamagedQty.toStringAsFixed(1)}',
                      style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFEF4444), fontSize: 12)),
                  Text(
                    'قيمة العجز المالي: ${_money.format(_totalShortageVal)}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: _totalShortageVal > 0 ? const Color(0xFFEF4444) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // جدول إدخال السطور
            Expanded(
              child: _loadingCatalog
                  ? const Center(child: CircularProgressIndicator())
                  : _catalog.isEmpty
                      ? const Center(child: Text('لا توجد أصناف في الكتالوج', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: _lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final row = _lines[idx];
                            return _buildEntryRowCard(row, idx);
                          },
                        ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة صنف آخر'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _notesCtrl,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات عملية الجرد (اختياري)...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('حفظ وتسجيل الجرد'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRowCard(_AuditEntryRow row, int idx) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // اختيار الصنف
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: row.itemId,
              dropdownColor: const Color(0xFF1E293B),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الصنف',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: _catalog.map((c) {
                return DropdownMenuItem(
                  value: c['id'].toString(),
                  child: Text('${c['name']} (${c['sku']})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _catalog.firstWhere((c) => c['id'].toString() == val);
                  setState(() {
                    row.itemId = val;
                    row.sku = found['sku'] ?? '';
                    row.name = found['name'] ?? '';
                    row.unit = found['unit_code'] ?? '';
                    row.systemQty = (found['current_stock'] as num?)?.toDouble() ?? 0.0;
                    row.unitCost = (found['cost'] as num?)?.toDouble() ?? 0.0;
                    row.countedCtrl.text = row.systemQty.toStringAsFixed(1);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 10),

          // الرصيد النظامي
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النظامي', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: AppColors.onSurfaceVariant)),
                Text('${row.systemQty.toStringAsFixed(1)} ${row.unit}', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // الرصيد الفعلي
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.countedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'المجرود (${row.unit})',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // التالف
          Expanded(
            flex: 1,
            child: TextField(
              controller: row.damagedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'التالف',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // الفرق والقيمة
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الفرق: ${row.adjustQty > 0 ? '+' : ''}${row.adjustQty.toStringAsFixed(1)} ${row.unit}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: row.adjustQty < 0 ? const Color(0xFFEF4444) : (row.adjustQty > 0 ? const Color(0xFF10B981) : Colors.white),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  row.shortageValue > 0 ? 'عجز: ${_money.format(row.shortageValue)}' : 'تكلفة: ${_money.format(row.unitCost)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: row.shortageValue > 0 ? const Color(0xFFEF4444) : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // حذف الصف
          IconButton(
            onPressed: () => _removeRow(idx),
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'حذف الصنف',
          ),
        ],
      ),
    );
  }
}

class _AuditEntryRow {
  String itemId;
  String sku;
  String name;
  String unit;
  double systemQty;
  double unitCost;
  TextEditingController countedCtrl;
  TextEditingController damagedCtrl;
  String? note;

  _AuditEntryRow({
    required this.itemId,
    required this.sku,
    required this.name,
    required this.unit,
    required this.systemQty,
    required this.unitCost,
    required this.countedCtrl,
    required this.damagedCtrl,
  });

  double get countedQty => double.tryParse(countedCtrl.text.trim()) ?? systemQty;
  double get damagedQty => double.tryParse(damagedCtrl.text.trim()) ?? 0.0;
  double get adjustQty => countedQty - (systemQty - damagedQty);
  double get shortageValue => adjustQty < 0 ? (adjustQty.abs() * unitCost) : 0.0;

  void dispose() {
    countedCtrl.dispose();
    damagedCtrl.dispose();
  }
}
