import 'package:uuid/uuid.dart';
import 'package:my_desktop_app/core/supabase_client.dart';
import 'package:my_desktop_app/core/local_db.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AccountingRepository — كل استدعاءات Supabase RPC لقسم الحسابات
// يُطابق 025_accounting_rpcs_v2.sql
// ══════════════════════════════════════════════════════════════════════════════

class AccountingRepository {
  // ── المبيعات ────────────────────────────────────────────────────────────────

  /// ملخص المبيعات (إيرادات + مصروفات + مبيعات نقدية/بطاقة)
  Future<Map<String, dynamic>> getSalesSummary({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    Map<String, dynamic> summary = {};
    try {
      final result = await supabase.rpc('acc_get_sales_summary', params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_branch_id': ?branchId,
      });
      if (result is Map) {
        summary = Map<String, dynamic>.from(result);
      }
    } catch (_) {}

    // التحقق المباشر من المصروفات المعتمدة (approved/posted) في جدول expense_invoices
    // لضمان دقة إجمالي المصروفات في لوحة التحكم حتى لو كانت دالة SQL السابقة تحسب فقط 'posted'
    final rpcExpenses = (summary['total_expenses'] as num?)?.toDouble() ?? 0.0;
    if (rpcExpenses == 0.0) {
      try {
        final fromDate = from.toIso8601String().split('T').first;
        final toDate   = to.toIso8601String().split('T').first;
        var query = supabase
            .from('expense_invoices')
            .select('total, payment_method, status')
            .gte('expense_date', fromDate)
            .lte('expense_date', toDate)
            .inFilter('status', ['approved', 'posted']);

        if (branchId != null && branchId.isNotEmpty && branchId != 'HQ') {
          query = query.eq('branch_id', branchId);
        } else if (branchId == 'HQ') {
          query = query.isFilter('branch_id', null);
        }

        final rows = await query;
        double calcTotal = 0.0;
        double calcCash = 0.0;
        for (final row in (rows as List? ?? [])) {
          final t = (row['total'] as num?)?.toDouble() ?? 0.0;
          calcTotal += t;
          if (row['payment_method'] == 'cash') {
            calcCash += t;
          }
        }

        if (calcTotal > 0 || summary.isEmpty) {
          summary['total_expenses'] = calcTotal;
          summary['cash_expenses'] = calcCash;
          final totalSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
          summary['net_revenue'] = totalSales - calcTotal;
        }
      } catch (_) {}
    }

    return summary;
  }

