import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../../core/local_db.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/catalog/catalog_cubit.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../../../../cubits/sync/sync_cubit.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../services/shift_close_pdf_builder.dart';

// ── الأقسام ───────────────────────────────────────────────────────────────────

enum _AdminTab {
  shiftClose,
  expenses,
  attendance,
  deductions,
  vacation,
  supplies,
}

const _tabLabels = {
  _AdminTab.shiftClose: 'إقفال الوردية',
  _AdminTab.expenses: 'المصروفات',
  _AdminTab.attendance: 'الحضور والغياب',
  _AdminTab.deductions: 'الخصومات والمكافآت',
  _AdminTab.vacation: 'طلب إجازة',
  _AdminTab.supplies: 'طلب مستلزمات',
};

const _tabIcons = {
  _AdminTab.shiftClose: Icons.lock_clock_outlined,
  _AdminTab.expenses: Icons.receipt_outlined,
  _AdminTab.attendance: Icons.people_outline_rounded,
  _AdminTab.deductions: Icons.tune_rounded,
  _AdminTab.vacation: Icons.beach_access_outlined,
  _AdminTab.supplies: Icons.inventory_2_outlined,
};

// ── الشاشة الرئيسية ───────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  _AdminTab _selectedTab = _AdminTab.shiftClose;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── هيدر شاشة الإدارة ─────────────────────────────────────────
            _AdminHeader(
              selectedTab: _selectedTab,
              onTabSelected: (tab) => setState(() => _selectedTab = tab),
            ),

            // ── المحتوى ─────────────────────────────────────────────────────
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case _AdminTab.shiftClose:
        return const _ShiftCloseSection();
      case _AdminTab.expenses:
        return const _ExpensesSection();
      case _AdminTab.attendance:
        return const _AttendanceSection();
      case _AdminTab.deductions:
        return const _DeductionsSection();
      case _AdminTab.vacation:
        return const _VacationSection();
      case _AdminTab.supplies:
        return const _SuppliesSection();
    }
  }
}

