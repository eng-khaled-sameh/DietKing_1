import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_modules.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../cubits/catalog/catalog_cubit.dart';
import '../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../features/meal_sales/presentation/screens/meal_sales_screen.dart';
import '../inventory/inventory_dashboard_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  bool _isNavigating = false;

  void _handleModuleTap(AppModule module) {
    if (_isNavigating) return;

    if (module == AppModule.cashier) {
      setState(() {
        _isNavigating = true;
      });

      // تحميل بيانات الكاشير عند الدخول للقسم فقط
      context.read<CatalogCubit>().load();
      context.read<PosSettingsCubit>().load();

      // الانتقال بالـ push العادي للتمكن من الرجوع لاحقاً لشاشة الكروت
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MealSalesScreen(),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    } else if (module == AppModule.inventory) {
      setState(() {
        _isNavigating = true;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const InventoryDashboardScreen(),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هذا القسم قيد التطوير',
            style: GoogleFonts.ibmPlexSansArabic(),
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = allowedModules();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'اختر القسم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXxl,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXxl),
                Wrap(
                  spacing: AppDimens.spaceLg,
                  runSpacing: AppDimens.spaceLg,
                  alignment: WrapAlignment.center,
                  children: modules.map((module) {
                    return _ModuleCard(
                      module: module,
                      onTap: () => _handleModuleTap(module),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final AppModule module;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isHoveredOrFocused = _isHovered || _isFocused;

    return FocusableActionDetector(
      onShowHoverHighlight: (isHovered) {
        setState(() {
          _isHovered = isHovered;
        });
      },
      onShowFocusHighlight: (isFocused) {
        setState(() {
          _isFocused = isFocused;
        });
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onTap();
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 170,
          height: 150,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: isHoveredOrFocused
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: isHoveredOrFocused
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
              width: isHoveredOrFocused ? 2 : 1,
            ),
            boxShadow: isHoveredOrFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Icon(
                        widget.module.icon,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      widget.module.arabicName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontMd,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!widget.module.isImplemented)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      'قريباً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