  /// تفاصيل الفواتير — keyset pagination
  Future<Map<String, dynamic>> getSalesDetail({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_sales_detail', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  // ── الإقفالات ───────────────────────────────────────────────────────────────

  /// إقفالات لعرض الـ Dashboard (آخر 20، بدون pagination)
  Future<List<Map<String, dynamic>>> getClosingsForDashboard({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await supabase.rpc('acc_get_closings_dashboard', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// قائمة الإقفالات الكاملة — keyset pagination
  Future<Map<String, dynamic>> getClosings({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_closings', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// تسجيل مراجعة إقفال
  Future<Map<String, dynamic>> reviewClosing({
    required String closingId,
    required double reviewedDifference,
    String? reviewReason,
    String? accountantNotes,
  }) async {
    final result = await supabase.rpc('acc_review_closing', params: {
      'p_closing_id': closingId,
      'p_reviewed_difference': reviewedDifference,
      'p_review_reason': ?reviewReason,
      'p_accountant_notes': ?accountantNotes,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// إحالة العجز إلى HR
  Future<Map<String, dynamic>> referClosingToHr({
    required String closingId,
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    final result = await supabase.rpc('acc_refer_closing_to_hr', params: {
      'p_closing_id': closingId,
      'p_employee_id': employeeId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// إلغاء عجز إقفال وردية وتصفيره وإلغاء طلب الخصم إذا كان معلقاً
  Future<Map<String, dynamic>> cancelClosingShortage({
    required String closingId,
    String? reason,
  }) async {
    final result = await supabase.rpc('acc_cancel_closing_shortage', params: {
      'p_closing_id': closingId,
      'p_reason': ?reason,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── المصروفات ───────────────────────────────────────────────────────────────

  /// كل المصروفات — keyset pagination مع دعم الفرع الرئيسي HQ والاستعلام الاحتياطي
  Future<Map<String, dynamic>> getAllExpenses({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final isHq  = branchId == 'HQ';
    final isAll = branchId == null; // كل الفروع (بدون فلتر)

    // 1. محاولة استدعاء دالة acc_get_all_expenses
    try {
      final result = await supabase.rpc('acc_get_all_expenses', params: {
        'p_from'      : from.toUtc().toIso8601String(),
        'p_to'        : to.toUtc().toIso8601String(),
        'p_branch_id' : isHq || isAll ? null : branchId,
        'p_limit'     : limit,
        'p_cursor_ts' : cursorTs,
        'p_cursor_id' : cursorId,
        'p_hq_only'   : isHq,
      });
      final map = (result as Map<String, dynamic>?) ?? {};
      final items = (map['items'] as List? ?? []);
      if (items.isNotEmpty || !isHq) {
        return map;
      }
    } catch (_) {
      // محاولة استدعاء بدون p_hq_only إذا كانت النسخة القديمة
      if (!isHq) {
        try {
          final result = await supabase.rpc('acc_get_all_expenses', params: {
            'p_from'      : from.toUtc().toIso8601String(),
            'p_to'        : to.toUtc().toIso8601String(),
            'p_branch_id' : isAll ? null : branchId,
            'p_limit'     : limit,
            'p_cursor_ts' : cursorTs,
            'p_cursor_id' : cursorId,
          });
          final map = (result as Map<String, dynamic>?) ?? {};
          return map;
        } catch (_) {}
      }
    }

    // 2. Fallback مضمون ومباشر من جدول expense_invoices
    try {
      final fromDate = from.toIso8601String().split('T').first;
      final toDate   = to.toIso8601String().split('T').first;
      var query = supabase
          .from('expense_invoices')
          .select()
          .gte('expense_date', fromDate)
          .lte('expense_date', toDate);

      if (isHq) {
        // الفرع الرئيسي: سجلات بدون branch_id
        query = query.isFilter('branch_id', null);
      } else if (!isAll) {
        query = query.eq('branch_id', branchId);
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      final items = List<Map<String, dynamic>>.from(res as List? ?? []);

      // بناء summary دقيق للمصروفات في حالة الـ fallback
      double totApproved = 0.0;
      int pendingCnt = 0;
      int approvedCnt = 0;
      int rejectedCnt = 0;
      final byCat = <String, double>{};

      for (final it in items) {
        final st = (it['status'] as String? ?? 'pending').toLowerCase();
        final tot = (it['total'] as num?)?.toDouble() ?? 0.0;
        final cat = (it['category'] as String?)?.trim() ?? 'أخرى';
        if (st == 'approved' || st == 'posted') {
          totApproved += tot;
          approvedCnt++;
          byCat[cat] = (byCat[cat] ?? 0) + tot;
        } else if (st == 'rejected') {
          rejectedCnt++;
        } else {
          pendingCnt++;
        }
      }

      return {
        'summary': {
          'total_amount': totApproved,
          'count': items.length,
          'pending_count': pendingCnt,
          'approved_count': approvedCnt,
          'rejected_count': rejectedCnt,
          'by_category': byCat,
        },
        'items': items,
        'limit': limit,
      };
    } catch (_) {
      return {'summary': {}, 'items': [], 'limit': limit};
    }
  }


  /// إضافة مصروف جديد من المحاسب (مع تحديد الفرع أو كفرع رئيسي HQ)
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final isHq = payload['branch_id'] == null ||
        payload['branch_id'] == 'HQ' ||
        payload['branch_id'] == '';

    // توليد UUID صحيح دائماً لـ client_id
    final clientId = (payload['client_id'] != null && payload['client_id'].toString().length > 10)
        ? payload['client_id'].toString()
        : const Uuid().v4();
    payload['client_id'] = clientId;

    // تحويل المبالغ إلى double مضموناً
    final double amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final double vat    = (payload['vat_amount'] as num?)?.toDouble() ?? 0.0;

    if (amount <= 0) {
      throw Exception('قيمة المصروف يجب أن تكون أكبر من الصفر');
    }

    if (isHq) {
      payload['branch_id'] = null;
      payload['status'] = 'approved';
    } else {
      payload['status'] = 'pending';
    }

    // تعيين القيم الرقمية الصحيحة
    payload['amount']     = amount;
    payload['vat_amount'] = vat;

    // 1. محاولة عبر الـ RPC
    try {
      final result = await supabase.rpc('create_expense', params: {
        'p': payload,
      });
      return (result as Map<String, dynamic>?) ?? {};
    } catch (rpcError) {
      // 2. Fallback مباشر لجدول expense_invoices
      try {
        final uid   = supabase.auth.currentUser?.id;
        final email = supabase.auth.currentUser?.email ?? '';
        final now   = DateTime.now();
        final ts    = now.millisecondsSinceEpoch.toString();
        final invoiceNum = isHq
            ? 'EXP-HQ-${ts.substring(ts.length - 6)}'
            : 'EXP-BR-${ts.substring(ts.length - 6)}';

        final branchId   = isHq ? null : (payload['branch_id'] as String?);
        final branchName = isHq
            ? 'الفرع الرئيسي'
            : (payload['branch_name'] as String? ?? 'فرع');
        final branchCode = isHq ? 'HQ' : 'BR';

        final insertData = <String, dynamic>{
          'client_id'      : clientId,
          'invoice_number' : invoiceNum,
          'branch_id'      : branchId,
          'branch_name'    : branchName,
          'branch_code'    : branchCode,
          'cashier_id'     : uid,
          'cashier_name'   : email.split('@').first,
          'category'       : (payload['category'] as String?)?.trim() ?? 'أخرى',
          'payee'          : payload['payee'],
          'description'    : payload['description'],
          'amount'         : amount,
          'vat_amount'     : vat,
          'total'          : amount + vat,
          'payment_method' : payload['payment_method'] ?? 'cash',
          'expense_date'   : payload['expense_date'] ??
              now.toIso8601String().split('T').first,
          'notes'          : payload['notes'],
          'status'         : isHq ? 'approved' : 'pending',
        };

        final inserted = await supabase
            .from('expense_invoices')
            .insert(insertData)
            .select()
            .maybeSingle();

        return inserted ?? {'invoice_number': invoiceNum};
      } catch (insertError) {
        throw Exception(
          'فشل حفظ المصروف: $insertError',
        );
      }
    }
  }

  /// اعتماد أو رفض مصروف من المحاسب مع إشعار الفرع
  Future<Map<String, dynamic>> decideExpense({
    required String expenseId,
    required String status, // 'approved' | 'rejected'
    String? reason,
    String? branchId,
    String? invoiceNumber,
    double? total,
  }) async {
    bool updated = false;
    Object? lastError;

    // 1. تجربة الـ RPC المخصص
    try {
      final result = await supabase.rpc('acc_decide_expense', params: {
        'p_expense_id': expenseId,
        'p_status': status,
        'p_notes': reason,
      });
      // التحقق من أن RPC أعاد نتيجة ناجحة
      if (result != null) {
        updated = true;
      }
    } catch (e) {
      lastError = e;
      // 2. fallback: تحديث مباشر في جدول expense_invoices عبر id أو client_id
      try {
        final updatePayload = {
          'status': status,
          'decided_at': DateTime.now().toUtc().toIso8601String(),
          'decided_by': supabase.auth.currentUser?.id,
          if (reason != null && reason.isNotEmpty) 'decision_notes': reason,
        };

        // محاولة بالـ id أولاً
        final res = await supabase
            .from('expense_invoices')
            .update(updatePayload)
            .eq('id', expenseId)
            .select('id')
            .maybeSingle();

        if (res != null) {
          updated = true;
        } else {
          // محاولة بـ client_id كـ fallback ثانٍ
          final res2 = await supabase
              .from('expense_invoices')
              .update(updatePayload)
              .eq('client_id', expenseId)
              .select('id')
              .maybeSingle();
          if (res2 != null) updated = true;
        }
      } catch (e2) {
        lastError = e2;
      }
    }

    if (!updated) {
      throw Exception('فشل تحديث حالة المصروف: $lastError');
    }

    // 3. إرسال إشعار للكاشير في الفرع (اختياري، لا يوقف العملية)
    if (branchId != null && branchId.isNotEmpty) {
      try {
        await supabase.from('notifications').insert({
          'recipient_role': 'cashier',
          'recipient_branch_id': branchId,
          'type': status == 'approved' ? 'expense_approved' : 'expense_rejected',
          'title': status == 'approved' ? 'تم اعتماد المصروف' : 'تم رفض المصروف',
          'body': status == 'approved'
              ? 'تم اعتماد فاتورة المصروف رقم ${invoiceNumber ?? ''} بقيمة ${total?.toStringAsFixed(2) ?? ''} ر.س من قسم الحسابات.'
              : 'تم رفض فاتورة المصروف رقم ${invoiceNumber ?? ''} من قسم الحسابات${reason != null && reason.isNotEmpty ? " — السبب: $reason" : ""}.',
          'ref_table': 'expense_invoices',
          'ref_id': expenseId,
        });
      } catch (_) {}
    }

    return {'ok': updated, 'status': status};
  }

  /// حذف جميع المصروفات التجريبية
  Future<int> clearAllTestExpenses() async {
    // مسح السجلات المحلية في الجهاز
    try {
      await LocalRecordsRepository().clearExpenses();
    } catch (_) {}

    try {
      final res = await supabase.rpc('acc_clear_test_expenses');
      return (res['deleted_invoices'] as int?) ?? 0;
    } catch (_) {
      // fallback delete
      try {
        await supabase.from('expense_invoices').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        try {
          await supabase.from('expenses').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        } catch (_) {}
        return 1;
      } catch (_) {
        return 0;
      }
    }
  }


  // ── المشتريات ───────────────────────────────────────────────────────────────

  /// قائمة طلبات التوريد — keyset pagination
  Future<Map<String, dynamic>> getSupplyOrders({
    String? status,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_supply_orders', params: {
      'p_status': ?status,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// إنشاء طلب توريد جديد (يمكن اعتماده تلقائياً إذا كان منشأ من الحسابات)
  Future<Map<String, dynamic>> createSupplyOrder({
    required String clientId,
    required String supplierName,
    String? supplierPhone,
    DateTime? expectedDate,
    String priority = 'normal',
    String? notes,
    required List<Map<String, dynamic>> lines,
    bool autoApprove = false,
  }) async {
    final result = await supabase.rpc('create_supply_order', params: {
      'p_client_id': clientId,
      'p_supplier_name': supplierName,
      'p_supplier_phone': ?supplierPhone,
      'p_expected_date': ?expectedDate?.toIso8601String().substring(0, 10),
      'p_priority': priority,
      'p_notes': ?notes,
      'p_lines': lines,
      'p_auto_approve': autoApprove,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// مراجعة طلب توريد (اعتماد بالكميات المعتمدة أو رفض مع السبب) للمحاسب
  Future<Map<String, dynamic>> reviewSupplyOrder({
    required String orderId,
    required String decision,
    required int expectedVersion,
    String? rejectionReason,
    List<Map<String, dynamic>>? lines,
  }) async {
    final result = await supabase.rpc('review_supply_order', params: {
      'p_order_id': orderId,
      'p_expected_version': expectedVersion,
      'p_decision': decision,
      'p_rejection_reason': ?rejectionReason,
      'p_lines': ?lines,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── المخزون ─────────────────────────────────────────────────────────────────

  /// نظرة عامة على المخزون — keyset pagination
  Future<Map<String, dynamic>> getInventoryOverview({
    bool lowStockOnly = false,
    int limit = 100,
    String? cursorName,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_inventory_overview', params: {
      'p_low_stock_only': lowStockOnly,
      'p_limit': limit,
      'p_cursor_name': ?cursorName,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ??
        {'summary': {}, 'items': [], 'limit': limit};
  }

  /// تحديث متوسط التكلفة لصنف في المخزون
  Future<Map<String, dynamic>> updateInventoryItemCost({
    required String itemId,
    required double avgCost,
  }) async {
    final result = await supabase.rpc('acc_update_item_cost', params: {
      'p_item_id': itemId,
      'p_avg_cost': avgCost,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// جلب قائمة المنتجات التامة مع أسعار البيع وتكلفة الوجبات
  Future<List<Map<String, dynamic>>> getProductsWithCosts() async {
    final result = await supabase.rpc('acc_get_products_with_costs');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// تحديث سعر البيع وتكلفة المنتج التام والخيارات
  Future<Map<String, dynamic>> updateProductPricing({
    required String productId,
    double? price,
    double cost = 0,
    List<Map<String, dynamic>>? variants,
  }) async {
    final result = await supabase.rpc('acc_update_product_pricing', params: {
      'p_product_id': productId,
      'p_price': ?price,
      'p_cost': cost,
      'p_variants': ?variants,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── الرواتب ─────────────────────────────────────────────────────────────────

  /// قائمة الموظفين مع الرواتب — keyset pagination
  Future<Map<String, dynamic>> getEmployeesSalaries({
    String? branchId,
    String status = 'active',
    int limit = 50,
    String? cursorName,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_employees_salaries', params: {
      'p_branch_id': ?branchId,
      'p_status': status,
      'p_limit': limit,
      'p_cursor_name': ?cursorName,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// تعديل الراتب مع تسجيل السجل التاريخي
  Future<Map<String, dynamic>> updateSalary({
    required String employeeId,
    required double basicSalary,
    double? allowances,
    double? transportAllowance,
    required String reason,
    DateTime? effectiveDate,
  }) async {
    final result = await supabase.rpc('acc_update_salary', params: {
      'p_employee_id': employeeId,
      'p_basic_salary': basicSalary,
      'p_allowances': ?allowances,
      'p_transport_allowance': ?transportAllowance,
      'p_reason': reason,
      'p_effective_date': ?effectiveDate?.toIso8601String().substring(0, 10),
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// سجل تغييرات راتب موظف
  Future<List<Map<String, dynamic>>> getSalaryHistory(
      String employeeId) async {
    final result = await supabase.rpc('acc_get_salary_history', params: {
      'p_employee_id': employeeId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── التنبيهات والـ Dashboard ────────────────────────────────────────────────

  /// تنبيهات الـ Dashboard (عجوزات + طلبات معلقة + مخزون منخفض)
  Future<List<Map<String, dynamic>>> getDashboardAlerts() async {
    final result = await supabase.rpc('acc_get_dashboard_alerts');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── بيانات مشتركة ───────────────────────────────────────────────────────────

  /// قائمة الفروع
  Future<List<Map<String, dynamic>>> listBranches() async {
    final result = await supabase.rpc('acc_list_branches');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// قائمة الموردين
  Future<List<Map<String, dynamic>>> listSuppliers() async {
    final result = await supabase.rpc('acc_list_suppliers');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// موظفو فرع محدد (للإحالة إلى HR)
  Future<List<Map<String, dynamic>>> getBranchEmployees(
      String branchId) async {
    final result = await supabase.rpc('acc_get_branch_employees', params: {
      'p_branch_id': branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── التقارير الشاملة ────────────────────────────────────────────────────────

  /// احتساب طلبيات الفرع من المخزن الرئيسي كقيمة مالية
  Future<Map<String, dynamic>> getBranchWarehouseOrders({
    DateTime? from,
    DateTime? to,
    String? branchId,
  }) async {
    final result =
        await supabase.rpc('acc_get_branch_warehouse_orders', params: {
      'p_from': ?from?.toUtc().toIso8601String(),
      'p_to': ?to?.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return (result as Map<String, dynamic>?) ??
        {'orders': [], 'total_cost': 0};
  }

  /// التقرير المالي الشامل للشركة والفرع (مبيعات، مشتريات، مصروفات، طلبيات، فائض كاشير)
  Future<Map<String, dynamic>> getComprehensiveFinancialReport({
    DateTime? from,
    DateTime? to,
    String? branchId,
  }) async {
    Map<String, dynamic> report = {};
    try {
      final result =
          await supabase.rpc('acc_get_comprehensive_financial_report', params: {
        'p_from': ?from?.toUtc().toIso8601String(),
        'p_to': ?to?.toUtc().toIso8601String(),
        'p_branch_id': ?branchId,
      });
      if (result is Map) {
        report = Map<String, dynamic>.from(result);
      }
    } catch (_) {}

    // التحقق من المصروفات المعتمدة إذا كانت صفر
    final expensesMap = (report['expenses'] as Map<String, dynamic>?) ?? {};
    final expTotal = (expensesMap['total'] as num?)?.toDouble() ?? 0.0;
    if (expTotal == 0.0 && from != null && to != null) {
      try {
        final fromDate = from.toIso8601String().split('T').first;
        final toDate   = to.toIso8601String().split('T').first;
        var query = supabase
            .from('expense_invoices')
            .select('category, total, status')
            .gte('expense_date', fromDate)
            .lte('expense_date', toDate)
            .inFilter('status', ['approved', 'posted']);

        if (branchId != null && branchId.isNotEmpty && branchId != 'HQ') {
          query = query.eq('branch_id', branchId);
        } else if (branchId == 'HQ') {
          query = query.isFilter('branch_id', null);
        }

        final rows = await query;
        double calcTotal = 0.0;
        final catMap = <String, double>{};

        for (final r in (rows as List? ?? [])) {
          final t = (r['total'] as num?)?.toDouble() ?? 0.0;
          final c = (r['category'] as String?)?.trim() ?? 'أخرى';
          calcTotal += t;
          catMap[c] = (catMap[c] ?? 0) + t;
        }

        if (calcTotal > 0) {
          final byCatList = catMap.entries
              .map((e) => {'category': e.key, 'total': e.value})
              .toList()
            ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

          report['expenses'] = {
            'count': (rows as List).length,
            'total': calcTotal,
            'by_category': byCatList,
          };

          // إعادة احتساب صافي الربح
          final salesTotal = ((report['sales'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
          final surplus    = ((report['closings'] as Map?)?['surplus'] as num?)?.toDouble() ?? 0.0;
          final purchases  = ((report['purchases'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
          final shortage   = ((report['closings'] as Map?)?['shortage'] as num?)?.toDouble() ?? 0.0;
          report['net_profit'] = (salesTotal + surplus) - (calcTotal + purchases + shortage);
        }
      } catch (_) {}
    }

    return report;
  }
}
