import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../models/branch_order.dart';

class BranchItemRow extends StatefulWidget {
  final String orderId;
  final BranchOrderItem item;
  final bool isDispatched;

  const BranchItemRow({
    super.key,
    required this.orderId,
    required this.item,
    required this.isDispatched,
  });

  @override
  State<BranchItemRow> createState() => _BranchItemRowState();
}

class _BranchItemRowState extends State<BranchItemRow> {
  late TextEditingController _issuedController;

  @override
  void initState() {
    super.initState();
    _issuedController = TextEditingController(text: widget.item.issued.toString());
  }

  @override
  void didUpdateWidget(covariant BranchItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.issued != widget.item.issued) {
      _issuedController.text = widget.item.issued.toString();
    }
  }

  @override
  void dispose() {
    _issuedController.dispose();
    super.dispose();
  }

  void _onIssuedChanged(String val) {
    final qty = int.tryParse(val) ?? 0;
    context.read<InventoryCubit>().setIssuedQuantity(widget.orderId, widget.item.id, qty);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              widget.item.name,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'المطلوب: ${widget.item.requested}',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _issuedController,
              keyboardType: TextInputType.number,
              enabled: !widget.item.unavailable && !widget.isDispatched,
              style: GoogleFonts.ibmPlexSansArabic(
                color: widget.item.unavailable ? AppColors.onSurfaceVariant : AppColors.onSurface,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceContainerHigh)),
              ),
              onChanged: _onIssuedChanged,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Checkbox(
                value: widget.item.unavailable,
                onChanged: widget.isDispatched
                    ? null
                    : (val) {
                        cubit.setItemUnavailable(widget.orderId, widget.item.id, val ?? false);
                      },
                activeColor: AppColors.primary,
                checkColor: AppColors.onPrimary,
              ),
              Text(
                'غير متوفر',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: widget.item.unavailable ? AppColors.error : AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
