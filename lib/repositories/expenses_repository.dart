import 'package:uuid/uuid.dart';
import '../core/supabase_client.dart';
import '../core/local_db.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.clientId,
    required this.number,
    required this.category,
    required this.amount,
    required this.vatAmount,
    required this.total,
    required this.paymentMethod,
    required this.expenseDate,
    required this.createdAt,
    this.id,
    this.payee,
    this.description,
    this.notes,
    this.status = 'pending',
    this.decisionNotes,
  });

  final String? id;
  final String clientId;
  final String number;
  final String category;
  final double amount;
  final double vatAmount;
  final double total;
  final String paymentMethod;
  final DateTime expenseDate;
  final DateTime createdAt;
  final String? payee;
  final String? description;
  final String? notes;
  final String status;
  final String? decisionNotes;

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    double numberValue(dynamic value) => (value as num?)?.toDouble() ?? 0;
    DateTime dateValue(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

    final s = json['status']?.toString().toLowerCase();
    final branchId = json['branch_id']?.toString();
    final isBranch = branchId != null &&
        branchId.isNotEmpty &&
        json['branch_code'] != 'HQ' &&
        json['branch_name'] != 'الفرع الرئيسي';

    final String cleanStatus;
    if (isBranch) {
      if (s == 'approved') {
        cleanStatus = 'approved';
      } else if (s == 'rejected') {
        cleanStatus = 'rejected';
      } else {
        cleanStatus = 'pending';
      }
    } else {
      cleanStatus = (s == 'rejected') ? 'rejected' : 'approved';
    }

    return ExpenseRecord(
      id: json['id']?.toString(),
      clientId: json['client_id']?.toString() ?? '',
      number: json['number']?.toString() ?? json['invoice_number']?.toString() ?? '-',
      category: json['category']?.toString() ?? '-',
      amount: numberValue(json['amount']),
      vatAmount: numberValue(json['vat_amount']),
      total: numberValue(json['total']),
      paymentMethod: json['payment_method']?.toString() ?? 'other',
      expenseDate: dateValue(json['expense_date']),
      createdAt: dateValue(json['created_at']),
      payee: json['payee']?.toString(),
      description: json['description']?.toString(),
      notes: json['notes']?.toString(),
      status: cleanStatus,
      decisionNotes: json['decision_notes']?.toString() ?? json['reason']?.toString(),
    );
  }

  factory ExpenseRecord.fromLocalRecord(LocalRecord record) {
    final payload = record.payload;
    double numberValue(dynamic value) => (value as num?)?.toDouble() ?? 0;

    return ExpenseRecord(
      clientId: record.clientId,
      number: record.serverNumber ?? record.localNumber ?? '-',
      category: payload['category']?.toString() ?? '-',
      amount: numberValue(payload['amount']),
      vatAmount: numberValue(payload['vat_amount']),
      total:
          record.total ??
          numberValue(payload['amount']) + numberValue(payload['vat_amount']),
      paymentMethod: payload['payment_method']?.toString() ?? 'other',
      expenseDate:
          DateTime.tryParse(payload['expense_date']?.toString() ?? '') ??
          record.createdAt,
      createdAt: record.createdAt,
      payee: payload['payee']?.toString(),
      description: payload['description']?.toString(),
      notes: payload['notes']?.toString(),
      status: payload['status']?.toString() ?? 'pending',
      decisionNotes: payload['decision_notes']?.toString(),
    );
  }
}

