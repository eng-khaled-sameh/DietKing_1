import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../models/audit_row.dart';

class AuditRowTile extends StatefulWidget {
  final AuditRow row;

  const AuditRowTile({super.key, required this.row});

  @override
  State<AuditRowTile> createState() => _AuditRowTileState();
}

class _AuditRowTileState extends State<AuditRowTile> {
  late TextEditingController _actualQtyController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _actualQtyController = TextEditingController(text: widget.row.actualQty.toString());
    _noteController = TextEditingController(text: widget.row.note);
  }

  @override
  void didUpdateWidget(covariant AuditRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.actualQty != widget.row.actualQty) {
      _actualQtyController.text = widget.row.actualQty.toString();
    }
    if (oldWidget.row.note != widget.row.note) {
      _noteController.text = widget.row.note;
    }
  }

  @override
  void dispose() {
    _actualQtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onActualQtyChanged(String val) {
    final qty = double.tryParse(val) ?? 0;
    context.read<InventoryCubit>().setAuditActual(widget.row.sku, qty);
  }

  void _onNoteChanged(String val) {
    context.read<InventoryCubit>().setAuditNote(widget.row.sku, val);
  }

  @override
  Widget build(BuildContext context) {
    final difference = widget.row.difference;
    final isMatch = difference == 0;
    final statusColor = isMatch ? AppColors.statusGreen : AppColors.statusRed;
    final statusText = isMatch ? 'مطابق' : 'يوجد فارق';

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              widget.row.sku,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              widget.row.name,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${widget.row.systemQty} ${widget.row.unit}',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _actualQtyController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: _onActualQtyChanged,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${difference > 0 ? '+' : ''}$difference ${widget.row.unit}',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isMatch ? AppColors.onSurfaceVariant : AppColors.statusRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.ibmPlexSansArabic(color: statusColor, fontSize: 12),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _noteController,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: const InputDecoration(
                hintText: 'ملاحظات الجرد...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: _onNoteChanged,
            ),
          ),
        ],
      ),
    );
  }
}
