import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/screens/inventory/cubit/inventory_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../data/inventory/inventory_api.dart';
import '../../data/inventory/inventory_sync.dart';
import '../../data/inventory/inventory_cache.dart';
import 'inventory_shell.dart';

class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final api = InventoryApi(supabase);
        final cache = InventoryCache();
        final sync = InventorySync(supabase, cache);
        return InventoryCubit(api, sync)..loadInitialData();
      },
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: InventoryShell(),
        ),
      ),
    );
  }
}
