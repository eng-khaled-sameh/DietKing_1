import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/models/leave_request_model.dart';
import '../cubit/hr_leave_requests_cubit.dart';

import '../services/hr_excel_export_service.dart';

class LeaveRequestsSection extends StatelessWidget {
  const LeaveRequestsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // الـ HrLeaveRequestsCubit مُوفَّر من HrShell — لا نُنشئه هنا
    return const _LeaveRequestsView();
  }
}

class _LeaveRequestsView extends StatefulWidget {
  const _LeaveRequestsView();

  @override
  State<_LeaveRequestsView> createState() => _LeaveRequestsViewState();
}

class _LeaveRequestsViewState extends State<_LeaveRequestsView> {
  bool _isExporting = false;
  String _selectedBranch = 'all';
  String _selectedStatus = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _selectedDecision = 'all'; // 'all', 'paid', 'unpaid'

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HrLeaveRequestsCubit, HrLeaveRequestsState>(
      builder: (context, state) {
        final allRequests = state.requests;

        // استخراج قائمة الفروع المتاحة
        final branches = <String>{'all'};
        for (final r in allRequests) {
          if (r.branchName != null && r.branchName!.trim().isNotEmpty) {
            branches.add(r.branchName!.trim());
          }
        }

        // تصفية الطلبات للعرض في الشاشة
        final filteredRequests = allRequests.where((r) {
          final bName = (r.branchName != null && r.branchName!.trim().isNotEmpty)
              ? r.branchName!.trim()
              : 'المركز الرئيسي';
          if (_selectedBranch != 'all' && bName != _selectedBranch) return false;
          if (_selectedStatus != 'all' && r.status != _selectedStatus) return false;
          if (_selectedDecision == 'paid') {
            if (r.decisionType == 'with_deduction' || !r.isPaid) return false;
          } else if (_selectedDecision == 'unpaid') {
            if (r.decisionType != 'with_deduction' && r.isPaid) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            _buildHeader(context, allRequests),
            if (allRequests.isNotEmpty) _buildFilterBar(branches.toList()),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (state.isLoading && allRequests.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null) {
                    return Center(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  }
                  if (allRequests.isEmpty) {
                    return const Center(child: Text('لا توجد طلبات إجازة'));
                  }
                  if (filteredRequests.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد طلبات تطابق الفلتر المحدد',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    itemCount: filteredRequests.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.spaceMd),
                    itemBuilder: (context, index) {
                      final req = filteredRequests[index];
                      return _LeaveRequestCard(req: req);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<LeaveRequest> requests) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات الإجازات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'إدارة واعتماد إجازات الموظفين وتصديرها مرتبة بالفروع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // زر تصدير Excel لجميع الفروع
          ElevatedButton.icon(
            onPressed: (_isExporting || requests.isEmpty)
                ? null
                : () => _exportExcel(requests),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined, size: 18),
            label: Text(
              _isExporting ? 'جاري التصدير...' : 'تصدير Excel لجميع الفروع',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C41),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
          const SizedBox(width: 10),

          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<HrLeaveRequestsCubit>().fetchRequests(force: true),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<String> branches) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      color: AppColors.surfaceContainerLow,
      child: Row(
        children: [
          // فلتر الفرع
          Text(
            'الفرع:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBranch,
                isDense: true,
                dropdownColor: AppColors.surfaceContainerHigh,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white),
                items: branches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text(b == 'all' ? 'كافة الفروع' : b),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBranch = v);
                },
              ),
            ),
          ),

          const SizedBox(width: 16),

          // فلتر الحالة
          Text(
            'الحالة:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _buildChip('الكل', 'all', _selectedStatus, (v) => setState(() => _selectedStatus = v)),
          const SizedBox(width: 4),
          _buildChip('قيد المراجعة', 'pending', _selectedStatus, (v) => setState(() => _selectedStatus = v)),
          const SizedBox(width: 4),
          _buildChip('معتمدة', 'approved', _selectedStatus, (v) => setState(() => _selectedStatus = v)),
          const SizedBox(width: 4),
          _buildChip('مرفوضة', 'rejected', _selectedStatus, (v) => setState(() => _selectedStatus = v)),

          const SizedBox(width: 16),

          // فلتر نوع الإجازة
          Text(
            'النوع:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _buildChip('الكل', 'all', _selectedDecision, (v) => setState(() => _selectedDecision = v)),
          const SizedBox(width: 4),
          _buildChip('مدفوعة', 'paid', _selectedDecision, (v) => setState(() => _selectedDecision = v)),
          const SizedBox(width: 4),
          _buildChip('بخصم', 'unpaid', _selectedDecision, (v) => setState(() => _selectedDecision = v)),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, String current, ValueChanged<String> onSelected) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(
            color: isSelected ? AppColors.primaryContainer : AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel(List<LeaveRequest> requests) async {
    setState(() => _isExporting = true);
    try {
      final path = await HrExcelExportService.exportLeaveRequestsGroupedByBranch(
        requests: requests,
      );
      if (mounted) {
        setState(() => _isExporting = false);
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم تصدير تقرير الإجازات لجميع الفروع مرتب فرع فرع بنجاح!\nالمسار: $path',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF107C41),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequest req;

  const _LeaveRequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (req.status) {
      case 'approved':
        statusColor = AppColors.statusGreen;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.secondary;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: BorderSide(color: AppColors.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${req.jobRole} - ${req.branchName ?? 'المركز الرئيسي'}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    req.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'من ${DateFormat('yyyy-MM-dd').format(req.startDate)} إلى ${DateFormat('yyyy-MM-dd').format(req.endDate)} (${req.daysCount} أيام)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'السبب: ${req.reason}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (req.status != 'pending') ...[
              const SizedBox(height: 8),
              Text(
                'القرار: ${req.decisionTypeLabel}',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (req.decisionNotes != null && req.decisionNotes!.isNotEmpty)
                Text(
                  'ملاحظة الإدارة: ${req.decisionNotes}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
            ],
            if (req.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _decide(context, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('رفض'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _decide(context, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                    ),
                    child: const Text('موافقة'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _decide(BuildContext context, String status) {
    if (status == 'rejected') {
      context.read<HrLeaveRequestsCubit>().decideRequest(
        id: req.id,
        status: status,
      );
      return;
    }

    // Approve requires knowing if it's with or without deduction
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String decisionType = 'with_deduction';
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('الموافقة على الإجازة'),
              content: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: const Text('إجازة مدفوعة (بدون خصم من الراتب)'),
                      value: 'without_deduction',
                      groupValue: decisionType,
                      onChanged: (v) => setState(() => decisionType = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('إجازة بخصم (خصم يوم من الراتب)'),
                      value: 'with_deduction',
                      groupValue: decisionType,
                      onChanged: (v) => setState(() => decisionType = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final isPaid = decisionType == 'without_deduction';
                    context.read<HrLeaveRequestsCubit>().decideRequest(
                      id: req.id,
                      status: 'approved',
                      decisionType: decisionType,
                      isPaid: isPaid,
                    );
                  },
                  child: const Text('تأكيد الموافقة'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
