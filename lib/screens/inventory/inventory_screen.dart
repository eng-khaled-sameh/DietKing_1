import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/global_app_layout.dart';
import 'cubit/inventory_cubit.dart';
import 'inventory_shell.dart';

/// نقطة دخول وحدة المخزون. تفتح مباشرة على قسم الخامات.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().initModule();
  }

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GlobalAppLayout(child: InventoryShell()),
      ),
    );
  }
}
