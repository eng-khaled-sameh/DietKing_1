/// نموذج بيانات الفاتورة — يجمع كل المعلومات اللازمة لتوليد PDF ومعاينة الفاتورة
class InvoiceData {
  final String companyName;       // "دايت كنج"
  final String branchName;        // من الجلسة الحالية، مثال "فرع الرياض"
  final String cashierName;       // من الجلسة الحالية
  final String orderNumber;       // رقم تسلسلي، مثال "#1042"
  final DateTime dateTime;
  final List<InvoiceLineItem> items;  // { name, quantity, unitPrice, totalPrice }
  final double subtotal;
  final double discountAmount;    // 0 افتراضيًا الآن
  // TODO: bind to real discount logic
  final double vatAmount;         // من نفس منطق order_totals_breakdown (15% مشمولة)
  final double grandTotal;

  const InvoiceData({
    required this.companyName,
    required this.branchName,
    required this.cashierName,
    required this.orderNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.grandTotal,
  });
}

/// سطر واحد في الفاتورة
class InvoiceLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}
