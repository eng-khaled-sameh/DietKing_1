import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_modules.dart';
import '../../cubits/catalog/catalog_cubit.dart';
import '../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../cubits/session/session_cubit.dart';
import '../../features/auth/presentation/widgets/start_shift_dialog.dart';
import '../../features/meal_sales/presentation/screens/meal_sales_screen.dart';
import '../../models/user_profile.dart';
import '../inventory/cubit/inventory_cubit.dart';
import '../inventory/inventory_screen.dart';
import 'placeholder_module_screen.dart';

Future<void> startAndOpenModule(
  BuildContext context,
  AppModule module,
  UserProfile profile, {
  bool replace = false,
}) async {
  final sessionCubit = context.read<SessionCubit>();
  if (sessionCubit.hasModuleSession(module)) {
    sessionCubit.resume(
      userId: profile.userId,
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
      module: module,
    );
    if (!context.mounted) return;
    prepareModule(context, module);
    final route = MaterialPageRoute<void>(builder: (_) => _moduleScreen(module));
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
    return;
  }
  final start = await StartShiftDialog.show(context, module);
  if (!context.mounted || start == null) return;
  context.read<SessionCubit>().start(
        userId: profile.userId,
        email: profile.email,
        fullName: profile.fullName,
        role: profile.role,
        module: module,
        shift: start.shift,
        branch: start.branch,
        openingCash: start.openingCash,
      );
  if (!context.mounted) return;
  prepareModule(context, module);
  final route = MaterialPageRoute<void>(builder: (_) => _moduleScreen(module));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

Widget _moduleScreen(AppModule module) {
  return switch (module) {
    AppModule.cashier => const MealSalesScreen(),
    AppModule.inventory => const InventoryScreen(),
    AppModule.accounts || AppModule.hr => PlaceholderModuleScreen(module: module),
  };
}

void prepareModule(BuildContext context, AppModule module) {
  if (module == AppModule.cashier) {
    // شاشة طلبات المخزون ضمن نقطة البيع تعتمد على نفس كتالوج المخزون.
    // يبدأ التحميل مرة واحدة فقط داخل InventoryCubit، لذا لن يعيد المزامنة
    // عند الرجوع إلى نقطة البيع في نفس الجلسة.
    context.read<InventoryCubit>().initModule();
    context.read<CatalogCubit>().load();
    context.read<PosSettingsCubit>().load();
  }
}
