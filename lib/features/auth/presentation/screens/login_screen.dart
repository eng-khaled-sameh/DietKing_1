import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../widgets/login_card.dart';
import '../widgets/login_footer.dart';
import '../widgets/login_status_strip.dart';
import '../widgets/login_title_bar.dart';

/// شاشة تسجيل دخول الكاشير الرئيسية — دايت كنج POS
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── 1. خلفية متدرجة مع توهجات دائرية ──────────────────────────
            const _BackgroundGradient(),
            // ── 2. ترتيب الويدجتس الرئيسي ────────────────────────────────────
            Column(
              children: [
                // شريط العنوان العلوي (خارج الـ padding)
                const LoginTitleBar(),

                // شريط حالة النظام والنقطة المصرحة
                const LoginStatusStrip(),

                // بطاقة تسجيل الدخول وسط الصفحة
                const Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceLg,
                      ),
                      child: LoginCard(),
                    ),
                  ),
                ),
                // فوتر الصفحة السفلي
                const LoginFooter(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// خلفية متدرجة شفافة تمنح الشاشة مظهرًا حديثًا وفاخرًا
class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // توهج ذهبي علوي يسار
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // توهج أخضر سفلي يمين
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.tertiary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
