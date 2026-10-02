import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/inventory/inventory_api.dart';
import '../../../data/inventory/inventory_sync.dart' show InventorySync;
import '../../../data/inventory/models/catalog_snapshot.dart';
import '../../../data/inventory/models/stock_entry.dart';
import '../../../data/inventory/models/supply_order.dart';
import '../models/enums.dart';
import '../models/raw_material.dart';
import '../models/audit_row.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryApi _api;
  final InventorySync _sync;

  InventoryCubit(this._api, this._sync) : super(InventoryState.initial());

  // --- Initial Data Load ---
  Future<void> loadInitialData() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // Load from local cache first
      final cachedCatalog = await _sync.loadCatalogFromCache();
      if (cachedCatalog.stamp > 0) {
        emit(state.copyWith(catalog: cachedCatalog));
      }
      
      // Let Sync do the heavy lifting from network (deltas)
      final freshCatalog = await _sync.syncCatalog();
      final freshStock = await _sync.syncStock(); // Main warehouse assumed
      final supplyOrders = await _api.getSupplyOrders();
      final branchOrders = await _api.getBranchOrders();

      emit(state.copyWith(
        isLoading: false,
        catalog: freshCatalog,
        stock: freshStock.entries,
        supplyOrders: supplyOrders,
        branchOrders: branchOrders,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // --- State Updaters from SyncManager (Realtime) ---
  void updateCatalog(CatalogSnapshot catalog) {
    emit(state.copyWith(catalog: catalog));
  }

  void updateStock(List<StockEntry> stock) {
    emit(state.copyWith(stock: stock));
  }

  // --- UI Interactions ---

  void selectSection(InventorySection section) {
    emit(state.copyWith(section: section));
  }

  void setRawQuery(String query) {
    emit(state.copyWith(rawQuery: query));
  }

  void setRawCategoryFilter(String? categoryId) {
    if (categoryId == null) {
      emit(state.nullifyRawCategoryFilter());
    } else {
      emit(state.setRawCategoryIdFilter(categoryId));
    }
  }

  void toggleRawLowOnly() {
    emit(state.copyWith(rawLowOnly: !state.rawLowOnly));
  }

  void sortRaw(RawSortColumn column) {
    if (state.rawSortColumn == column) {
      emit(state.copyWith(rawSortAscending: !state.rawSortAscending));
    } else {
      emit(state.copyWith(rawSortColumn: column, rawSortAscending: true));
    }
  }

  void selectSupplyTab(SupplyOrderStatus status) {
    emit(state.copyWith(supplyTab: status));
  }

  // --- Operations (Async) ---

  Future<void> createSupplyOrder({
    required String supplierName,
    required DateTime expectedDate,
    required String priority,
    required List<Map<String, dynamic>> lines,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _api.createSupplyOrder(
        supplierName: supplierName,
        expectedDate: expectedDate,
        priority: priority,
        lines: lines,
      );
      // Refresh documents
      final orders = await _api.getSupplyOrders();
      emit(state.copyWith(
        isLoading: false,
        supplyOrders: orders,
        supplyTab: SupplyOrderStatus.pendingReview,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> createKitchenIssue({
    required String chefName,
    required String shift,
    String? cookPlan,
    required List<Map<String, dynamic>> lines,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _api.createKitchenIssue(
        chefName: chefName,
        shift: shift,
        cookPlan: cookPlan,
        lines: lines,
      );
      // Reload stock after issue
      final freshStock = (await _sync.syncStock()).entries;
      emit(state.copyWith(isLoading: false, stock: freshStock));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> createKitchenBatch({
    required String itemId,
    required double quantity,
    String? qualityNote,
    required DateTime producedAt,
    DateTime? expiresAt,
  }) async {
    // In real implementation this would call a repository RPC
  }


  /// جرد حقيقي — يرسل الصفوف للسيرفر ويحدث الكاش محلياً
  Future<Map<String, dynamic>> applyStocktake({
    bool dryRun = true,
    String? token,
    String? notes,
  }) async {
    final lines = state.auditRows.map((r) => {
      'sku': r.sku,
      'actual_qty': r.actualQty,
      'spoiled_qty': 0.0,
      'note': r.note,
    }).toList();

    final result = await _api.applyStocktake(
      dryRun: dryRun,
      token: token,
      notes: notes,
      lines: lines,
    );
    // إذا كانت commit → حدّث الرصيد من السيرفر
    if (!dryRun) {
      final freshStock = await _sync.syncStock();
      emit(state.copyWith(stock: freshStock.entries));
    }
    return {
      'ok': result.ok,
      'diffs': result.lines
          .where((l) => (l.adjustQty).abs() > 0.001 || (l.damagedQty) > 0)
          .map((l) => {'sku': l.sku, 'name': l.name, 'adjust': l.adjustQty})
          .toList(),
      'errors': result.errors,
    };
  }

  void reconcileAudit() {
    // يُستدعى للمعاينة فقط — التطبيق الفعلي عبر applyStocktake(dryRun: false)
  }

  // --- UI-Level Raw Material Operations (Local State) ---

  /// Add a raw material to local UI state (sample data mode)
  bool addRawMaterial(RawMaterial material) {
    // No duplicate SKU check needed for now — just emit notification
    return true; // success
  }

  /// Set stock for an item by SKU (local optimistic update)
  void setStock(String sku, double newStock) {
    // In real implementation this would call a repository RPC
    // For now just a no-op; stock is managed via Supabase sync
  }

  /// Adjust stock by delta for an item by SKU
  void adjustStock(String sku, double delta) {
    // In real implementation this would call a repository RPC
    // For now just a no-op; stock is managed via Supabase sync
  }

  // --- Audit Operations ---

  void setAuditActual(String sku, double qty) {
    final updatedRows = state.auditRows.map((row) {
      if (row.sku == sku) {
        return AuditRow(
          sku: row.sku,
          name: row.name,
          systemQty: row.systemQty,
          actualQty: qty,
          unit: row.unit,
          note: row.note,
        );
      }
      return row;
    }).toList();
    emit(state.copyWith(auditRows: updatedRows));
  }

  void setAuditNote(String sku, String note) {
    final updatedRows = state.auditRows.map((row) {
      if (row.sku == sku) {
        return AuditRow(
          sku: row.sku,
          name: row.name,
          systemQty: row.systemQty,
          actualQty: row.actualQty,
          unit: row.unit,
          note: note,
        );
      }
      return row;
    }).toList();
    emit(state.copyWith(auditRows: updatedRows));
  }

  // --- Branch Order Operations ---

  void deleteBranchOrder(String id) {
    final updated = state.branchOrders.where((o) => o.id != id).toList();
    emit(state.copyWith(branchOrders: updated));
  }

  void dispatchBranchOrder(String id) {
    // In real implementation this would call a repository RPC
    // For now it's a no-op since BranchOrderStatus doesn't have 'dispatched'
  }

  void setIssuedQuantity(String orderId, String itemId, int qty) {
    // Local UI state update — no-op in current data model
  }

  void setItemUnavailable(String orderId, String itemId, bool unavailable) {
    // Local UI state update — no-op in current data model
  }
}

