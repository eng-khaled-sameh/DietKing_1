import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/raw/raw_filters_bar.dart';
import '../widgets/raw/raw_materials_table.dart';
import '../dialogs/add_raw_material_dialog.dart';
import '../dialogs/import_dialog.dart';

class RawMaterialsSection extends StatelessWidget {
  const RawMaterialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخامات في المخزون',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const ImportDialog(),
                      );
                    },
                    icon: const Icon(Icons.file_upload_outlined, color: AppColors.onSurface),
                    label: Text(
                      'استيراد / تصدير',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const AddRawMaterialDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, color: AppColors.onPrimary),
                    label: Text(
                      'إضافة خامة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const RawFiltersBar(),
          const SizedBox(height: 16),
          const Expanded(child: RawMaterialsTable()),
        ],
      ),
    );
  }
}
