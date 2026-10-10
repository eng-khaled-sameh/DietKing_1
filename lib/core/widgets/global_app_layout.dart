import 'package:flutter/material.dart';

import 'pos_session_info_row.dart';
import 'pos_status_footer.dart';
import 'pos_window_title_row.dart';

/// مخطط عام يشمل البار العلوي (شريط العنوان + معلومات الجلسة) والفوتر السفلي.
/// يمكن استخدامه لتغليف أي صفحة رئيسية في التطبيق (الكاشير، المخزون، الحسابات، شؤون الموظفين، الخ)
/// لضمان توحيد التصميم.
class GlobalAppLayout extends StatelessWidget {
  final Widget child;

  const GlobalAppLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PosWindowTitleRow(),
        const PosSessionInfoRow(),
        Expanded(child: child),
        const PosStatusFooter(),
      ],
    );
  }
}
