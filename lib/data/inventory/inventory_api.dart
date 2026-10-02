import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/local_db.dart'; // using generateUuidV4() from here

import 'models/supply_order.dart';
import 'models/kitchen_models.dart';
import 'models/branch_order.dart';
import 'models/stocktake_models.dart';
import 'models/notification_models.dart';

/// واجهة برمجة التطبيقات للمخزون (Inventory API)
/// يحتوي على كافة نداءات RPC للقراءة والكتابة للمستندات والعمليات
class InventoryApi {
  final SupabaseClient _client;

  InventoryApi(this._client);

  // ── المستندات (Documents) ──────────────────────────────────────────────────

  Future<List<SupplyOrder>> getSupplyOrders({int limit = 100}) async {
    final res = await _client.rpc('inventory_get_documents', params: {
      'p_doc_type': 'supply_orders',
      'p_limit': limit,
    });
    final list = res as List<dynamic>;
    return list.map((j) => SupplyOrder.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<BranchOrder>> getBranchOrders({String? branchId, int limit = 100}) async {
    final res = await _client.rpc('inventory_get_documents', params: {
      'p_doc_type': 'branch_orders',
      if (branchId != null) 'p_branch_id': branchId,
      'p_limit': limit,
    });
    final list = res as List<dynamic>;
    return list.map((j) => BranchOrder.fromJson(j as Map<String, dynamic>)).toList();
  }
  
  // You can also add getKitchenIssues, getKitchenBatches if needed by the app.

  // ── العمليات (Operations) ──────────────────────────────────────────────────

  /// إنشاء طلب توريد
  Future<SupplyOrder> createSupplyOrder({
    required String supplierName,
    String? supplierPhone,
    required DateTime expectedDate,
    required String priority,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('create_supply_order', params: {
      'p_client_id': clientId,
      'p_supplier_name': supplierName,
      'p_supplier_phone': supplierPhone,
      'p_expected_date': expectedDate.toIso8601String().split('T').first,
      'p_priority': priority,
      'p_notes': notes,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    
    // According to specs, the RPC returns { ok, doc, stock, stamps }
    return SupplyOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// مراجعة طلب توريد
  Future<SupplyOrder> reviewSupplyOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('review_supply_order', params: {
      'p_client_id': clientId,
      'p_order_id': orderId,
      'p_approve': approve,
      'p_rejection_reason': rejectionReason,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return SupplyOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// استلام طلب توريد
  Future<SupplyOrder> receiveSupplyOrder({
    required String orderId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('receive_supply_order', params: {
      'p_client_id': clientId,
      'p_order_id': orderId,
      'p_notes': notes,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return SupplyOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// صرف خامات للمطبخ
  Future<KitchenIssue> createKitchenIssue({
    String? cookPlan,
    required String chefName,
    required String shift,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('create_kitchen_issue', params: {
      'p_client_id': clientId,
      'p_cook_plan': cookPlan,
      'p_chef_name': chefName,
      'p_shift': shift,
      'p_notes': notes,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return KitchenIssue.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// استلام إنتاج المطبخ
  Future<KitchenBatch> createKitchenBatch({
    String? itemId,
    String? newItemName,
    String? newItemUnit,
    required double quantity,
    String? productionLine,
    required DateTime producedAt,
    required DateTime finishedAt,
    String? qualityNote,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('create_kitchen_batch', params: {
      'p_client_id': clientId,
      'p_item_id': itemId,
      'p_new_item_name': newItemName,
      'p_new_item_unit': newItemUnit ?? 'عبوة',
      'p_quantity': quantity,
      'p_production_line': productionLine,
      'p_produced_at': producedAt.toUtc().toIso8601String(),
      'p_finished_at': finishedAt.toUtc().toIso8601String(),
      'p_quality_note': qualityNote,
    }) as Map<String, dynamic>;
    return KitchenBatch.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// طلب الفرع
  Future<BranchOrder> createBranchOrder({
    required String branchId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('create_branch_order', params: {
      'p_client_id': clientId,
      'p_branch_id': branchId,
      'p_notes': notes,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return BranchOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  Future<BranchOrder> updateBranchOrder({
    required String orderId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('update_branch_order', params: {
      'p_client_id': clientId,
      'p_order_id': orderId,
      'p_notes': notes,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return BranchOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  Future<BranchOrder> cancelBranchOrder({
    required String orderId,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('cancel_branch_order', params: {
      'p_client_id': clientId,
      'p_order_id': orderId,
    }) as Map<String, dynamic>;
    return BranchOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  Future<BranchOrder> decideBranchOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc('decide_branch_order', params: {
      'p_client_id': clientId,
      'p_order_id': orderId,
      'p_approve': approve,
      'p_rejection_reason': rejectionReason,
      'p_lines': lines,
    }) as Map<String, dynamic>;
    return BranchOrder.fromJson(res['doc'] as Map<String, dynamic>);
  }

  /// الجرد (المعاينة أو التطبيق)
  Future<StocktakePreview> applyStocktake({
    String? token,
    bool dryRun = true,
    String? warehouseId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = dryRun ? generateUuidV4() : generateUuidV4();
    final res = await _client.rpc('apply_stocktake', params: {
      'p_client_id': clientId,
      'p_token': token,
      'p_dry_run': dryRun,
      'p_warehouse_id': warehouseId,
      'p_notes': notes,
      'p_lines': lines,
    });
    return StocktakePreview.fromJson(res as Map<String, dynamic>);
  }

  /// استيراد الأصناف (Excel)
  Future<Map<String, dynamic>> importItems({
    String? token,
    bool dryRun = true,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> categories,
  }) async {
    final clientId = dryRun ? generateUuidV4() : generateUuidV4();
    final res = await _client.rpc('inventory_import_items', params: {
      'p_client_id': clientId,
      'p_token': token,
      'p_dry_run': dryRun,
      'p_items': items,
      'p_categories': categories,
    });
    return res as Map<String, dynamic>;
  }

  /// طلب تصريح الإدارة (للاستيراد أو الجرد)
  Future<Map<String, dynamic>> requestAdminApproval(String password, String action) async {
    final res = await _client.rpc('admin_issue_approval', params: {
      'p_password': password,
      'p_action': action,
    });
    return res as Map<String, dynamic>;
  }

  // ── الإشعارات ────────────────────────────────────────────────────────────

  Future<NotificationSummary> getNotificationsSummary({int limit = 50}) async {
    final res = await _client.rpc('notifications_summary', params: {'p_limit': limit});
    return NotificationSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    await _client.rpc('notifications_mark_read', params: {'p_ids': ids});
  }

  Future<void> markAllNotificationsRead() async {
    await _client.rpc('notifications_mark_all_read');
  }
}
