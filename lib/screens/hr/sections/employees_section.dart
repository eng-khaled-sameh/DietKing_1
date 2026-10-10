import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubit/employees_cubit.dart';
import '../cubit/employees_state.dart';
import 'widgets/employee_form.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../models/hr_enums.dart';

class EmployeesSection extends StatelessWidget {
  const EmployeesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeesCubit(),
      child: const _EmployeesView(),
    );
  }
}

class _EmployeesView extends StatelessWidget {
  const _EmployeesView();

  void _showNewEmployeeForm(BuildContext context) {
    final cubit = context.read<EmployeesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppDimens.spaceLg),
          child: EmployeeForm(
            onSuccess: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة الموظف بنجاح')),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEmployeeDetails(BuildContext context, EmployeeModel emp) {
    final cubit = context.read<EmployeesCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: AppColors.primary),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(child: Text(emp.fullName)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('كود الموظف', emp.code),
              _detailRow('المسمى الوظيفي', emp.jobRole.label),
              _detailRow('الفرع/الموقع', emp.locationName),
              _detailRow('الراتب الأساسي', emp.basicSalary.toString()),
              if (emp.phone != null && emp.phone!.isNotEmpty)
                _detailRow('رقم الهاتف', emp.phone!),
              if (emp.hireDate != null)
                _detailRow(
                  'تاريخ التعيين',
                  emp.hireDate!.toIso8601String().split('T').first,
                ),
              if (emp.qualification != null && emp.qualification!.isNotEmpty)
                _detailRow('المؤهل', emp.qualification!),
              if (emp.notes != null && emp.notes!.isNotEmpty)
                _detailRow('ملاحظات', emp.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showChangeStatusDialog(context, emp, cubit);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('تغيير الحالة (إيقاف/فصل)'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusDialog(
    BuildContext context,
    EmployeeModel emp,
    EmployeesCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        EmployeeStatus selectedStatus = emp.status;
        final reasonController = TextEditingController();
        DateTime? suspensionEnd;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تغيير حالة الموظف'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<EmployeeStatus>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'الحالة الجديدة',
                      ),
                      items: EmployeeStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedStatus = v);
                      },
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    if (selectedStatus == EmployeeStatus.suspended)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تاريخ انتهاء الإيقاف'),
                        subtitle: Text(
                          suspensionEnd != null
                              ? suspensionEnd!
                                    .toIso8601String()
                                    .split('T')
                                    .first
                              : 'اختر التاريخ',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (date != null)
                            setState(() => suspensionEnd = date);
                        },
                      ),
                    const SizedBox(height: AppDimens.spaceMd),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'السبب (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedStatus == EmployeeStatus.suspended &&
                        suspensionEnd == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء اختيار تاريخ انتهاء الإيقاف'),
                        ),
                      );
                      return;
                    }
                    try {
                      await cubit.updateEmployeeStatus(
                        id: emp.id,
                        status: selectedStatus,
                        reason: reasonController.text.isEmpty
                            ? null
                            : reasonController.text,
                        suspensionEnd: suspensionEnd
                            ?.toIso8601String()
                            .split('T')
                            .first,
                      );
                      if (context.mounted) {
                        Navigator.pop(context); // close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تحديث الحالة بنجاح'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الموظفين',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => context
                        .read<EmployeesCubit>()
                        .fetchEmployees(refresh: true),
                    tooltip: 'تحديث',
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  ElevatedButton.icon(
                    onPressed: () => _showNewEmployeeForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('موظف جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Counters
        BlocBuilder<EmployeesCubit, EmployeesState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
              ),
              child: Row(
                children: [
                  _buildCounterCard(
                    context,
                    'نشط',
                    state.counts['active'] ?? 0,
                    AppColors.statusGreen,
                    EmployeeStatus.active,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'موقوف',
                    state.counts['suspended'] ?? 0,
                    AppColors.secondary,
                    EmployeeStatus.suspended,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'مفصول',
                    state.counts['terminated'] ?? 0,
                    AppColors.error,
                    EmployeeStatus.terminated,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'مؤرشف',
                    state.counts['archived'] ?? 0,
                    AppColors.outline,
                    EmployeeStatus.archived,
                    state.status,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: AppDimens.spaceLg),

        // List
        Expanded(
          child: BlocBuilder<EmployeesCubit, EmployeesState>(
            builder: (context, state) {
              if (state.isLoading && state.employees.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null && state.employees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      ElevatedButton(
                        onPressed: () => context
                            .read<EmployeesCubit>()
                            .fetchEmployees(refresh: true),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }
              if (state.employees.isEmpty) {
                return const Center(child: Text('لا توجد نتائج'));
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 140,
                  crossAxisSpacing: AppDimens.spaceMd,
                  mainAxisSpacing: AppDimens.spaceMd,
                ),
                itemCount:
                    state.employees.length + (state.hasReachedMax ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index >= state.employees.length) {
                    context.read<EmployeesCubit>().fetchEmployees();
                    return const Padding(
                      padding: EdgeInsets.all(AppDimens.spaceMd),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final emp = state.employees[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      side: BorderSide(
                        color: AppColors.outline.withOpacity(0.1),
                      ),
                    ),
                    color: AppColors.surfaceContainerLow,
                    child: InkWell(
                      onTap: () => _showEmployeeDetails(context, emp),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        emp.code,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(emp.status.name),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSm,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.work_outline,
                                    size: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${emp.jobRole.label} - ${emp.locationName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCounterCard(
    BuildContext context,
    String label,
    int count,
    Color color,
    EmployeeStatus cardStatus,
    EmployeeStatus? currentStatus,
  ) {
    final isSelected = cardStatus == currentStatus;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSelected) {
            context.read<EmployeesCubit>().updateFilters(clearStatus: true);
          } else {
            context.read<EmployeesCubit>().updateFilters(
              status: cardStatus,
              clearStatus: false,
            );
          }
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.25)
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String statusName) {
    Color color;
    String label;
    switch (statusName) {
      case 'active':
        color = AppColors.statusGreen;
        label = 'نشط';
        break;
      case 'suspended':
        color = AppColors.secondary;
        label = 'موقوف';
        break;
      case 'terminated':
        color = AppColors.error;
        label = 'مفصول';
        break;
      default:
        color = AppColors.outline;
        label = 'مؤرشف';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
