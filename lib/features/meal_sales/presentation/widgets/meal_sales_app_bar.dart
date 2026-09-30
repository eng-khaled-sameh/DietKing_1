import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_session_info_row.dart';
import '../../../../core/widgets/pos_window_title_row.dart';
import 'meal_sales_nav_tabs.dart';

/// الهيدر الكامل لشاشة البيع بالوجبة:
/// يجمع شريط عنوان النافذة + شريط معلومات الجلسة + تبويبات التنقل وشارات الاختصارات
class MealSalesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MealSalesAppBar({super.key});

  /// مجموع ارتفاع الصفوف:
  /// titleBarHeight(40) + sessionInfoRow(48) + navBarRow(44) = 132
  static const double _totalHeight = AppDimens.titleBarHeight + 48.0 + 44.0;

  @override
  Size get preferredSize => const Size.fromHeight(_totalHeight);

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1. شريط عنوان النافذة ──────────────────────────────────────────
        PosWindowTitleRow(),

        // ── 2. شريط معلومات الجلسة والكاشير ────────────────────────────────
        PosSessionInfoRow(),

        // ── 3. تبويبات التنقل المتطابقة مع شارات الاختصارات ────────────────
        MealSalesNavTabs(initialIndex: 0),
      ],
    );
  }
}
