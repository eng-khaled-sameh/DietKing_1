import 'package:equatable/equatable.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_category.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_item.dart';
import 'package:my_desktop_app/data/inventory/models/stock_entry.dart';
import 'package:my_desktop_app/data/inventory/models/catalog_snapshot.dart';
import 'package:my_desktop_app/data/inventory/models/supply_order.dart';
import 'package:my_desktop_app/data/inventory/models/kitchen_models.dart';
import 'package:my_desktop_app/data/inventory/models/branch_order.dart';
import 'package:my_desktop_app/data/inventory/models/stocktake_models.dart';
import '../models/enums.dart';
import '../models/audit_row.dart';

/// كلاس مساعد لربط الصنف بالرصيد في واجهة المستخدم
class InventoryItemWithStock {
  final InventoryItem item;
  final double stockQty;
  final InventoryCategory? category;
  
  InventoryItemWithStock({
    required this.item, 
    required this.stockQty,
    this.category,
  });
  
  bool get isLow => stockQty <= item.minLevel && item.minLevel > 0;
  String get categoryLabel => category?.name ?? 'بدون تصنيف';
}

class InventoryState extends Equatable {
  final InventorySection section;
  final bool isLoading;
  final String? error;
  
  // Catalog & Stock data
  final CatalogSnapshot? catalog;
  final List<StockEntry> stock;

  // Raw Materials filters
  final String rawQuery;
  final String? rawCategoryIdFilter;
  final bool rawLowOnly;
  final RawSortColumn? rawSortColumn;
  final bool rawSortAscending;

  // Supply state
  final List<SupplyOrder> supplyOrders;
  final SupplyOrderStatus supplyTab;

  // Kitchen state
  final List<KitchenIssue> kitchenIssues;
  final List<KitchenBatch> kitchenBatches;

  // Branch Orders state
  final List<BranchOrder> branchOrders;

  // Stocktake state
  final List<StocktakeRecord> stocktakeRecords;
  
  // Audit rows (local UI state for stock auditing)
  final List<AuditRow> auditRows;

  const InventoryState({
    this.section = InventorySection.dashboard,
    this.isLoading = false,
    this.error,
    this.catalog,
    this.stock = const [],
    this.rawQuery = '',
    this.rawCategoryIdFilter,
    this.rawLowOnly = false,
    this.rawSortColumn,
    this.rawSortAscending = true,
    this.supplyOrders = const [],
    this.supplyTab = SupplyOrderStatus.pendingReview,
    this.kitchenIssues = const [],
    this.kitchenBatches = const [],
    this.branchOrders = const [],
    this.stocktakeRecords = const [],
    this.auditRows = const [],
  });

  factory InventoryState.initial() => const InventoryState();

  InventoryState copyWith({
    InventorySection? section,
    bool? isLoading,
    String? error,
    CatalogSnapshot? catalog,
    List<StockEntry>? stock,
    String? rawQuery,
    String? rawCategoryIdFilter,
    bool? rawLowOnly,
    RawSortColumn? rawSortColumn,
    bool? rawSortAscending,
    List<SupplyOrder>? supplyOrders,
    SupplyOrderStatus? supplyTab,
    List<KitchenIssue>? kitchenIssues,
    List<KitchenBatch>? kitchenBatches,
    List<BranchOrder>? branchOrders,
    List<StocktakeRecord>? stocktakeRecords,
    List<AuditRow>? auditRows,
  }) {
    return InventoryState(
      section: section ?? this.section,
      isLoading: isLoading ?? this.isLoading,
      error: error, // error resets if not provided explicitly? No, let's keep it if not null? Standard is reset if not provided, or explicitly pass it. Let's just do error: error
      catalog: catalog ?? this.catalog,
      stock: stock ?? this.stock,
      rawQuery: rawQuery ?? this.rawQuery,
      rawCategoryIdFilter: rawCategoryIdFilter, // Note: copyWith doesn't handle nullification well here, so we'll use nullify func
      rawLowOnly: rawLowOnly ?? this.rawLowOnly,
      rawSortColumn: rawSortColumn ?? this.rawSortColumn,
      rawSortAscending: rawSortAscending ?? this.rawSortAscending,
      supplyOrders: supplyOrders ?? this.supplyOrders,
      supplyTab: supplyTab ?? this.supplyTab,
      kitchenIssues: kitchenIssues ?? this.kitchenIssues,
      kitchenBatches: kitchenBatches ?? this.kitchenBatches,
      branchOrders: branchOrders ?? this.branchOrders,
      stocktakeRecords: stocktakeRecords ?? this.stocktakeRecords,
      auditRows: auditRows ?? this.auditRows,
    );
  }

