import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cubits/held_orders_cubit.dart';
import '../../../../core/models/held_order.dart';
import '../../../../core/models/invoice_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_status_footer.dart';
import '../cubits/cart_cubit.dart';
import '../mock_data/mock_meal_catalog.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/meal_sales_app_bar.dart';
import '../widgets/order_summary_panel.dart';
import '../widgets/protein_matrix_table.dart';
import '../widgets/quick_addon_card.dart';
import '../widgets/section_header.dart';

/// الشاشة الرئيسية للبيع بالوجبة (Meal Sales) — دايت كنج POS
class MealSalesScreen extends StatefulWidget {
  final List<CartLine>? initialCartLines;

  const MealSalesScreen({
    super.key,
    this.initialCartLines,
  });

  @override
  State<MealSalesScreen> createState() => _MealSalesScreenState();
}

class _MealSalesScreenState extends State<MealSalesScreen> {
  late CartCubit _cartCubit;
  final FocusNode _focusNode = FocusNode();

  /// عدّاد تسلسلي بسيط لرقم الطلب (في الذاكرة فقط)
  static int _orderCounter = 1000;

  @override
  void initState() {
    super.initState();
    _cartCubit = CartCubit();
    if (widget.initialCartLines != null) {
      _cartCubit.restoreCart(widget.initialCartLines!);
    }
  }

  @override
  void dispose() {
    _cartCubit.close();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleHoldOrder() {
    final state = _cartCubit.state;
    if (state.lines.isEmpty) return;

    final summaryLabel = state.lines.length <= 2
        ? state.lines.map((l) => l.name).join(' + ')
        : '${state.lines[0].name} + ${state.lines[1].name} و ${state.lines.length - 2} أخرى';

    final order = HeldOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: HeldOrderSource.mealSale,
      heldAt: DateTime.now(),
      summaryLabel: summaryLabel,
      totalAmount: state.grandTotal,
      payload: List<CartLine>.from(state.lines),
    );

    context.read<HeldOrdersCubit>().holdOrder(order);
    _cartCubit.clearAll();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعليق الطلب بنجاح', textAlign: TextAlign.right),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// يبني [InvoiceData] من الحالة الحالية لـ [CartCubit] ويفتح Dialog المعاينة
  void _handleCheckout() {
    final state = _cartCubit.state;

    // لو السلة فارغة، اعرض Snackbar ولا تفتح Dialog
    if (state.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلب لإتمامه', textAlign: TextAlign.right),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // بناء رقم الطلب التسلسلي
    _orderCounter++;
    final orderNumber = '#$_orderCounter';

    // تحويل CartLine → InvoiceLineItem
    final invoiceItems = state.lines
        .map((line) => InvoiceLineItem(
              name: line.variantLabel.isNotEmpty
                  ? '${line.name} (${line.variantLabel})'
                  : line.name,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              totalPrice: line.lineTotal,
            ))
        .toList();

    // TODO: bind to real session — حاليًا بيانات ثابتة
    final invoiceData = InvoiceData(
      companyName: 'دايت كنج',
      branchName: 'فرع الرياض',
      cashierName: 'كاشير 1',
      orderNumber: orderNumber,
      dateTime: DateTime.now(),
      items: invoiceItems,
      subtotal: state.subtotal,
      discountAmount: state.discountAmount,
      vatAmount: state.vatAmount,
      grandTotal: state.grandTotal,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoicePreviewDialog(
        invoiceData: invoiceData,
        onPaymentComplete: () {
          _cartCubit.clearAll();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الدفع وطباعة الفاتورة بنجاح', textAlign: TextAlign.right),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cartCubit,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            // تجنب تعارض الاختصارات مع أي TextField مفتوح
            final primaryFocus = FocusManager.instance.primaryFocus;
            final isTextFieldFocused = primaryFocus?.context?.widget is EditableText;

            if (event.logicalKey == LogicalKeyboardKey.f4) {
              _handleHoldOrder();
            } else if (event.logicalKey == LogicalKeyboardKey.escape && !isTextFieldFocused) {
              _cartCubit.clearAll();
            } else if ((event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                !isTextFieldFocused) {
              _handleCheckout();
            }
          }
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _MealSalesBody(
            onCheckout: _handleCheckout,
          ),
        ),
      ),
    );
  }
}

class _MealSalesBody extends StatelessWidget {
  final VoidCallback onCheckout;
  
  const _MealSalesBody({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── 1. الهيدر ──────────────────────────────────────────────────────
          const MealSalesAppBar(),

          // ── 2. محتوى الكاتالوج والطلب (عمودان) ────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── عمود الكاتالوج (8/12) ──────────────────────────────────
                  Expanded(
                    flex: 8,
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.only(left: AppDimens.spaceSm),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── عنوان قسم البروتين ───────────────────────────
                          const SectionHeader(
                            title: 'أصناف البروتين الرئيسية',
                            subtitle:
                                'اختر نوع البروتين والوزن لإضافته للفاتورة مباشرة',
                            icon: Icons.fitness_center_rounded,
                            badgeLabel: '3 أنواع × 5 أوزان',
                          ),

                          const SizedBox(height: AppDimens.spaceMd),

                          // ── جدول مصفوفة البروتين ─────────────────────────
                          const ProteinMatrixTable(),

                          const SizedBox(height: AppDimens.spaceXl),

                          // ── عنوان قسم الإضافات ───────────────────────────
                          const SectionHeader(
                            title: 'إضافات سريعة وسناكات ومشروبات',
                            subtitle:
                                'سندوتشات دايت، سلطات خضراء، ومشروبات بدون سكر',
                            icon: Icons.fastfood_rounded,
                            badgeLabel: '6 أصناف متوفرة',
                          ),

                          const SizedBox(height: AppDimens.spaceMd),

                          // ── شبكة بطاقات الإضافات (3 أعمدة) ─────────────
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: AppDimens.spaceSm,
                              crossAxisSpacing: AppDimens.spaceSm,
                              mainAxisExtent: 52, // طول ثابت على قد المحتوى
                            ),
                            itemCount: mockAddonItems.length,
                            itemBuilder: (context, index) {
                              final addon = mockAddonItems[index];
                              return QuickAddonCard(
                                label: addon.label,
                                subLabel: addon.subLabel,
                                price: addon.price.toDouble(),
                                icon: addon.icon,
                                onTap: () {
                                  context.read<CartCubit>().addItem(
                                        name: addon.label,
                                        variantLabel: 'إضافة',
                                        unitPrice: addon.price.toDouble(),
                                      );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: AppDimens.spaceMd),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: AppDimens.spaceLg),

                  // ── عمود ملخص الطلب الجانبي الثابت (4/12) ─────────────────
                  Expanded(
                    flex: 4,
                    child: OrderSummaryPanel(
                      onCheckout: onCheckout,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. فوتر حالة الأجهزة ──────────────────────────────────────────
          const PosStatusFooter(),
        ],
      ),
    );
  }
}
