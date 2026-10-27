import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// نافذة منبثقة سريعة لتحديد ما إذا كانت الإضافة عادية (مدفوعة) أم ضمن باقة (0 ريال)
///
/// تُعيد:
/// - [false]: إضافة عادية (تُسجل بسعرها الطبيعي)
/// - [true]: ضمن باقة (تُسجل كباقة بقيمة 0 ريال ولا تخصم من المكسب)
/// - [null]: إلغاء العملية
class AddonPackageDialog extends StatelessWidget {
  final String productName;
  final String subLabel;
  final double price;
  final IconData icon;

  const AddonPackageDialog({
    super.key,
    required this.productName,
    this.subLabel = '',
    required this.price,
    this.icon = Icons.fastfood_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final priceStr = price.toStringAsFixed(
      price.truncateToDouble() == price ? 0 : 2,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF131722),
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: const BorderSide(color: Color(0xFF222838), width: 1.2),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── رأس النافذة: أيقونة واسم الصنف ─────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontLg,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (subLabel.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF8A92A3), size: 20),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.spaceMd),
              const Divider(color: Color(0xFF202636), height: 1),
              const SizedBox(height: AppDimens.spaceMd),

              Text(
                'حدد نوع الإضافة لإدراجها في الفاتورة:',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB0B7C3),
                ),
              ),

              const SizedBox(height: AppDimens.spaceMd),

              // ── الخيار 1: إضافة عادية (مدفوعة) ───────────────────────────
              _OptionCard(
                title: 'إضافة عادية',
                subtitle: 'طلب إضافي مدفوع بالسعر الطبيعي',
                priceText: '$priceStr ر.س',
                badgeText: 'عادية',
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFF2DD4BF),
                bgColor: const Color(0xFF0F1E24),
                borderColor: const Color(0xFF1E3A3A),
                onTap: () => Navigator.of(context).pop(false),
              ),

              const SizedBox(height: AppDimens.spaceSm + 2),

              // ── الخيار 2: ضمن باقة (0 ريال) ──────────────────────────────
              _OptionCard(
                title: 'ضمن باقة',
                subtitle: 'مشمولة باشتراك العميل بسعر 0 ر.س (مثل الوجبات)',
                priceText: '0.00 ر.س',
                badgeText: 'باقة',
                icon: Icons.card_giftcard_rounded,
                accentColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFF26190B),
                borderColor: const Color(0xFFD97706).withValues(alpha: 0.6),
                onTap: () => Navigator.of(context).pop(true),
              ),

              const SizedBox(height: AppDimens.spaceLg),

              // ── زر الإلغاء ────────────────────────────────────────────────
              SizedBox(
                height: 40,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF8A92A3)),
                  label: Text(
                    'إلغاء الصنف',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontSm,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A92A3),
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

class _OptionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String priceText;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.bgColor.withValues(alpha: 0.95)
                : widget.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.accentColor
                  : widget.borderColor,
              width: _isHovered ? 1.8 : 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // ── أيقونة الخيار ──
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // ── النصوص ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontMd,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badgeText,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: const Color(0xFF8A92A3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── السعر ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.priceText,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontMd,
                      fontWeight: FontWeight.w800,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFF8A92A3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
