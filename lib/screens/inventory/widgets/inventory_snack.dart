import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

void showInventorySnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.ibmPlexSansArabic(),
      ),
      backgroundColor: isError ? AppColors.error : AppColors.surfaceContainerHigh,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
