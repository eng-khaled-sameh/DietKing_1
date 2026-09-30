import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import 'login_logo_header.dart';
import 'login_submit_button.dart';
import 'login_text_field.dart';
import 'shift_selection_dialog.dart';

/// بطاقة تسجيل الدخول الرئيسية التي تجمع الهيدر والحقول وزر الدخول والإرشادات
class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    this.cashierController,
    this.passwordController,
    this.onSubmit,
  });

  final TextEditingController? cashierController;
  final TextEditingController? passwordController;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppDimens.loginCardMaxWidth,
      ),
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
                    children: [
                      // 1. هيدر اللوجو والعناوين
                      const LoginLogoHeader(),
                      const SizedBox(height: AppDimens.spaceXl),

                      // 2. حقل اسم الكاشير
                      LoginTextField(
                        label: 'اسم المستخدم / الرقم الوظيفي',
                        hintText: 'أدخل اسم المستخدم أو الرقم الوظيفي',
                        icon: Icons.badge_outlined,
                        controller: cashierController,
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // 3. حقل كلمة السر
                      LoginTextField(
                        label: 'كلمة السر',
                        hintText: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        controller: passwordController,
                      ),
                      const SizedBox(height: AppDimens.spaceXl),

                      // 4. زر تقديم تسجيل الدخول (يفتح نافذة اختيار الوردية)
                      LoginSubmitButton(
                        onPressed: onSubmit ??
                            () => ShiftSelectionDialog.show(context),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // 5. نص إرشاد Enter لتسجيل الدخول السريع
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
