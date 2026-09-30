import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../../core/models/invoice_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../services/invoice_pdf_builder.dart';

// TODO: حفظ نسخة من الفاتورة في قاعدة البيانات (Supabase) بعد إتمام الطباعة، لأغراض السجلات والتقارير لاحقًا.

/// Dialog معاينة الفاتورة — يعرض معاينة مرئية (Flutter Widget) لبيانات الفاتورة
/// مع زر "تم الدفع" لطباعة PDF فعليًا وزر "رجوع" للإلغاء.
class InvoicePreviewDialog extends StatefulWidget {
  final InvoiceData invoiceData;
  final VoidCallback onPaymentComplete;

  const InvoicePreviewDialog({
    super.key,
    required this.invoiceData,
    required this.onPaymentComplete,
  });

  @override
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  bool _isPrinting = false;

  Future<void> _handlePayment(String paymentMethod) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      // تحديث بيانات الفاتورة بطريقة الدفع المختارة
      final invoiceToPrint = widget.invoiceData.copyWith(paymentMethod: paymentMethod);

      // 1. بناء PDF
      final pdfBytes = await buildInvoicePdf(invoiceToPrint);

      // 2. طباعة فعلية عبر نافذة الطابعة في نظام التشغيل
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'DietKing_Invoice_${DateTime.now().millisecondsSinceEpoch}',
      );

      // 3. إغلاق Dialog + تفريغ السلة + Snackbar
      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الطباعة: $e', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.invoiceData;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceMd,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryContainer.withValues(alpha: 0.15),
                      AppColors.surfaceContainerLow,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimens.radiusLg),
                    topRight: Radius.circular(AppDimens.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Text(
                        'معاينة الفاتورة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontLg,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // ── محتوى الفاتورة المرئي ─────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── اسم الشركة + الفرع ────────────────────────────────
                        Center(
                          child: Text(
                            data.companyName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXxl,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            data.branchName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── خط فاصل ───────────────────────────────────────────
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── معلومات الطلب ─────────────────────────────────────
                        _buildInfoRow('رقم الطلب', data.orderNumber),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          'التاريخ',
                          '${data.dateTime.year}-${data.dateTime.month.toString().padLeft(2, '0')}-${data.dateTime.day.toString().padLeft(2, '0')}  ${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow('الكاشير', data.cashierName),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── خط فاصل ───────────────────────────────────────────
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── عناوين جدول الأصناف ───────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'الصنف',
                                style: _headerStyle(),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'الكمية',
                                style: _headerStyle(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'السعر',
                                style: _headerStyle(),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الإجمالي',
                                style: _headerStyle(),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 6),

                        // ── أسطر الأصناف ──────────────────────────────────────
                        ...data.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      item.name,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: AppDimens.fontSm,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.quantity}',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: AppDimens.fontSm,
                                        color: AppColors.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.unitPrice.toStringAsFixed(2),
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: AppDimens.fontSm,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.totalPrice.toStringAsFixed(2),
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: AppDimens.fontSm,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                            )),

                        const SizedBox(height: AppDimens.spaceSm),
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── المجموع الفرعي ────────────────────────────────────
                        _buildTotalRow('المجموع الفرعي', data.subtotal),
                        const SizedBox(height: 4),

                        // ── الخصم (يُعرض دائمًا) ─────────────────────────────
                        _buildTotalRow('الخصم', data.discountAmount, isNegative: true),
                        const SizedBox(height: 4),

                        // ── ضريبة القيمة المضافة ──────────────────────────────
                        _buildTotalRow('ضريبة القيمة المضافة:', data.vatAmount),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── خط فاصل + الإجمالي النهائي ────────────────────────
                        Divider(
                          height: 1,
                          color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceSm,
                            vertical: AppDimens.spaceSm,
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
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الإجمالي النهائي',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontMd + 1,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                '${data.grandTotal.toStringAsFixed(2)} ر.س',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXl,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.spaceMd),
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),
                        Center(
                          child: Text(
                            'شكرًا لزيارتكم - دايت كنج',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            'دايت كينج شريكك الصحي',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── أزرار الإجراءات ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceMd,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppDimens.radiusLg),
                    bottomRight: Radius.circular(AppDimens.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    // ── زر رجوع / إلغاء ────────────────────────────────────────
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(
                            'رجوع',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontMd,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onSurfaceVariant,
                            backgroundColor: AppColors.surfaceContainer,
                            side: BorderSide(
                              color: AppColors.outlineVariant.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppDimens.spaceMd),

                    // ── زر كاش ─────────────────────────────────────────────
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : () => _handlePayment('كاش'),
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.payments_outlined, size: 20),
                          label: Text(
                            'كاش',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontMd + 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),

                    // ── زر فيزا ─────────────────────────────────────────────
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : () => _handlePayment('فيزا'),
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.credit_card_rounded, size: 20),
                          label: Text(
                            'فيزا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontMd + 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  TextStyle _headerStyle() => GoogleFonts.ibmPlexSansArabic(
        fontSize: AppDimens.fontXs,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
      );

  Widget _buildDivider() => Container(
        height: 1,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.25),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
        ),
      );

  Widget _buildInfoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      );

  Widget _buildTotalRow(String label, double amount, {bool isNegative = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              color: AppColors.onSurface,
            ),
          ),
          Text(
            '${isNegative && amount > 0 ? '-' : ''}${amount.toStringAsFixed(2)} ر.س',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              fontWeight: FontWeight.w600,
              color: isNegative && amount > 0
                  ? Colors.redAccent
                  : AppColors.onSurface,
            ),
          ),
        ],
      );
}
