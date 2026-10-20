import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// بطاقة إضافة سريعة مُصغّرة (ساندوتش، سلطة، مشروب، سناك)
/// — تدعم تفاعل الماوس (Hover) وتأثير الحركة عند الضغط (Scale bounce) متوافقة مع المنتجات الأساسية
class QuickAddonCard extends StatefulWidget {
  final String label;
  // subLabel محذوف من العرض — يُحتفظ به للتوافق إن استُدعي من مكان آخر
  final String subLabel;
  final double price;
  final IconData icon;
  final VoidCallback? onTap;

  const QuickAddonCard({
    super.key,
    required this.label,
    required this.subLabel,
    required this.price,
    required this.icon,
    this.onTap,
  });

  @override
  State<QuickAddonCard> createState() => _QuickAddonCardState();
}

class _QuickAddonCardState extends State<QuickAddonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.35),
              width: _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: _isHovered ? 8 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              splashColor: AppColors.primaryContainer.withValues(alpha: 0.35),
              highlightColor: AppColors.primaryContainer.withValues(alpha: 0.18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: AppDimens.spaceXs,
                ),
                child: Row(
                  children: [
                    // ── دائرة الأيقونة (مُصغّرة) ──────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? AppColors.primaryContainer.withValues(alpha: 0.2)
                            : AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isHovered
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(width: AppDimens.spaceSm),

                    // ── اسم الصنف ────────────────────────────
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontSm,
                          fontWeight: FontWeight.w700,
                          color: _isHovered
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                      ),
                    ),

                    const SizedBox(width: AppDimens.spaceXs),

                    // ── السعر ─────────────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                        border: Border.all(
                          color: _isHovered
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.outlineVariant.withValues(
                                  alpha: 0.25,
                                ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${widget.price.toInt()}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'ر.س',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs - 2,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
