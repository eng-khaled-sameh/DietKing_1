import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubits/cart_cubit.dart';
import '../models/protein_matrix_item.dart';

/// جدول مصفوفة البروتين:
/// الأعمدة: دجاج / لحم / سمك
/// الصفوف:  100غ / 150غ / 200غ / 250غ / 300غ
/// كل خلية: زر ضغط يضيف الصنف للفاتورة عبر [CartCubit]
class ProteinMatrixTable extends StatelessWidget {
  const ProteinMatrixTable({super.key});

  static const List<String> _columns = ['دجاج', 'لحم', 'سمك'];
  static const List<String> _rows = ['100غ', '150غ', '200غ', '250غ', '300غ'];

  static const Map<String, IconData> _columnIcons = {
    'دجاج': Icons.lunch_dining_rounded,
    'لحم': Icons.kebab_dining_rounded,
    'سمك': Icons.set_meal_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── صف رؤوس الأعمدة ──────────────────────────────────────────────
          _buildHeaderRow(),
          const Divider(height: 1, color: Color(0x20FFFFFF)),

          // ── صفوف الأوزان ──────────────────────────────────────────────────
          ...List.generate(_rows.length, (rowIdx) {
            final weight = _rows[rowIdx];
            final isLast = rowIdx == _rows.length - 1;
            return Column(
              children: [
                _buildDataRow(context, weight),
                if (!isLast)
                  const Divider(height: 1, color: Color(0x14FFFFFF)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          // خلية زاوية فارغة (موضع label الوزن)
          const SizedBox(width: 50),
          ...List.generate(_columns.length, (i) {
            final col = _columns[i];
            return Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _columnIcons[col],
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      col,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String weight) {
    // نجد السعر من أول خلية في هذا الصف (السعر موحد لجميع الأعمدة)
    final price = proteinMatrixItems
        .firstWhere((e) => e.weightLabel == weight)
        .price;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── label الوزن على اليمين ───────────────────────────────────────
          SizedBox(
            width: 50,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm - 2),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  weight,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // ── خلايا الأعمدة ─────────────────────────────────────────────────
          ...List.generate(_columns.length, (colIdx) {
            final protein = _columns[colIdx];
            return Expanded(
              child: _MatrixCell(
                proteinType: protein,
                weightLabel: weight,
                price: price,
                showLeftBorder: true,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── خلية واحدة في الجدول ─────────────────────────────────────────────────────

class _MatrixCell extends StatefulWidget {
  final String proteinType;
  final String weightLabel;
  final double price;
  final bool showLeftBorder;

  const _MatrixCell({
    required this.proteinType,
    required this.weightLabel,
    required this.price,
    this.showLeftBorder = false,
  });

  @override
  State<_MatrixCell> createState() => _MatrixCellState();
}

class _MatrixCellState extends State<_MatrixCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context) {
    // تأثير بصري مؤقت
    _controller.forward().then((_) => _controller.reverse());

    // إضافة للسلة
    context.read<CartCubit>().addItem(
          name: widget.proteinType,
          variantLabel: widget.weightLabel,
          unitPrice: widget.price,
        );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          splashColor: AppColors.primaryContainer.withValues(alpha: 0.35),
          highlightColor: AppColors.primaryContainer.withValues(alpha: 0.18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                left: widget.showLeftBorder
                    ? BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      )
                    : BorderSide.none,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.price.toInt()}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'ر.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs - 1,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
