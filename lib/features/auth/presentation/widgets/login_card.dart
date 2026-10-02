import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../../models/login_branch.dart';
import '../screens/login_screen.dart';
import 'login_logo_header.dart';
import 'login_submit_button.dart';
import 'login_text_field.dart';

/// بطاقة تسجيل الدخول الرئيسية
class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    // ── الفرع ──
    required this.selectedBranch,
    this.branchError,
    required this.onBranchChanged,
    required this.onBranchRetry,
    // ── الوردية ──
    required this.selectedShift,
    this.shiftError,
    required this.onShiftChanged,
    // ── حقول المستخدم ──
    this.cashierController,
    this.passwordController,
    this.cashierFocusNode,
    this.passwordFocusNode,
    this.onSubmit,
    this.isLoading = false,
    this.errorMessage,
    this.usernameError,
    this.passwordError,
    required this.step,
    required this.onNext,
    required this.onBack,
  });

  final int step;
  final VoidCallback onNext;
  final VoidCallback onBack;

  final LoginBranch? selectedBranch;
  final String? branchError;
  final ValueChanged<LoginBranch?> onBranchChanged;
  final VoidCallback onBranchRetry;

  final String? selectedShift;
  final String? shiftError;
  final ValueChanged<String?> onShiftChanged;

  final TextEditingController? cashierController;
  final TextEditingController? passwordController;
  final FocusNode? cashierFocusNode;
  final FocusNode? passwordFocusNode;
  final VoidCallback? onSubmit;
  final bool isLoading;
  final String? errorMessage;
  final String? usernameError;
  final String? passwordError;
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.loginCardMaxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: AppDimens.cardElevation,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // خط علوي متلاشٍ
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: AppColors.topBarGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimens.radiusXl),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. هيدر اللوجو
                      const Center(child: LoginLogoHeader()),
                      const SizedBox(height: AppDimens.spaceXl),

                      if (step == 1) ...[
                        // 4. حقل اسم المستخدم
                        LoginTextField(
                          label: 'اسم المستخدم / الرقم الوظيفي',
                          hintText: 'أدخل اسم المستخدم أو الرقم الوظيفي',
                          icon: Icons.badge_outlined,
                          controller: cashierController,
                          focusNode: cashierFocusNode,
                          nextFocusNode: passwordFocusNode,
                          textInputAction: TextInputAction.next,
                          errorText: usernameError,
                        ),
                        const SizedBox(height: AppDimens.spaceLg),

                        // 5. حقل كلمة المرور
                        LoginTextField(
                          label: 'كلمة السر',
                          hintText: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          controller: passwordController,
                          focusNode: passwordFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: isLoading ? null : () => onNext(),
                          errorText: passwordError,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),

                        // 6. رسالة خطأ المصادقة
                        if (errorMessage != null && errorMessage!.isNotEmpty)
                          _AuthErrorBanner(message: errorMessage!),

                        const SizedBox(height: AppDimens.spaceMd),

                        // 7. زر التالي
                        SizedBox(
                          width: double.infinity,
                          height: AppDimens.buttonHeight,
                          child: FilledButton(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusMd,
                                ),
                              ),
                            ),
                            child: Text(
                              'التالي',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontLg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // 2. اختيار الفرع
                        _BranchDropdown(
                          selectedBranch: selectedBranch,
                          errorText: branchError,
                          onChanged: onBranchChanged,
                          onRetry: onBranchRetry,
                        ),
                        const SizedBox(height: AppDimens.spaceLg),

                        // 3. اختيار الوردية
                        _ShiftSelector(
                          selectedShift: selectedShift,
                          errorText: shiftError,
                          onChanged: onShiftChanged,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),

                        // رسالة خطأ المصادقة في الخطوة 2
                        if (errorMessage != null && errorMessage!.isNotEmpty)
                          _AuthErrorBanner(message: errorMessage!),

                        const SizedBox(height: AppDimens.spaceMd),

                        // أزرار الرجوع وتسجيل الدخول
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: AppDimens.buttonHeight,
                                child: OutlinedButton(
                                  onPressed: isLoading ? null : onBack,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.onSurface,
                                    side: BorderSide(
                                      color: AppColors.outlineVariant,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusMd,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'رجوع',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontMd,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.spaceMd),
                            Expanded(
                              flex: 2,
                              child: LoginSubmitButton(
                                onPressed: isLoading ? null : onSubmit,
                                isLoading: isLoading,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppDimens.spaceLg),

                      // 8. إرشاد Enter
                      const _EnterHint(),
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
}

// ── Dropdown الفرع ─────────────────────────────────────────────────────────────

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.selectedBranch,
    this.errorText,
    required this.onChanged,
    required this.onRetry,
  });

  final LoginBranch? selectedBranch;
  final String? errorText;
  final ValueChanged<LoginBranch?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'الفرع',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // الحاوية بنفس ستايل LoginTextField
        BlocBuilder<BranchesCubit, BranchesState>(
          builder: (context, state) {
            // ── حالة التحميل ──
            if (state.status == BranchesStatus.loading) {
              return _fieldContainer(
                hasError: false,
                child: Row(
                  children: [
                    const SizedBox(width: AppDimens.spaceMd),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Text(
                      'جارٍ تحميل الفروع...',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontMd,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── حالة الفشل ──
            if (state.status == BranchesStatus.failure) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldContainer(
                    hasError: true,
                    child: Row(
                      children: [
                        const SizedBox(width: AppDimens.spaceMd),
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: AppDimens.iconMd,
                          color: Color(0xFFCF6679),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: Text(
                            state.errorMessage ?? 'تعذر تحميل الفروع',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              color: const Color(0xFFCF6679),
                            ),
                          ),
                        ),
                        // زر إعادة المحاولة مدمج
                        InkWell(
                          onTap: onRetry,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.spaceSm,
                              vertical: 4,
                            ),
                            child: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontXs,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // ── حالة loaded أو initial ──
            final branches = state.branches;

            return _fieldContainer(
              hasError: hasError,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LoginBranch>(
                  value: selectedBranch,
                  isExpanded: true,
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: hasError
                        ? const Color(0xFFCF6679)
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: AppDimens.iconMd,
                          color: hasError
                              ? const Color(0xFFCF6679)
                              : AppColors.primary,
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Text(
                          branches.isEmpty
                              ? 'لا توجد فروع متاحة'
                              : 'اختر الفرع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontMd,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  dropdownColor: AppColors.surfaceContainerHigh,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    color: AppColors.onSurface,
                  ),
                  items: branches.map((branch) {
                    return DropdownMenuItem<LoginBranch>(
                      value: branch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceSm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: AppDimens.iconMd,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            Expanded(
                              child: Text(
                                branch.code.isNotEmpty
                                    ? '${branch.name}  [${branch.code}]'
                                    : branch.name,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontMd,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: branches.isEmpty ? null : onChanged,
                  selectedItemBuilder: (ctx) => branches.map((branch) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceSm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: AppDimens.iconMd,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            Text(
                              branch.code.isNotEmpty
                                  ? '${branch.name}  [${branch.code}]'
                                  : branch.name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontMd,
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),

        // رسالة الخطأ
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: Color(0xFFCF6679),
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  color: const Color(0xFFCF6679),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _fieldContainer({required bool hasError, required Widget child}) {
    return Container(
      height: AppDimens.inputHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: hasError
              ? const Color(0xFFCF6679)
              : AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}

// ── اختيار الوردية (Radio Buttons) ────────────────────────────────────────────

class _ShiftSelector extends StatelessWidget {
  const _ShiftSelector({
    required this.selectedShift,
    this.errorText,
    required this.onChanged,
  });

  final String? selectedShift;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'الوردية',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // حاوية الـ Radio buttons
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFCF6679)
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: AppShifts.all.asMap().entries.map((entry) {
              final idx = entry.key;
              final shift = entry.value;
              final isLast = idx == AppShifts.all.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: () => onChanged(shift),
                    borderRadius: BorderRadius.vertical(
                      top: idx == 0
                          ? Radius.circular(AppDimens.radiusMd)
                          : Radius.zero,
                      bottom: isLast
                          ? Radius.circular(AppDimens.radiusMd)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: shift,
                            groupValue: selectedShift,
                            onChanged: onChanged,
                            activeColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shift,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              fontWeight: selectedShift == shift
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selectedShift == shift
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: AppColors.outlineVariant.withValues(alpha: 0.15),
                    ),
                ],
              );
            }).toList(),
          ),
        ),

        // رسالة الخطأ
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: Color(0xFFCF6679),
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  color: const Color(0xFFCF6679),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── بانر خطأ المصادقة ─────────────────────────────────────────────────────────

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFCF6679);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: errorColor, size: 18),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                color: errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── إرشاد Enter ──────────────────────────────────────────────────────────────

class _EnterHint extends StatelessWidget {
  const _EnterHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.keyboard_outlined,
          size: AppDimens.iconSm,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          'اضغط Enter لتسجيل الدخول السريع',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