// ── هيدر الإدارة ──────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final _AdminTab selectedTab;
  final ValueChanged<_AdminTab> onTabSelected;

  const _AdminHeader({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      child: Column(
        children: [
          // ── شريط العنوان ────────────────────────────────────────────────
          Container(
            height: 48,
            color: AppColors.surfaceContainerLow,
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Row(
              children: [
                const Icon(Icons.assessment_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'لوحة الإدارة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontLg,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                // ── مؤشر المزامنة ───────────────────────────────────────
                BlocBuilder<SyncCubit, SyncState>(
                  builder: (context, syncState) {
                    return _SyncIndicator(syncState: syncState);
                  },
                ),
                const SizedBox(width: AppDimens.spaceMd),
                // ── معلومات الجلسة ───────────────────────────────────────
                BlocBuilder<SessionCubit, SessionState>(
                  builder: (context, session) {
                    return Text(
                      '${session.cashierName} | ${session.branchName} | ${session.shift}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── تبويبات التنقل ──────────────────────────────────────────────
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceXs,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _AdminTab.values.map((tab) {
                  final isSelected = tab == selectedTab;
                  return Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTabSelected(tab),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceXs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tabIcons[tab]!,
                                size: AppDimens.iconSm,
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _tabLabels[tab]!,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontSm,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.onPrimary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── مؤشر المزامنة ──────────────────────────────────────────────────────────────

class _SyncIndicator extends StatelessWidget {
  final SyncState syncState;

  const _SyncIndicator({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final hasFailed = syncState.failedCount > 0;
    final hasPending = syncState.pendingCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFailed)
          Container(
            margin: const EdgeInsets.only(left: AppDimens.spaceSm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 12, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  'فشل: ${syncState.failedCount}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (hasPending)
          Container(
            margin: const EdgeInsets.only(left: AppDimens.spaceSm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5)),
            ),
            child: Text(
              'فواتير معلقة: ${syncState.pendingCount}',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(width: AppDimens.spaceXs),
        SizedBox(
          height: 28,
          child: ElevatedButton.icon(
            onPressed: syncState.isSyncing
                ? null
                : () => context.read<SyncCubit>().triggerSync(),
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.onPrimary),
                  )
                : const Icon(Icons.sync_rounded, size: 14),
            label: Text(
              'إرسال الآن',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 6: إقفال الوردية
// ═══════════════════════════════════════════════════════════════════════════════

class _ShiftCloseSection extends StatefulWidget {
  const _ShiftCloseSection();

  @override
  State<_ShiftCloseSection> createState() => _ShiftCloseSectionState();
}

class _ShiftCloseSectionState extends State<_ShiftCloseSection> {
  final _countedCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isClosing = false;
  String? _errorMsg;
  double _countedCash = 0.0;

  // بيانات مجمَّعة من local_records
  List<LocalRecord> _sessionInvoices = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _countedCashController.addListener(() {
      final v = double.tryParse(
              _countedCashController.text.replaceAll(',', '.')) ??
          0.0;
      setState(() => _countedCash = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvoices());
  }

  @override
  void dispose() {
    _countedCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final session = context.read<SessionCubit>().state;
    final repo = LocalRecordsRepository();
    final invoices = await repo.getBySession(session.sessionId, 'sale');
    if (mounted) {
      setState(() {
        _sessionInvoices = invoices;
        _loaded = true;
      });
    }
  }

  // ── حساب الملخص ─────────────────────────────────────────────────────────────

  double get _totalSales =>
      _sessionInvoices.fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalCash => _sessionInvoices
      .where((r) => r.paymentMethod == 'كاش')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalVisa => _sessionInvoices
      .where((r) => r.paymentMethod == 'فيزا')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalOther => _sessionInvoices
      .where((r) => r.paymentMethod != 'كاش' && r.paymentMethod != 'فيزا')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalDiscount => _sessionInvoices.fold(0.0, (s, r) {
        final d = (r.payload['discount_amount'] as num?)?.toDouble() ?? 0.0;
        return s + d;
      });

  double get _totalVat => _sessionInvoices.fold(0.0, (s, r) {
        final v = (r.payload['vat_amount'] as num?)?.toDouble() ?? 0.0;
        return s + v;
      });

  double get _expectedCash => _totalCash;
  double get _difference => _countedCash - _expectedCash;

  // ── تنفيذ الإقفال ────────────────────────────────────────────────────────────

  Future<void> _handleClose() async {
    if (_isClosing) return;

    if (_countedCashController.text.trim().isEmpty) {
      setState(() => _errorMsg = 'يرجى إدخال المبلغ الموجود في الكاش');
      return;
    }
    if (_countedCash < 0) {
      setState(() => _errorMsg = 'المبلغ لا يمكن أن يكون أقل من صفر');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          title: Text(
            'تأكيد إقفال الوردية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'بعد الإقفال ستُطبع الفواتير ويتم تسجيل الخروج.\nهل أنت متأكد؟',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء',
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
              ),
              child: Text('إقفال',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isClosing = true;
      _errorMsg = null;
    });

    try {
      final session = context.read<SessionCubit>().state;
      final repo = LocalRecordsRepository();
      final now = DateTime.now();

      // أ) كتابة سجل shift_close
      final clientId = generateUuidV4();
      await repo.insert(LocalRecord(
        kind: 'shift_close',
        clientId: clientId,
        userId: session.userId,
        branchId: session.branchId,
        sessionId: session.sessionId,
        payload: {
          'client_id': clientId,
          'session_id': session.sessionId,
          'branch_id': session.branchId,
          'shift': session.shift,
          'opened_at': session.startedAt?.toUtc().toIso8601String(),
          'closed_at': now.toUtc().toIso8601String(),
          'counted_cash':
              double.parse(_countedCash.toStringAsFixed(2)),
          'client_invoices_count': _sessionInvoices.length,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        },
        status: 'pending',
        createdAt: now,
      ));

      // ب) محاولة مزامنة بحد أقصى 15 ثانية بدون حجب
      if (mounted) {
        context.read<SyncCubit>().triggerSync();
        await Future.delayed(const Duration(seconds: 15));
      }

      // ج) طباعة التقرير
      if (mounted) {
        // أعِد تحميل الفواتير لأخذ server_number المحدث بعد المزامنة
        final updatedInvoices =
            await repo.getBySession(session.sessionId, 'sale');

        final reportData = ShiftCloseReportData(
          branchName: session.branchName,
          branchCode: session.branchCode,
          cashierName: session.cashierName,
          shift: session.shift,
          openedAt: session.startedAt ?? now,
          closedAt: now,
          invoices: updatedInvoices,
          totalSales: _totalSales,
          totalCash: _totalCash,
          totalVisa: _totalVisa,
          totalDiscount: _totalDiscount,
          totalVat: _totalVat,
          expectedCash: _expectedCash,
          countedCash: _countedCash,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        try {
          final pdfBytes = await buildShiftClosePdf(reportData);
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name:
                'DietKing_ShiftClose_${session.sessionId.substring(0, 8)}',
          );
        } catch (printErr) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشلت الطباعة: $printErr',
                    textAlign: TextAlign.right),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // د) إنهاء الجلسة والانتقال لشاشة الدخول
        if (mounted) {
          context.read<SessionCubit>().end();
          context.read<CatalogCubit>().reset();
          // SyncCubit يواصل المزامنة في الخلفية — لا نعمل signOut الآن
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClosing = false;
          _errorMsg = 'حدث خطأ: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── كارت معلومات الوردية ─────────────────────────────────────────
          BlocBuilder<SessionCubit, SessionState>(
            builder: (context, session) {
              return _AdminCard(
                title: 'معلومات الوردية الحالية',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    _InfoRow(
                        label: 'الفرع',
                        value:
                            '${session.branchName} (${session.branchCode})'),
                    _InfoRow(
                        label: 'الكاشير', value: session.cashierName),
                    _InfoRow(label: 'الوردية', value: session.shift),
                    if (session.startedAt != null)
                      _InfoRow(
                        label: 'بداية الوردية',
                        value: _fmtDateTime(session.startedAt!),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── ملخص المبيعات ────────────────────────────────────────────────
          if (_loaded)
            _AdminCard(
              title: 'ملخص مبيعات الوردية',
              icon: Icons.bar_chart_rounded,
              child: Column(
                children: [
                  _InfoRow(
                      label: 'عدد الفواتير',
                      value: '${_sessionInvoices.length}'),
                  _InfoRow(
                      label: 'إجمالي المبيعات',
                      value:
                          '${_totalSales.toStringAsFixed(2)} ر.س'),
                  _InfoRow(
                      label: 'إجمالي النقدي',
                      value:
                          '${_totalCash.toStringAsFixed(2)} ر.س'),
                  _InfoRow(
                      label: 'إجمالي الفيزا',
                      value:
                          '${_totalVisa.toStringAsFixed(2)} ر.س'),
                  if (_totalOther > 0)
                    _InfoRow(
                        label: 'طرق أخرى',
                        value:
                            '${_totalOther.toStringAsFixed(2)} ر.س'),
                  _InfoRow(
                      label: 'إجمالي الخصومات',
                      value:
                          '${_totalDiscount.toStringAsFixed(2)} ر.س'),
                  _InfoRow(
                      label: 'إجمالي ض.ق.م',
                      value:
                          '${_totalVat.toStringAsFixed(2)} ر.س'),
                ],
              ),
            ),
          if (!_loaded)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
          const SizedBox(height: AppDimens.spaceMd),

          // ── مقارنة الكاش ─────────────────────────────────────────────────
          _AdminCard(
            title: 'مقارنة الكاش',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'المبلغ المتوقع في الدرج',
                  value: '${_expectedCash.toStringAsFixed(2)} ر.س',
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'المبلغ الموجود بالكاش',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _countedCashController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                      fontSize: AppDimens.fontMd,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixText: 'ر.س',
                      suffixStyle: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                // الفرق
                _DifferenceIndicator(difference: _difference),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── ملاحظات ──────────────────────────────────────────────────────
          _AdminCard(
            title: 'ملاحظات (اختياري)',
            icon: Icons.notes_rounded,
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: AppDimens.fontMd,
              ),
              decoration: InputDecoration(
                hintText: 'أي ملاحظات خاصة بالوردية...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color:
                        AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── رسالة خطأ ────────────────────────────────────────────────────
          if (_errorMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.redAccent,
                          fontSize: AppDimens.fontSm),
                    ),
                  ),
                ],
              ),
            ),

          // ── زر الإقفال ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isClosing ? null : _handleClose,
              icon: _isClosing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_clock_outlined, size: 22),
              label: Text(
                'إقفال الوردية وطباعة التقرير',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── مؤشر الفرق ──────────────────────────────────────────────────────────────

class _DifferenceIndicator extends StatelessWidget {
  final double difference;

  const _DifferenceIndicator({required this.difference});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (difference == 0) {
      label = 'مطابق';
      color = AppColors.tertiary;
      icon = Icons.check_circle_outline_rounded;
    } else if (difference > 0) {
      label = 'زيادة ${difference.toStringAsFixed(2)} ر.س';
      color = AppColors.tertiaryContainer;
      icon = Icons.trending_up_rounded;
    } else {
      label = 'عجز ${difference.abs().toStringAsFixed(2)} ر.س';
      color = Colors.redAccent;
      icon = Icons.trending_down_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 7: المصروفات
// ═══════════════════════════════════════════════════════════════════════════════

const _expenseCategories = [
  'مستلزمات تشغيل',
  'صيانة',
  'نظافة',
  'كهرباء ومياه',
  'مواصلات',
  'نثريات',
  'أخرى',
];

class _ExpensesSection extends StatefulWidget {
  const _ExpensesSection();

  @override
  State<_ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<_ExpensesSection> {
  String _category = _expenseCategories.first;
  final _payeeController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _vatController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  String _paymentMethod = 'نقدي';
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMsg;

  List<LocalRecord> _sessionExpenses = [];

  double get _vatAmount =>
      double.tryParse(_vatController.text) ?? 0.0;
  double get _amount =>
      double.tryParse(_amountController.text) ?? 0.0;
  double get _total => _amount + _vatAmount;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _vatController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExpenses());
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _vatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final session = context.read<SessionCubit>().state;
    final repo = LocalRecordsRepository();
    final expenses = await repo.getBySession(session.sessionId, 'expense');
    if (mounted) setState(() => _sessionExpenses = expenses);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_amount <= 0) {
      setState(() => _errorMsg = 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final session = context.read<SessionCubit>().state;
      final repo = LocalRecordsRepository();
      final clientId = generateUuidV4();
      final localNumber = await repo.nextLocalNumber(
          session.branchCode.isNotEmpty ? session.branchCode : 'DK');
      final now = DateTime.now();

      final payload = {
        'client_id': clientId,
        'branch_id': session.branchId,
        'session_id': session.sessionId,
        'category': _category,
        'payee': _payeeController.text.trim().isEmpty
            ? null
            : _payeeController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'amount': double.parse(_amount.toStringAsFixed(2)),
        'vat_amount': double.parse(_vatAmount.toStringAsFixed(2)),
        'payment_method': _paymentMethod == 'نقدي' ? 'cash' : 'other',
        'expense_date':
            '${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      await repo.insert(LocalRecord(
        kind: 'expense',
        clientId: clientId,
        userId: session.userId,
        branchId: session.branchId,
        sessionId: session.sessionId,
        localNumber: localNumber,
        paymentMethod: _paymentMethod,
        total: _total,
        payload: payload,
        status: 'pending',
        createdAt: now,
      ));

      if (mounted) {
        context.read<SyncCubit>().triggerSync();
        await _loadExpenses();
        // إعادة التعيين
        _amountController.clear();
        _vatController.text = '0';
        _payeeController.clear();
        _descController.clear();
        _notesController.clear();
        setState(() {
          _isSaving = false;
          _category = _expenseCategories.first;
          _paymentMethod = 'نقدي';
          _expenseDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ المصروف بنجاح', textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMsg = 'خطأ: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── نموذج المصروف ────────────────────────────────────────────────
          _AdminCard(
            title: 'إضافة مصروف جديد',
            icon: Icons.add_circle_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نوع المصروف
                _FormLabel('نوع المصروف'),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                      fontSize: AppDimens.fontMd),
                  decoration: _inputDecoration(),
                  items: _expenseCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // المستفيد والوصف
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('المستفيد / المورد (اختياري)'),
                          _TextInput(controller: _payeeController,
                              hint: 'اسم المستفيد'),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('الوصف (اختياري)'),
                          _TextInput(controller: _descController,
                              hint: 'وصف المصروف'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // المبلغ والقيمة المضافة
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('المبلغ (ر.س) *'),
                          _TextInput(
                            controller: _amountController,
                            hint: '0.00',
                            isNumber: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('ض.ق.م (ر.س) — افتراضي 0'),
                          _TextInput(
                            controller: _vatController,
                            hint: '0',
                            isNumber: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('الإجمالي'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Text(
                            '${_total.toStringAsFixed(2)} ر.س',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: AppDimens.fontMd,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // طريقة الدفع والتاريخ
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('طريقة الدفع'),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'نقدي', label: Text('نقدي')),
                            ButtonSegment(value: 'آخر', label: Text('آخر')),
                          ],
                          selected: {_paymentMethod},
                          onSelectionChanged: (s) =>
                              setState(() => _paymentMethod = s.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primaryContainer,
                            selectedForegroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppDimens.spaceLg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('التاريخ'),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expenseDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppColors.primary,
                                    surface: AppColors.surfaceContainerLow,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() => _expenseDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.onSurface,
                                    fontSize: AppDimens.fontMd,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // ملاحظات
                _FormLabel('ملاحظات (اختياري)'),
                _TextInput(controller: _notesController, hint: 'ملاحظات'),
                const SizedBox(height: AppDimens.spaceMd),

                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Text(_errorMsg!,
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.redAccent)),
                  ),

                SizedBox(
                  width: 200,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text('حفظ الفاتورة',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // ── جدول مصروفات الوردية ────────────────────────────────────────
          _AdminCard(
            title: 'مصروفات الوردية الحالية',
            icon: Icons.list_alt_rounded,
            child: _sessionExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      child: Text(
                        'لا توجد مصروفات مسجلة في هذه الوردية',
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          AppColors.surfaceContainerHigh),
                      dataRowColor: WidgetStateProperty.resolveWith((states) =>
                          AppColors.surfaceContainerLow),
                      border: TableBorder.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      columns: [
                        _col('الرقم'),
                        _col('النوع'),
                        _col('المبلغ'),
                        _col('الإجمالي'),
                        _col('الحالة'),
                      ],
                      rows: _sessionExpenses.map((r) {
                        final number = r.serverNumber ??
                            r.localNumber ??
                            '-';
                        final category =
                            (r.payload['category'] as String?) ?? '-';
                        final amount =
                            (r.payload['amount'] as num?)?.toDouble() ?? 0.0;
                        final total = r.total ?? 0.0;
                        return DataRow(cells: [
                          DataCell(Text(number,
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface))),
                          DataCell(Text(category,
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface))),
                          DataCell(Text(
                              '${amount.toStringAsFixed(2)} ر.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface))),
                          DataCell(Text(
                              '${total.toStringAsFixed(2)} ر.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface))),
                          DataCell(_StatusBadge(status: r.status)),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      );
}

// ── Badge حالة السجل ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'synced' => ('تم الإرسال', AppColors.tertiary),
      'failed' => ('فشل الإرسال', Colors.redAccent),
      _ => ('بانتظار الإرسال', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 8: الأقسام التجريبية
// ═══════════════════════════════════════════════════════════════════════════════

// ── الحضور والغياب ─────────────────────────────────────────────────────────────

class _AttendanceSection extends StatefulWidget {
  const _AttendanceSection();

  @override
  State<_AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends State<_AttendanceSection> {
  final List<Map<String, dynamic>> _employees = [
    {'name': 'أحمد محمد', 'status': 'حاضر', 'note': ''},
    {'name': 'فاطمة علي', 'status': 'حاضر', 'note': ''},
    {'name': 'خالد سعيد', 'status': 'حاضر', 'note': ''},
    {'name': 'نورة عبدالله', 'status': 'حاضر', 'note': ''},
    {'name': 'عمر إبراهيم', 'status': 'حاضر', 'note': ''},
    {'name': 'سارة يوسف', 'status': 'حاضر', 'note': ''},
  ];
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title:
                'الحضور والغياب — ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
            icon: Icons.people_outline_rounded,
            child: Column(
              children: [
                ...List.generate(_employees.length, (i) {
                  final emp = _employees[i];
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            emp['name'],
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        DropdownButton<String>(
                          value: emp['status'],
                          dropdownColor: AppColors.surfaceContainerLow,
                          style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface),
                          underline: const SizedBox(),
                          items: ['حاضر', 'غائب', 'متأخر']
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _employees[i]['status'] = v!),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontSize: AppDimens.fontSm),
                            decoration: InputDecoration(
                              hintText: 'ملاحظة',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fontSize: AppDimens.fontSm),
                              filled: true,
                              fillColor: AppColors.surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSm),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (v) => _employees[i]['note'] = v,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppDimens.spaceMd),
                if (_saved)
                  Container(
                    padding: const EdgeInsets.all(AppDimens.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                          color: AppColors.tertiary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.tertiary, size: 16),
                        const SizedBox(width: 6),
                        Text('تم الحفظ (تجريبي)',
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.tertiary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppDimens.spaceSm),
                SizedBox(
                  width: 160,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _saved = true),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text('حفظ',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── الخصومات والمكافآت ─────────────────────────────────────────────────────────

class _DeductionsSection extends StatefulWidget {
  const _DeductionsSection();

  @override
  State<_DeductionsSection> createState() => _DeductionsSectionState();
}

class _DeductionsSectionState extends State<_DeductionsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _deductionNameCtrl = TextEditingController();
  final _deductionAmountCtrl = TextEditingController();
  final _deductionReasonCtrl = TextEditingController();
  final _deductionNoteCtrl = TextEditingController();
  String _deductionType = 'خصم';
  DateTime _deductionDate = DateTime.now();
  final List<Map<String, dynamic>> _deductions = [];

  final _bonusNameCtrl = TextEditingController();
  final _bonusAmountCtrl = TextEditingController();
  final _bonusReasonCtrl = TextEditingController();
  final _bonusNoteCtrl = TextEditingController();
  DateTime _bonusDate = DateTime.now();
  final List<Map<String, dynamic>> _bonuses = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _deductionNameCtrl.dispose();
    _deductionAmountCtrl.dispose();
    _deductionReasonCtrl.dispose();
    _deductionNoteCtrl.dispose();
    _bonusNameCtrl.dispose();
    _bonusAmountCtrl.dispose();
    _bonusReasonCtrl.dispose();
    _bonusNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'الخصومات والمكافآت',
            icon: Icons.tune_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabCtrl,
                  labelStyle: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w700),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'خصومات وعجز'),
                    Tab(text: 'مكافآت'),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceMd),
                SizedBox(
                  height: 520,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── تبويب الخصومات ─────────────────────────────────
                      _DeductionForm(
                        nameCtrl: _deductionNameCtrl,
                        amountCtrl: _deductionAmountCtrl,
                        reasonCtrl: _deductionReasonCtrl,
                        noteCtrl: _deductionNoteCtrl,
                        selectedType: _deductionType,
                        selectedDate: _deductionDate,
                        onTypeChanged: (v) =>
                            setState(() => _deductionType = v),
                        onDateChanged: (d) =>
                            setState(() => _deductionDate = d),
                        onAdd: () => setState(() {
                          _deductions.add({
                            'name': _deductionNameCtrl.text,
                            'type': _deductionType,
                            'amount': _deductionAmountCtrl.text,
                            'reason': _deductionReasonCtrl.text,
                            'date': _deductionDate,
                          });
                          _deductionNameCtrl.clear();
                          _deductionAmountCtrl.clear();
                          _deductionReasonCtrl.clear();
                          _deductionNoteCtrl.clear();
                        }),
                        items: _deductions,
                        columns: ['الموظف', 'النوع', 'القيمة', 'السبب', 'التاريخ'],
                        rowBuilder: (d) => [
                          d['name'],
                          d['type'],
                          d['amount'],
                          d['reason'],
                          '${(d['date'] as DateTime).year}-${(d['date'] as DateTime).month.toString().padLeft(2, '0')}-${(d['date'] as DateTime).day.toString().padLeft(2, '0')}',
                        ],
                      ),

                      // ── تبويب المكافآت ─────────────────────────────────
                      _BonusForm(
                        nameCtrl: _bonusNameCtrl,
                        amountCtrl: _bonusAmountCtrl,
                        reasonCtrl: _bonusReasonCtrl,
                        noteCtrl: _bonusNoteCtrl,
                        selectedDate: _bonusDate,
                        onDateChanged: (d) => setState(() => _bonusDate = d),
                        onAdd: () => setState(() {
                          _bonuses.add({
                            'name': _bonusNameCtrl.text,
                            'amount': _bonusAmountCtrl.text,
                            'reason': _bonusReasonCtrl.text,
                            'date': _bonusDate,
                          });
                          _bonusNameCtrl.clear();
                          _bonusAmountCtrl.clear();
                          _bonusReasonCtrl.clear();
                          _bonusNoteCtrl.clear();
                        }),
                        items: _bonuses,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeductionForm extends StatelessWidget {
  final TextEditingController nameCtrl, amountCtrl, reasonCtrl, noteCtrl;
  final String selectedType;
  final DateTime selectedDate;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onAdd;
  final List<Map<String, dynamic>> items;
  final List<String> columns;
  final List<String> Function(Map<String, dynamic>) rowBuilder;

  const _DeductionForm({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.reasonCtrl,
    required this.noteCtrl,
    required this.selectedType,
    required this.selectedDate,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onAdd,
    required this.items,
    required this.columns,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormLabel('الموظف'),
              _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
            ],
          )),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FormLabel('النوع'),
            DropdownButton<String>(
              value: selectedType,
              dropdownColor: AppColors.surfaceContainerLow,
              style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface),
              items: ['خصم', 'عجز']
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => onTypeChanged(v!),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormLabel('القيمة'),
              _TextInput(
                  controller: amountCtrl,
                  hint: '0.00',
                  isNumber: true),
            ],
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormLabel('السبب'),
              _TextInput(controller: reasonCtrl, hint: 'سبب الخصم'),
            ],
          )),
        ]),
        const SizedBox(height: 8),
        _FormLabel('ملاحظات'),
        _TextInput(controller: noteCtrl, hint: 'ملاحظات'),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text('إضافة',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusMd)),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MiniTable(columns: columns, rows: items.map(rowBuilder).toList()),
        ],
      ],
    );
  }
}

class _BonusForm extends StatelessWidget {
  final TextEditingController nameCtrl, amountCtrl, reasonCtrl, noteCtrl;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onAdd;
  final List<Map<String, dynamic>> items;

  const _BonusForm({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.reasonCtrl,
    required this.noteCtrl,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onAdd,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormLabel('الموظف'),
              _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
            ],
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormLabel('القيمة (ر.س)'),
              _TextInput(
                  controller: amountCtrl,
                  hint: '0.00',
                  isNumber: true),
            ],
          )),
        ]),
        const SizedBox(height: 8),
        _FormLabel('السبب'),
        _TextInput(controller: reasonCtrl, hint: 'سبب المكافأة'),
        const SizedBox(height: 8),
        _FormLabel('ملاحظات'),
        _TextInput(controller: noteCtrl, hint: 'ملاحظات'),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text('إضافة',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiaryContainer,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusMd)),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MiniTable(
            columns: ['الموظف', 'القيمة', 'السبب', 'التاريخ'],
            rows: items
                .map((d) => [
                      d['name'] as String,
                      d['amount'] as String,
                      d['reason'] as String,
                      '${(d['date'] as DateTime).year}-${(d['date'] as DateTime).month.toString().padLeft(2, '0')}-${(d['date'] as DateTime).day.toString().padLeft(2, '0')}',
                    ])
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ── طلب إجازة ─────────────────────────────────────────────────────────────────

class _VacationSection extends StatefulWidget {
  const _VacationSection();

  @override
  State<_VacationSection> createState() => _VacationSectionState();
}

class _VacationSectionState extends State<_VacationSection> {
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _vacationType = 'اعتيادية';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _error;
  final List<Map<String, dynamic>> _requests = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'طلب إجازة',
            icon: Icons.beach_access_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormLabel('الموظف'),
                      _TextInput(
                          controller: _nameCtrl, hint: 'اسم الموظف'),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('نوع الإجازة'),
                        DropdownButton<String>(
                          value: _vacationType,
                          dropdownColor: AppColors.surfaceContainerLow,
                          style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface),
                          items: ['اعتيادية', 'مرضية', 'عارضة', 'بدون مرتب']
                              .map((t) => DropdownMenuItem(
                                  value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _vacationType = v!),
                        ),
                      ]),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _DatePickerButton(
                    label: 'تاريخ البداية',
                    date: _startDate,
                    onPicked: (d) => setState(() => _startDate = d),
                  ),
                  const SizedBox(width: 12),
                  _DatePickerButton(
                    label: 'تاريخ النهاية',
                    date: _endDate,
                    onPicked: (d) => setState(() => _endDate = d),
                    minDate: _startDate,
                  ),
                ]),
                const SizedBox(height: 8),
                _FormLabel('السبب'),
                _TextInput(controller: _reasonCtrl, hint: 'سبب الإجازة'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.redAccent)),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_nameCtrl.text.isEmpty) {
                        setState(() =>
                            _error = 'يرجى إدخال اسم الموظف');
                        return;
                      }
                      if (_startDate == null || _endDate == null) {
                        setState(() =>
                            _error = 'يرجى تحديد تاريخ البداية والنهاية');
                        return;
                      }
                      if (_endDate!.isBefore(_startDate!)) {
                        setState(() =>
                            _error = 'تاريخ النهاية يجب أن يكون بعد البداية');
                        return;
                      }
                      setState(() {
                        _error = null;
                        _requests.add({
                          'name': _nameCtrl.text,
                          'type': _vacationType,
                          'start': _startDate,
                          'end': _endDate,
                          'reason': _reasonCtrl.text,
                          'status': 'قيد المراجعة',
                        });
                        _nameCtrl.clear();
                        _reasonCtrl.clear();
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('إرسال الطلب',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd)),
                    ),
                  ),
                ),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MiniTable(
                    columns: ['الموظف', 'النوع', 'البداية', 'النهاية', 'السبب', 'الحالة'],
                    rows: _requests.map((r) {
                      String d(DateTime dt) =>
                          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      return [
                        r['name'] as String,
                        r['type'] as String,
                        d(r['start'] as DateTime),
                        d(r['end'] as DateTime),
                        r['reason'] as String,
                        r['status'] as String,
                      ];
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── طلب مستلزمات ──────────────────────────────────────────────────────────────

class _SuppliesSection extends StatefulWidget {
  const _SuppliesSection();

  @override
  State<_SuppliesSection> createState() => _SuppliesSectionState();
}

class _SuppliesSectionState extends State<_SuppliesSection> {
  final _items = [
    {'name': 'أكياس', 'qty': TextEditingController()},
    {'name': 'علب تغليف', 'qty': TextEditingController()},
    {'name': 'مناديل', 'qty': TextEditingController()},
    {'name': 'أدوات مائدة', 'qty': TextEditingController()},
    {'name': 'منظفات', 'qty': TextEditingController()},
  ];
  final _notesCtrl = TextEditingController();
  final List<Map<String, dynamic>> _orders = [];

  @override
  void dispose() {
    for (final item in _items) {
      (item['qty'] as TextEditingController).dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'طلب مستلزمات من المخزن الرئيسي',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(_items.length, (i) {
                  final item = _items[i];
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            item['name'] as String,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller:
                                item['qty'] as TextEditingController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontSize: AppDimens.fontMd),
                            decoration: InputDecoration(
                              hintText: 'الكمية',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fontSize: AppDimens.fontSm),
                              filled: true,
                              fillColor: AppColors.surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSm),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppDimens.spaceSm),
                _FormLabel('ملاحظات'),
                _TextInput(controller: _notesCtrl, hint: 'أي ملاحظات...'),
                const SizedBox(height: AppDimens.spaceMd),
                SizedBox(
                  width: 180,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final ordered = _items
                          .where((it) =>
                              (it['qty'] as TextEditingController)
                                  .text
                                  .isNotEmpty)
                          .map((it) => {
                                'name': it['name'] as String,
                                'qty': (it['qty']
                                        as TextEditingController)
                                    .text,
                              })
                          .toList();
                      if (ordered.isEmpty) return;
                      setState(() {
                        _orders.add({
                          'items': ordered,
                          'notes': _notesCtrl.text,
                          'status': 'قيد الانتظار',
                          'date': DateTime.now(),
                        });
                        for (final item in _items) {
                          (item['qty'] as TextEditingController).clear();
                        }
                        _notesCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('إرسال الطلب',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd)),
                    ),
                  ),
                ),
                if (_orders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'الطلبات المرسلة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._orders.map((order) {
                    final date = order['date'] as DateTime;
                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: AppDimens.spaceSm),
                      padding: const EdgeInsets.all(AppDimens.spaceSm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (order['items'] as List)
                                  .map((i) =>
                                      '${i['name']} (${i['qty']})')
                                  .join('، '),
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontSm,
                                  color: AppColors.onSurface),
                            ),
                          ),
                          _StatusBadge(status: 'pending'),
                          const SizedBox(width: 8),
                          Text(
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontXs,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الكارت
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimens.radiusMd),
                topRight: Radius.circular(AppDimens.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontXs,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isNumber;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurface,
        fontSize: AppDimens.fontMd,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: AppDimens.fontMd),
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

InputDecoration _inputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceContainerHigh,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      borderSide: BorderSide.none,
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd, vertical: AppDimens.spaceXs),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
            color: AppColors.primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'وضع تجريبي — البيانات في الذاكرة فقط',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const _MiniTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(AppColors.surfaceContainerHigh),
        dataRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
        border: TableBorder.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        columns: columns
            .map((c) => DataColumn(
                  label: Text(
                    c,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                  cells: row
                      .map((cell) => DataCell(Text(
                            cell,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: AppColors.onSurface,
                            ),
                          )))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final DateTime? minDate;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onPicked,
    this.minDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: minDate ?? DateTime(2024),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surfaceContainerLow,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
                      : 'اختر التاريخ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: date != null
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: AppDimens.fontSm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
