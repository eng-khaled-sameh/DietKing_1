import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../../models/enums.dart';

class RawFiltersBar extends StatefulWidget {
  const RawFiltersBar({super.key});

  @override
  State<RawFiltersBar> createState() => _RawFiltersBarState();
}

class _RawFiltersBarState extends State<RawFiltersBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<InventoryCubit>().state.rawQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (previous, current) =>
          previous.rawCategoryIdFilter != current.rawCategoryIdFilter ||
          previous.rawLowOnly != current.rawLowOnly,
      builder: (context, state) {
        final cubit = context.read<InventoryCubit>();
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchController,
                onChanged: cubit.setRawQuery,
                style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو SKU...',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.rawCategoryIdFilter,
                    hint: Text(
                      'جميع الفئات',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                    dropdownColor: AppColors.surfaceContainerHigh,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.onSurface),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'جميع الفئات',
                          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                        ),
                      ),
                      ...RawCategory.values.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.name,
                          child: Text(
                            category.label,
                            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                          ),
                        ),
                      ),
                    ],
                    onChanged: cubit.setRawCategoryFilter,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            FilterChip(
              label: Text(
                'نواقص فقط',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: state.rawLowOnly ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
              selected: state.rawLowOnly,
              onSelected: (_) => cubit.toggleRawLowOnly(),
              backgroundColor: AppColors.surfaceContainerHigh,
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: state.rawLowOnly ? AppColors.primary : Colors.transparent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