class ExpensesRepository {
  /// جلب مصروفات الفرع مباشرة من السيرفر (Supabase)
  Future<List<ExpenseRecord>> getBranchExpenses(String branchId) async {
    // 1. المحاولة أولاً عبر قراءة جدول expense_invoices مباشرة للحصول على أحدث حالة
    try {
      final response = await supabase
          .from('expense_invoices')
          .select()
          .eq('branch_id', branchId)
          .order('created_at', ascending: false);

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(ExpenseRecord.fromJson)
          .toList();
      return rows;
    } catch (_) {
      // 2. إذا فشل، الاستعلام عبر RPC
      try {
        final response = await supabase.rpc(
          'get_branch_expenses',
          params: {'p_branch_id': branchId},
        );
        final rows = (response as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .map(ExpenseRecord.fromJson)
            .toList();
        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return rows;
      } catch (_) {
        return [];
      }
    }
  }

  /// تسجيل مصروف جديد مباشرة على السيرفر (Supabase) دون تخزين داخلي
  Future<Map<String, dynamic>> createExpense({
    required String branchId,
    required String? branchName,
    required String? branchCode,
    required String? sessionId,
    required String category,
    required double amount,
    required double vatAmount,
    required String paymentMethod,
    required DateTime expenseDate,
    String? payee,
    String? description,
    String? notes,
  }) async {
    final clientId = const Uuid().v4();
    final expenseDateStr =
        '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}';

    final effectiveSessionId =
        (sessionId != null && sessionId.trim().isNotEmpty)
            ? sessionId.trim()
            : const Uuid().v4();

    final payload = {
      'client_id': clientId,
      'branch_id': branchId,
      'session_id': effectiveSessionId,
      'category': category.trim(),
      'payee': (payee != null && payee.trim().isNotEmpty) ? payee.trim() : null,
      'description': (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'vat_amount': double.parse(vatAmount.toStringAsFixed(2)),
      'payment_method': paymentMethod == 'نقدي' ? 'cash' : 'other',
      'expense_date': expenseDateStr,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'status': 'pending',
    };

    // 1. استدعاء الدالة المباشرة create_expense في Supabase
    try {
      final res = await supabase.rpc('create_expense', params: {'p': payload});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'ok': true, 'data': res};
    } catch (rpcErr) {
      // 2. كاحتياط مباشر عند عدم توفر الدالة: الإدراج المباشر في expense_invoices
      final user = supabase.auth.currentUser;
      final total = amount + vatAmount;

      String invoiceNumber =
          'EXP-${(branchCode != null && branchCode.isNotEmpty) ? branchCode : 'BR'}-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      try {
        final counterRes = await supabase
            .from('branch_expense_counters')
            .select('last_number')
            .eq('branch_id', branchId)
            .maybeSingle();
        final currentNum = (counterRes?['last_number'] as num?)?.toInt() ?? 0;
        final nextNum = currentNum + 1;
        await supabase.from('branch_expense_counters').upsert({
          'branch_id': branchId,
          'last_number': nextNum,
        });
        invoiceNumber =
            'EXP-${(branchCode != null && branchCode.isNotEmpty) ? branchCode : 'BR'}-${nextNum.toString().padLeft(6, '0')}';
      } catch (_) {}

      final insertData = {
        'client_id': clientId,
        'invoice_number': invoiceNumber,
        'branch_id': branchId,
        'branch_name': branchName,
        'branch_code': branchCode,
        'cashier_id': user?.id,
        'cashier_name': user?.email?.split('@').first,
        'session_id': effectiveSessionId,
        'category': category.trim(),
        'payee':
            (payee != null && payee.trim().isNotEmpty) ? payee.trim() : null,
        'description': (description != null && description.trim().isNotEmpty)
            ? description.trim()
            : null,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'vat_amount': double.parse(vatAmount.toStringAsFixed(2)),
        'total': double.parse(total.toStringAsFixed(2)),
        'payment_method': paymentMethod == 'نقدي' ? 'cash' : 'other',
        'expense_date': expenseDateStr,
        'notes':
            (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
        'status': 'pending',
      };

      Map<String, dynamic> inserted;
      try {
        final res = await supabase
            .from('expense_invoices')
            .insert(insertData)
            .select()
            .single();
        inserted = Map<String, dynamic>.from(res);
      } catch (insertErr) {
        if (insertErr.toString().contains('status')) {
          final fallbackData = Map<String, dynamic>.from(insertData)
            ..remove('status');
          final res = await supabase
              .from('expense_invoices')
              .insert(fallbackData)
              .select()
              .single();
          inserted = Map<String, dynamic>.from(res);
        } else {
          // إذا فشل الإدراج أيضاً، نرمي خطأ RPC لأنه الأوضح والأكثر دقة
          throw rpcErr;
        }
      }

      // إشعار فوري لقسم الحسابات
      try {
        await supabase.from('notifications').insert({
          'recipient_role': 'accountant',
          'type': 'expense_submitted',
          'title': 'مصروف جديد قيد المراجعة',
          'body':
              'سجّل فرع ${branchName ?? 'الفرع'} مصروفاً بقيمة ${total.toStringAsFixed(2)} ر.س بانتظار الاعتماد.',
          'ref_table': 'expense_invoices',
          'ref_id': inserted['id']?.toString() ?? clientId,
        });
      } catch (_) {}

      return Map<String, dynamic>.from(inserted);
    }
  }
}
