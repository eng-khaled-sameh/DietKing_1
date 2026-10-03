import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import 'cubit/inventory_cubit.dart';
import 'inventory_shell.dart';

/// شاشة المخزون الرئيسية
/// تستخدم InventoryCubit المسجّل في MultiBlocProvider (main.dart)
/// وتستدعي initModule عند أول فتح لتحميل الكتالوج والأرصدة
class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // تحميل الكتالوج والأرصدة عند أول فتح للشاشة
    context.read<InventoryCubit>().initModule();
  }

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: InventoryShell(),
      ),
    );
  }
}
