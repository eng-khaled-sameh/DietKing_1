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

    // التحقق المباشر من المبيعات إذا كانت دالة الـ RPC ترجع 0 أو فشلت
    final rpcSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
    if (rpcSales == 0.0) {
      try {
        final fromIso = from.toUtc().toIso8601String();
        final toIso   = to.toUtc().toIso8601String();
        var query = supabase
            .from('sales')
            .select('id, branch_id, branch_name, payment_method, subtotal, discount_amount, vat_amount, total, status, sold_at')
            .gte('sold_at', fromIso)
            .lte('sold_at', toIso);

        if (branchId != null && branchId.isNotEmpty && branchId != 'HQ') {
          query = query.eq('branch_id', branchId);
        }

        final rows = await query;
        double sumTotal = 0.0;
        double sumGross = 0.0;
        double sumDiscount = 0.0;
        double sumVat = 0.0;
        double sumCash = 0.0;
        double sumCard = 0.0;
        final branchMap = <String, Map<String, dynamic>>{};

        for (final row in (rows as List? ?? [])) {
          final st = (row['status'] as String?)?.toLowerCase();
          if (st == 'cancelled' || st == 'refunded') continue;
          final t = (row['total'] as num?)?.toDouble() ?? 0.0;
          final sub = (row['subtotal'] as num?)?.toDouble() ?? 0.0;
          final disc = (row['discount_amount'] as num?)?.toDouble() ?? 0.0;
          final v = (row['vat_amount'] as num?)?.toDouble() ?? 0.0;
          final m = (row['payment_method'] as String? ?? '').toLowerCase();

          final isCash = m.contains('cash') || m.contains('كاش') || m.contains('نقد');
          final isCard = m.contains('card') || m.contains('visa') || m.contains('شبك') || m.contains('مدى') || m.contains('pos');

          sumTotal += t;
          sumGross += sub;
          sumDiscount += disc;
          sumVat += v;
          if (isCash) sumCash += t;
          if (isCard) sumCard += t;

          final bId = (row['branch_id'] as String?) ?? 'unknown';
          final bName = (row['branch_name'] as String?) ?? 'فرع';
          final currentB = branchMap[bId] ?? {
            'branch_id': bId,
            'branch_name': bName,
            'total_sales': 0.0,
            'invoices_count': 0,
          };
          currentB['total_sales'] = (currentB['total_sales'] as double) + t;
          currentB['invoices_count'] = (currentB['invoices_count'] as int) + 1;
          branchMap[bId] = currentB;
        }

        if (rows.isNotEmpty || sumTotal > 0) {
          summary['total_sales'] = sumTotal;
          summary['gross_sales'] = sumGross;
          summary['total_discount'] = sumDiscount;
          summary['total_vat'] = sumVat;
          summary['cash_sales'] = sumCash;
          summary['card_sales'] = sumCard;
          summary['invoices_count'] = rows.length;
          summary['by_branch'] = branchMap.values.toList();
          final curExp = (summary['total_expenses'] as num?)?.toDouble() ?? 0.0;
          summary['net_revenue'] = sumTotal - curExp;
        }
      } catch (_) {}
    }

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

  /// تقرير مبيعات الباقات — مجمّع: اسم الوجبة، وزنها، عدد الوجبات، اسم الفرع
  Future<List<Map<String, dynamic>>> getPackageSales({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await supabase.rpc('acc_get_package_sales', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// تقرير الوجبات (المنيو) — الكميات المسحوبة من كل فرع والرصيد المالي لكل وجبة
  /// الباقات تُحسب كعدد وجبات عادي لكن في السعر النهائي قيمتها 0
  Future<List<Map<String, dynamic>>> getMealsReport({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await supabase.rpc('acc_get_meals_report', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
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

    final fromIso = from?.toUtc().toIso8601String();
    final toIso = to?.toUtc().toIso8601String();

    // 1. التحقق المباشر من المبيعات (إذا كانت صفر أو مفقودة)
    final salesMap = (report['sales'] as Map<String, dynamic>?) ?? {};
    final salesTot = (salesMap['total'] as num?)?.toDouble() ?? 0.0;
    if (salesTot == 0.0 && fromIso != null && toIso != null) {
      try {
        var query = supabase
            .from('sales')
            .select('id, branch_id, branch_name, payment_method, subtotal, discount_amount, vat_amount, total, status, sold_at')
            .gte('sold_at', fromIso)
            .lte('sold_at', toIso);

        if (branchId != null && branchId.isNotEmpty && branchId != 'HQ') {
          query = query.eq('branch_id', branchId);
        }

        final rows = await query;
        double sumTotal = 0.0;
        double sumSubtotal = 0.0;
        double sumVat = 0.0;
        double sumCash = 0.0;
        double sumCard = 0.0;
        int invCount = 0;

        for (final row in (rows as List? ?? [])) {
          final st = (row['status'] as String?)?.toLowerCase();
          if (st == 'cancelled' || st == 'refunded') continue;
          final t = (row['total'] as num?)?.toDouble() ?? 0.0;
          final sub = (row['subtotal'] as num?)?.toDouble() ?? 0.0;
          final v = (row['vat_amount'] as num?)?.toDouble() ?? 0.0;
          final m = (row['payment_method'] as String? ?? '').toLowerCase();

          final isCash = m.contains('cash') || m.contains('كاش') || m.contains('نقد');
          final isCard = m.contains('card') || m.contains('visa') || m.contains('شبك') || m.contains('مدى') || m.contains('pos');

          sumTotal += t;
          sumSubtotal += sub;
          sumVat += v;
          if (isCash) sumCash += t;
          if (isCard) sumCard += t;
          invCount++;
        }

        if (invCount > 0 || sumTotal > 0) {
          report['sales'] = {
            'count': invCount,
            'subtotal': sumSubtotal,
            'vat_amount': sumVat,
            'total': sumTotal,
            'cash': sumCash,
            'card': sumCard,
          };
        }
      } catch (_) {}
    }

    // 2. التحقق المباشر من المصروفات المعتمدة (إذا كانت صفر)
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
        }
      } catch (_) {}
    }

    // 3. التحقق المباشر من مشتريات التوريد للمخزون (Supply Orders)
    final purMap = (report['purchases'] as Map<String, dynamic>?) ?? {};
    final purTotal = (purMap['total'] as num?)?.toDouble() ?? 0.0;
    if (purTotal == 0.0 && from != null && to != null) {
      try {
        final ordersData = await getSupplyOrders(limit: 200);
        final items = List<Map<String, dynamic>>.from(ordersData['items'] as List? ?? []);
        double sumPur = 0.0;
        int purCount = 0;

        for (final o in items) {
          final dtStr = o['created_at'] as String? ?? o['expected_date'] as String?;
          final dt = DateTime.tryParse(dtStr ?? '');
          if (dt != null && (dt.isBefore(from) || dt.isAfter(to))) {
            continue;
          }
          final st = (o['status'] as String?)?.toLowerCase();
          if (st == 'rejected' || st == 'cancelled') continue;

          final lines = o['lines'] as List? ?? [];
          double oTotal = 0.0;
          for (final l in lines) {
            if (l is Map) {
              final q = (l['qty_approved'] ?? l['qty_received'] ?? l['qty_requested'] as num?)?.toDouble() ?? 0.0;
              final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0.0;
              oTotal += (q * cost);
            }
          }
          sumPur += oTotal;
          purCount++;
        }

        if (sumPur == 0.0 && fromIso != null && toIso != null) {
          final rows = await supabase
              .from('supply_orders')
              .select('id, number, status, created_at, supply_order_lines(qty_approved, qty_received, qty_requested, unit_cost)')
              .gte('created_at', fromIso)
              .lte('created_at', toIso);

          for (final r in (rows as List? ?? [])) {
            final st = (r['status'] as String?)?.toLowerCase();
            if (st == 'rejected' || st == 'cancelled') continue;
            final lines = r['supply_order_lines'] as List? ?? [];
            for (final l in lines) {
              if (l is Map) {
                final q = (l['qty_approved'] ?? l['qty_received'] ?? l['qty_requested'] as num?)?.toDouble() ?? 0.0;
                final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0.0;
                sumPur += (q * cost);
              }
            }
            purCount++;
          }
        }

        if (purCount > 0 || sumPur > 0) {
          report['purchases'] = {
            'count': purCount,
            'total': sumPur,
          };
        }
      } catch (_) {}
    }

    // 4. التحقق المباشر من طلبيات الفرع من المخزون كفلوس
    final boMap = (report['branch_warehouse_orders'] as Map<String, dynamic>?) ?? {};
    final boTotal = (boMap['total'] as num?)?.toDouble() ?? 0.0;
    if (boTotal == 0.0 && from != null && to != null) {
      try {
        final boRes = await getBranchWarehouseOrders(from: from, to: to, branchId: branchId);
        final bTotal = (boRes['total_cost'] ?? boRes['total'] as num?)?.toDouble() ?? 0.0;
        final bOrders = boRes['orders'] as List? ?? [];
        if (bTotal > 0 || bOrders.isNotEmpty) {
          report['branch_warehouse_orders'] = {
            'count': bOrders.length,
            'total': bTotal,
          };
        }
      } catch (_) {}
    }

    // 5. التحقق المباشر من إقفالات الكاشير (فائض وعجز الصندوق)
    final clMap = (report['closings'] as Map<String, dynamic>?) ?? {};
    final clCount = (clMap['count'] as num?)?.toInt() ?? 0;
    if (clCount == 0 && fromIso != null && toIso != null) {
      try {
        var cq = supabase
            .from('shift_closings')
            .select('id, branch_id, opening_cash, counted_cash, actual_cash, system_cash, difference, closed_at')
            .gte('closed_at', fromIso)
            .lte('closed_at', toIso);
        if (branchId != null && branchId.isNotEmpty && branchId != 'HQ') {
          cq = cq.eq('branch_id', branchId);
        }
        final clRows = await cq;
        double surplus = 0.0;
        double shortage = 0.0;
        for (final row in (clRows as List? ?? [])) {
          final diff = (row['difference'] as num?)?.toDouble() ??
              (((row['actual_cash'] ?? row['counted_cash'] as num?)?.toDouble() ?? 0.0) -
                  ((row['system_cash'] as num?)?.toDouble() ?? 0.0));
          if (diff > 0) surplus += diff;
          if (diff < 0) shortage += diff.abs();
        }
        report['closings'] = {
          'count': (clRows as List).length,
          'surplus': surplus,
          'shortage': shortage,
        };
      } catch (_) {}
    }

    // 6. إعادة احتساب صافي الربح
    final sTotal = ((report['sales'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
    final eTotal = ((report['expenses'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
    final pTotal = ((report['purchases'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
    final bOrdersTotal = ((report['branch_warehouse_orders'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0;
    final surplusTotal = ((report['closings'] as Map?)?['surplus'] as num?)?.toDouble() ?? 0.0;
    final isComp = branchId == null || branchId.isEmpty || branchId == 'HQ';
    final suppliesCost = isComp ? pTotal : bOrdersTotal;

    report['net_profit'] = (sTotal + surplusTotal) - (eTotal + suppliesCost);

    return report;
  }

  // ── جرد المخزون ومراجعة وتدقيق الجرودات وتطبيق الخصومات ──────────────────────────

  /// جلب عمليات الجرد مع تفاصيل المراجعة والخصم والعجز
  Future<List<Map<String, dynamic>>> getStocktakeAudits({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await supabase.rpc('acc_get_stocktake_audits', params: {
        'p_from': ?from?.toIso8601String(),
        'p_to': ?to?.toIso8601String(),
      });
      if (res is List && res.isNotEmpty) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (_) {}

    // استعلام مباشر احتياطي
    try {
      var query = supabase.from('stocktakes').select('''
        id, number, created_at, notes, total_items, total_adjust, total_damage, warehouse_id, applied_by
      ''');
      if (from != null) query = query.gte('created_at', from.toIso8601String());
      if (to != null) query = query.lte('created_at', to.toIso8601String());

      final rows = await query.order('created_at', ascending: false).limit(100);
      final List<Map<String, dynamic>> results = [];

      // جلب المراجعات المسجلة إن وجدت
      Map<String, Map<String, dynamic>> reviewsMap = {};
      try {
        final reviews = await supabase.from('stocktake_reviews').select('*');
        for (final r in (reviews as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          if (m['stocktake_id'] != null) {
            reviewsMap[m['stocktake_id'].toString()] = m;
          }
        }
      } catch (_) {}

      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final stId = row['id'].toString();
        final rev = reviewsMap[stId];

        // حساب تقريبي لقيمة العجز إن لم تكن مسجلة
        double shortageVal = (rev?['shortage_value'] as num?)?.toDouble() ?? 0.0;
        double damageVal = (rev?['damage_value'] as num?)?.toDouble() ?? 0.0;

        if (shortageVal == 0 && damageVal == 0) {
          try {
            final lines = await supabase
                .from('stocktake_lines')
                .select('adjust_qty, damaged_qty, unit_cost')
                .eq('stocktake_id', stId);
            for (final l in (lines as List)) {
              final adj = (l['adjust_qty'] as num?)?.toDouble() ?? 0.0;
              final dmg = (l['damaged_qty'] as num?)?.toDouble() ?? 0.0;
              final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0.0;
              if (adj < 0) shortageVal += adj.abs() * cost;
              if (dmg > 0) damageVal += dmg * cost;
            }
          } catch (_) {}
        }

        results.add({
          'id': stId,
          'number': row['number'] ?? 'STK-${stId.substring(0, 6)}',
          'created_at': row['created_at'],
          'notes': row['notes'],
          'total_items': (row['total_items'] as num?)?.toInt() ?? 0,
          'total_adjust': (row['total_adjust'] as num?)?.toDouble() ?? 0.0,
          'total_damage': (row['total_damage'] as num?)?.toDouble() ?? 0.0,
          'warehouse_id': row['warehouse_id'],
          'applied_by': row['applied_by'],
          'shortage_value': shortageVal,
          'damage_value': damageVal,
          'review_status': rev?['status'] ?? 'pending_review',
          'reviewed_at': rev?['reviewed_at'],
          'reviewer_name': rev?['reviewer_name'],
          'review_notes': rev?['review_notes'],
          'deduction_amount': (rev?['deduction_amount'] as num?)?.toDouble() ?? 0.0,
          'deduction_employee_id': rev?['deduction_employee_id'],
          'deduction_employee_name': rev?['deduction_employee_name'],
          'deduction_employee_role': rev?['deduction_employee_role'],
          'deduction_request_id': rev?['deduction_request_id'],
        });
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// تفاصيل سطور الجرد لمطابقة الأصناف
  Future<List<Map<String, dynamic>>> getStocktakeLines(String stocktakeId) async {
    // 1. استخدام الدالة المخصصة التي تتجاوز RLS وتجلب تفاصيل الأصناف بشكل صحيح
    try {
      final res = await supabase.rpc(
        'acc_get_stocktake_lines',
        params: {'p_stocktake_id': stocktakeId},
      );
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
      // الدالة ترجع jsonb - قد يعود كـ String أو List
      if (res is String) {
        // محاولة parse إن جاء كـ JSON string
        return [];
      }
    } catch (_) {}

    // 2. استعلام مباشر احتياطي
    try {
      final res = await supabase
          .from('stocktake_lines')
          .select('id, system_qty, counted_qty, damaged_qty, adjust_qty, unit_cost, note, item_id')
          .eq('stocktake_id', stocktakeId);

      final lines = res as List;
      if (lines.isEmpty) return [];

      // جلب تفاصيل الأصناف بشكل منفصل
      final itemIds = lines.map((l) => l['item_id'].toString()).toSet().toList();
      Map<String, Map<String, dynamic>> itemsMap = {};
      try {
        final items = await supabase
            .from('inventory_items')
            .select('id, sku, name, unit_code')
            .inFilter('id', itemIds);
        for (final it in (items as List)) {
          final m = Map<String, dynamic>.from(it as Map);
          itemsMap[m['id'].toString()] = m;
        }
      } catch (_) {}

      return lines.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final item = itemsMap[map['item_id']?.toString() ?? ''] ?? {};
        final adj = (map['adjust_qty'] as num?)?.toDouble() ?? 0.0;
        final dmg = (map['damaged_qty'] as num?)?.toDouble() ?? 0.0;
        final cost = (map['unit_cost'] as num?)?.toDouble() ?? 0.0;

        return {
          'id': map['id'],
          'sku': item['sku'] ?? '',
          'name': item['name'] ?? 'صنف غير محدد',
          'unit_code': item['unit_code'] ?? '',
          'system_qty': (map['system_qty'] as num?)?.toDouble() ?? 0.0,
          'counted_qty': (map['counted_qty'] as num?)?.toDouble() ?? 0.0,
          'damaged_qty': dmg,
          'adjust_qty': adj,
          'unit_cost': cost,
          'shortage_value': adj < 0 ? (adj.abs() * cost) : 0.0,
          'damage_value': dmg * cost,
          'note': map['note'],
        };
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// جلب عمال المطبخ والمخزون فقط لتطبيق الخصم عليهم مع بدائل متعددة
  Future<List<Map<String, dynamic>>> getKitchenAndWarehouseEmployees({bool allActiveIfNone = true}) async {
    // 1. استدعاء الدالة المخصصة acc_get_kitchen_and_warehouse_employees
    try {
      final res = await supabase.rpc('acc_get_kitchen_and_warehouse_employees');
      // الدالة ترجع jsonb - يمكن أن يُفسَّر كـ List أو Map أو String
      List<dynamic> rawList = [];
      if (res is List) {
        rawList = res;
      } else if (res is Map && res.containsKey('data')) {
        rawList = res['data'] as List? ?? [];
      }
      if (rawList.isNotEmpty) {
        return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    // 2. استعلام مباشر على جدول الموظفين (يعمل لأن الـ policy تسمح لجميع المستخدمين المصادقين بعد migration 036)
    try {
      final res = await supabase
          .from('employees')
          .select('id, code, full_name, job_role, basic_salary, status, branch_id')
          .eq('status', 'active')
          .inFilter('job_role', ['kitchen_worker', 'chef', 'storekeeper', 'worker'])
          .order('full_name');

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      if (list.isNotEmpty) return list;

      // إذا لم يكن هناك عمال بهذه المسميات وطُلب جلب جميع النشطين
      if (allActiveIfNone) {
        final anyActive = await supabase
            .from('employees')
            .select('id, code, full_name, job_role, basic_salary, status, branch_id')
            .eq('status', 'active')
            .order('full_name');
        return List<Map<String, dynamic>>.from(anyActive as List? ?? []);
      }
    } catch (_) {}

    return [];
  }

  /// اعتماد الجرد بدون خصم
  Future<Map<String, dynamic>> approveStocktakeWithoutDeduction({
    required String stocktakeId,
    String? notes,
    String? reviewerName,
  }) async {
    try {
      final r = await supabase.rpc('acc_approve_stocktake_without_deduction', params: {
        'p_stocktake_id': stocktakeId,
        'p_notes': ?notes,
        'p_reviewer_name': ?reviewerName,
      });
      return Map<String, dynamic>.from(r as Map? ?? {});
    } catch (_) {
      // Direct upsert
      try {
        final uid = supabase.auth.currentUser?.id;
        await supabase.from('stocktake_reviews').upsert({
          'stocktake_id': stocktakeId,
          'status': 'approved',
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewer_name': reviewerName ?? 'المحاسب',
          'review_notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'stocktake_id');
        return {'success': true, 'status': 'approved'};
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }
  }

  /// اعتماد الجرد وتطبيق خصم على عامل مطبخ أو مخزون وإرساله لـ HR
  Future<Map<String, dynamic>> submitStocktakeDeduction({
    required String stocktakeId,
    required String employeeId,
    required double amount,
    required String notes,
    String? reviewerName,
  }) async {
    try {
      final r = await supabase.rpc('acc_submit_stocktake_deduction', params: {
        'p_stocktake_id': stocktakeId,
        'p_employee_id': employeeId,
        'p_amount': amount,
        'p_notes': notes,
        'p_reviewer_name': ?reviewerName,
      });
      return Map<String, dynamic>.from(r as Map? ?? {});
    } catch (_) {
      // Direct insertion into deduction_bonus_requests & stocktake_reviews
      try {
        final uid = supabase.auth.currentUser?.id;
        // 1. Get employee info
        final empRes = await supabase.from('employees').select('full_name, job_role').eq('id', employeeId).single();
        final empName = empRes['full_name'] as String? ?? '';
        final empRole = empRes['job_role'] as String? ?? '';

        // 2. Insert into deduction_bonus_requests
        final req = await supabase.from('deduction_bonus_requests').insert({
          'employee_id': employeeId,
          'requested_from': 'inventory',
          'type': 'deduction',
          'amount_type': 'cash',
          'cash_amount': amount,
          'notes': notes,
          'status': 'pending',
          'created_by': uid,
        }).select('id').single();

        final reqId = req['id'];

        // 3. Upsert stocktake_reviews
        await supabase.from('stocktake_reviews').upsert({
          'stocktake_id': stocktakeId,
          'status': 'approved_with_deduction',
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewer_name': reviewerName ?? 'المحاسب',
          'review_notes': notes,
          'deduction_request_id': reqId,
          'deduction_employee_id': employeeId,
          'deduction_employee_name': empName,
          'deduction_employee_role': empRole,
          'deduction_amount': amount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'stocktake_id');

        return {
          'success': true,
          'status': 'approved_with_deduction',
          'deduction_request_id': reqId,
        };
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }
  }

  /// إنشاء وتسجيل عملية جرد جديدة
  Future<Map<String, dynamic>> createStocktakeAudit({
    required List<Map<String, dynamic>> lines,
    String? notes,
  }) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      final whRes = await supabase.from('warehouses').select('id').limit(1).maybeSingle();
      final whId = whRes?['id'];
      final numStr = 'STK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      double totalAdj = 0;
      double totalDmg = 0;

      for (final l in lines) {
        final counted = (l['counted_qty'] as num?)?.toDouble() ?? 0.0;
        final system = (l['system_qty'] as num?)?.toDouble() ?? 0.0;
        final dmg = (l['damaged_qty'] as num?)?.toDouble() ?? 0.0;
        final adj = counted - (system - dmg);
        totalAdj += adj;
        totalDmg += dmg;
      }

      final stInsert = await supabase.from('stocktakes').insert({
        'number': numStr,
        'client_id': supabase.auth.currentUser?.id ?? DateTime.now().toIso8601String(),
        'warehouse_id': whId,
        'notes': notes,
        'total_items': lines.length,
        'total_adjust': totalAdj,
        'total_damage': totalDmg,
        'applied_by': uid,
      }).select('id, number').single();

      final stId = stInsert['id'] as String;

      final List<Map<String, dynamic>> linesToInsert = [];
      for (final l in lines) {
        final counted = (l['counted_qty'] as num?)?.toDouble() ?? 0.0;
        final system = (l['system_qty'] as num?)?.toDouble() ?? 0.0;
        final dmg = (l['damaged_qty'] as num?)?.toDouble() ?? 0.0;
        final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0.0;
        linesToInsert.add({
          'stocktake_id': stId,
          'item_id': l['item_id'],
          'system_qty': system,
          'counted_qty': counted,
          'damaged_qty': dmg,
          'adjust_qty': counted - (system - dmg),
          'unit_cost': cost,
          'note': l['note'],
        });
      }

      if (linesToInsert.isNotEmpty) {
        await supabase.from('stocktake_lines').insert(linesToInsert);
      }

      try {
        await supabase.from('stocktake_reviews').insert({
          'stocktake_id': stId,
          'status': 'pending_review',
        });
      } catch (_) {}

      return {'success': true, 'id': stId, 'number': numStr};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
