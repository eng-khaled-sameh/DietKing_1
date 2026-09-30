import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubits/cart_cubit.dart';

/// تفصيل مجاميع الطلب — يقرأ مباشرة من [CartCubit] عبر [BlocBuilder]
/// إضافة إمكانية إدخال خصم أو ضريبة يدوياً.
class OrderTotalsBreakdown extends StatelessWidget {
  const OrderTotalsBreakdown({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final subtotal = state.subtotal;
        final discountAmount = state.discountAmount;
        final vatAmount = state.vatAmount;
        final grandTotal = state.grandTotal;
        final totalItems = state.totalItems;

        return Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              // ── المجموع الفرعي ─────────────────────────────────────────────
              _buildRow(
                label: 'المجموع الفرعي',
                value: '${subtotal.toStringAsFixed(2)} ر.س',
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // ── الخصم ──────────────────────────────────────────────────────
              _buildClickableRow(
                context,
                label: 'الخصم',
                value: discountAmount > 0
                    ? '-${discountAmount.toStringAsFixed(2)} ر.س'
                    : 'إضافة خصم',
                isAction: true,
                isNegative: discountAmount > 0,
                onTap: () => _showDiscountDialog(context, state),
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // ── ضريبة القيمة المضافة ───────────────────────────────────────
              _buildClickableRow(
                context,
                label: 'القيمة المضافة',
                value: vatAmount > 0
                    ? '+${vatAmount.toStringAsFixed(2)} ر.س'
                    : 'إضافة ضريبة',
                isAction: true,
                onTap: () => _showVatDialog(context, state),
              ),

              const SizedBox(height: AppDimens.spaceSm + 2),

              const Divider(height: 1, color: Color(0x26FFFFFF)),

              const SizedBox(height: AppDimens.spaceSm + 2),

              // ── الإجمالي النهائي المميز ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm + 2,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryContainer.withValues(alpha: 0.15),
                      AppColors.primaryContainer.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإجمالي النهائي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontMd,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalItems ${totalItems == 1 ? 'صنف' : 'أصناف'} في الطلب',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          grandTotal.toStringAsFixed(2),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXxl + 2,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ر.س',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontSm,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    bool isMuted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: isMuted
                ? AppColors.onSurfaceVariant.withValues(alpha: 0.8)
                : AppColors.onSurface,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm + 1,
            fontWeight: isMuted ? FontWeight.w500 : FontWeight.w700,
            color: isMuted ? AppColors.onSurfaceVariant : AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildClickableRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isAction = false,
    bool isNegative = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontSm,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: isAction
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                    : EdgeInsets.zero,
                decoration: isAction
                    ? BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      )
                    : null,
                child: Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w700,
                    color: isNegative ? Colors.redAccent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, CartState state) {
    _showValueDialog(
      context: context,
      title: 'إضافة خصم',
      initialValue: state.discountValue,
      initialIsPercentage: state.isDiscountPercentage,
      onSave: (val, isPerc) {
        context.read<CartCubit>().setDiscount(val, isPercentage: isPerc);
      },
    );
  }

  void _showVatDialog(BuildContext context, CartState state) {
    _showValueDialog(
      context: context,
      title: 'إضافة ضريبة',
      initialValue: state.vatValue,
      initialIsPercentage: state.isVatPercentage,
      onSave: (val, isPerc) {
        context.read<CartCubit>().setVat(val, isPercentage: isPerc);
      },
    );
  }

  void _showValueDialog({
    required BuildContext context,
    required String title,
    required double initialValue,
    required bool initialIsPercentage,
    required Function(double value, bool isPercentage) onSave,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return _ValueDialog(
          title: title,
          initialValue: initialValue,
          initialIsPercentage: initialIsPercentage,
          onSave: onSave,
        );
      },
    );
  }
}

class _ValueDialog extends StatefulWidget {
  final String title;
  final double initialValue;
  final bool initialIsPercentage;
  final Function(double, bool) onSave;

  const _ValueDialog({
    required this.title,
    required this.initialValue,
    required this.initialIsPercentage,
    required this.onSave,
  });

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late TextEditingController _controller;
  late bool _isPercentage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toString() : '',
    );
    _isPercentage = widget.initialIsPercentage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text(
          widget.title,
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(
                      'نسبة (%)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                      ),
                    ),
                    value: true,
                    groupValue: _isPercentage,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isPercentage = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(
                      'مبلغ (ر.س)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                      ),
                    ),
                    value: false,
                    groupValue: _isPercentage,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isPercentage = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: InputDecoration(
                labelText: 'القيمة',
                labelStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_controller.text) ?? 0.0;
              widget.onSave(val, _isPercentage);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
