import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/models/deduction_bonus_model.dart';
import '../cubit/hr_deductions_bonuses_cubit.dart';

import '../services/hr_excel_export_service.dart';

class DeductionsBonusesSection extends StatelessWidget {
  const DeductionsBonusesSection({super.key});

  @override
  Widget build(BuildContext context) {
    // الـ HrDeductionsBonusesCubit مُوفَّر من HrShell — لا نُنشئه هنا
    return const _DeductionsBonusesView();
  }
}

class _DeductionsBonusesView extends StatefulWidget {
  const _DeductionsBonusesView();

  @override
  State<_DeductionsBonusesView> createState() => _DeductionsBonusesViewState();
}

class _DeductionsBonusesViewState extends State<_DeductionsBonusesView> {
  bool _isExporting = false;
  String _selectedBranch = 'all';
  String _selectedType = 'all'; // 'all', 'deduction', 'bonus'
  String _selectedStatus = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HrDeductionsBonusesCubit, HrDeductionsBonusesState>(
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
          if (_selectedType != 'all' && r.type != _selectedType) return false;
          if (_selectedStatus != 'all' && r.status != _selectedStatus) return false;
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
                    return const Center(
                      child: Text('لا توجد طلبات خصم أو مكافأة'),
                    );
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
                      return _DeductionBonusCard(req: req);
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

  Widget _buildHeader(BuildContext context, List<DeductionBonusRequest> requests) {
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
                  'الخصومات والإضافات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'إدارة واعتماد طلبات الخصم والمكافآت وتصديرها مرتبة بالفروع',
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
                context.read<HrDeductionsBonusesCubit>().fetchRequests(force: true),
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

          // فلتر النوع
          Text(
            'النوع:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _buildChip('الكل', 'all', _selectedType, (v) => setState(() => _selectedType = v)),
          const SizedBox(width: 4),
          _buildChip('خصومات', 'deduction', _selectedType, (v) => setState(() => _selectedType = v)),
          const SizedBox(width: 4),
          _buildChip('مكافآت', 'bonus', _selectedType, (v) => setState(() => _selectedType = v)),

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

  Future<void> _exportExcel(List<DeductionBonusRequest> requests) async {
    setState(() => _isExporting = true);
    try {
      final path = await HrExcelExportService.exportDeductionsAndBonusesGroupedByBranch(
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
                      'تم تصدير تقرير الخصومات والإضافات لجميع الفروع مرتب فرع فرع بنجاح!\nالمسار: $path',
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

class _DeductionBonusCard extends StatelessWidget {
  final DeductionBonusRequest req;

  const _DeductionBonusCard({required this.req});

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

    final isDeduction = req.type == 'deduction';

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
                      Row(
                        children: [
                          Icon(
                            isDeduction
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isDeduction
                                ? AppColors.error
                                : AppColors.statusGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${req.typeLabel} — ${req.amountLabel}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDeduction
                                  ? AppColors.error
                                  : AppColors.statusGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        req.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'السبب/الملاحظة: ${req.notes}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (req.status != 'pending' && req.finalCashAmount != null) ...[
              const SizedBox(height: 8),
              Text(
                'المبلغ المعتمد النهائي: ${req.finalCashAmount!.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
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
                    child: const Text('موافقة وتحديد المبلغ'),
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
      context.read<HrDeductionsBonusesCubit>().decideRequest(
        id: req.id,
        status: status,
      );
      return;
    }

    // Approve logic
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDays = req.amountType == 'days';
        String inputValue = '';
        if (isDays && req.daysAmount != null) {
          inputValue = req.daysAmount.toString();
        } else if (!isDays && req.cashAmount != null) {
          inputValue = req.cashAmount.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            double? parsedInput = double.tryParse(inputValue);
            double calculatedCash = 0;

            if (isDays && parsedInput != null && req.basicSalary != null) {
              calculatedCash = (req.basicSalary! / 30.0) * parsedInput;
            } else if (!isDays && parsedInput != null) {
              calculatedCash = parsedInput;
            }

            return AlertDialog(
              title: Text('الموافقة على ال${req.typeLabel}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'القيمة النقدية المحسوبة: ${calculatedCash.toStringAsFixed(2)} ر.س (بناءً على الراتب الأساسي)',
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                    ),
                  TextFormField(
                    initialValue: inputValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      labelText: isDays
                          ? 'عدد الأيام المعتمدة'
                          : 'القيمة النقدية المعتمدة (ر.س)',
                    ),
                    onChanged: (v) {
                      setState(() {
                        inputValue = v;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    double? finalCash;
                    double? parsed = double.tryParse(inputValue);
                    if (parsed != null && parsed >= 0) {
                      if (isDays && req.basicSalary != null) {
                        finalCash = (req.basicSalary! / 30.0) * parsed;
                      } else if (!isDays) {
                        finalCash = parsed;
                      }
                    }
                    if (finalCash == null) return;

                    Navigator.of(ctx).pop();
                    context.read<HrDeductionsBonusesCubit>().decideRequest(
                      id: req.id,
                      status: 'approved',
                      finalCashAmount: finalCash,
                    );
                  },
                  child: const Text('تأكيد واعتماد'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