  InventoryState nullifyRawCategoryFilter() {
    return InventoryState(
      section: section,
      isLoading: isLoading,
      error: error,
      catalog: catalog,
      stock: stock,
      rawQuery: rawQuery,
      rawCategoryIdFilter: null,
      rawLowOnly: rawLowOnly,
      rawSortColumn: rawSortColumn,
      rawSortAscending: rawSortAscending,
      supplyOrders: supplyOrders,
      supplyTab: supplyTab,
      kitchenIssues: kitchenIssues,
      kitchenBatches: kitchenBatches,
      branchOrders: branchOrders,
      stocktakeRecords: stocktakeRecords,
      auditRows: auditRows,
    );
  }
  
  InventoryState setRawCategoryIdFilter(String id) {
    return InventoryState(
      section: section,
      isLoading: isLoading,
      error: error,
      catalog: catalog,
      stock: stock,
      rawQuery: rawQuery,
      rawCategoryIdFilter: id,
      rawLowOnly: rawLowOnly,
      rawSortColumn: rawSortColumn,
      rawSortAscending: rawSortAscending,
      supplyOrders: supplyOrders,
      supplyTab: supplyTab,
      kitchenIssues: kitchenIssues,
      kitchenBatches: kitchenBatches,
      branchOrders: branchOrders,
      stocktakeRecords: stocktakeRecords,
      auditRows: auditRows,
    );
  }

  // --- Helpers for UI ---

  List<InventoryCategory> get rawCategories {
    if (catalog == null) return [];
    return catalog!.categories
        .where((c) => c.kind == CategoryKind.raw)
        .toList();
  }

  List<InventoryItemWithStock> get visibleRawMaterials {
    if (catalog == null) return [];
    
    // Build categories lookup
    final categoriesMap = {
      for (var c in catalog!.categories) c.id: c
    };
    
    // Items already typed
    final allItems = catalog!.items;
    
    // Map stock
    final stockMap = {
      for (var s in stock) s.itemId: s.quantity
    };
    
    var filtered = allItems.map((item) {
      return InventoryItemWithStock(
        item: item,
        stockQty: stockMap[item.id] ?? 0.0,
        category: categoriesMap[item.categoryId],
      );
    }).where((itemWithStock) {
      if (rawLowOnly && !itemWithStock.isLow) return false;
      if (rawCategoryIdFilter != null && itemWithStock.item.categoryId != rawCategoryIdFilter) return false;
      if (rawQuery.isNotEmpty) {
        final query = rawQuery.toLowerCase();
        if (!itemWithStock.item.name.toLowerCase().contains(query) && 
            !itemWithStock.item.sku.toLowerCase().contains(query)) {
          return false;
        }
      }
      // Only show Raw materials in this view (or whatever category logic needed)
      // Usually depends on CategoryKind.raw
      if (itemWithStock.category?.kind != CategoryKind.raw) return false;
      
      return true;
    }).toList();

    if (rawSortColumn != null) {
      filtered.sort((a, b) {
        int cmp = 0;
        switch (rawSortColumn!) {
          case RawSortColumn.sku:
            cmp = a.item.sku.compareTo(b.item.sku);
            break;
          case RawSortColumn.name:
            cmp = a.item.name.compareTo(b.item.name);
            break;
          case RawSortColumn.category:
            cmp = a.categoryLabel.compareTo(b.categoryLabel);
            break;
          case RawSortColumn.stock:
            cmp = a.stockQty.compareTo(b.stockQty);
            break;
        }
        return rawSortAscending ? cmp : -cmp;
      });
    }

    return filtered;
  }

  int get lowStockCount {
    if (catalog == null) return 0;
    int count = 0;
    final stockMap = { for (var s in stock) s.itemId: s.quantity };
    for (var item in catalog!.items) {
      final qty = stockMap[item.id] ?? 0.0;
      if (qty <= item.minLevel && item.minLevel > 0) count++;
    }
    return count;
  }

  int get pendingSupplyCount => supplyOrders.where((o) => o.status == SupplyOrderStatus.pendingReview).length;
  
  int get activeSupplyCount => supplyOrders.where((o) => 
    o.status == SupplyOrderStatus.pendingReview || 
    o.status == SupplyOrderStatus.approved
  ).length;
  
  List<SupplyOrder> supplyOrdersFor(SupplyOrderStatus status) => 
      supplyOrders.where((o) => o.status == status).toList();
      
  int get activeBranchOrdersCount => branchOrders.where((o) => o.status == BranchOrderStatus.approved || o.status == BranchOrderStatus.submitted).length;

  @override
  List<Object?> get props => [
        section, isLoading, error, catalog, stock,
        rawQuery, rawCategoryIdFilter, rawLowOnly, rawSortColumn, rawSortAscending,
        supplyOrders, supplyTab, kitchenIssues, kitchenBatches, branchOrders,
        stocktakeRecords, auditRows,
      ];
}
