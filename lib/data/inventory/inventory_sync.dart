import 'package:supabase_flutter/supabase_flutter.dart';

import 'inventory_cache.dart';
import 'models/catalog_snapshot.dart';
import 'models/inventory_category.dart';
import 'models/inventory_item.dart';
import 'models/inventory_unit.dart';
import 'models/stock_entry.dart';

/// طبقة المزامنة بالبصمات (Stamps + Delta)
///
/// آلية العمل عند أول فتح للقسم في الجلسة:
/// 1. اجلب بصمات السيرفر (طلب واحد صغير < 300 بايت)
/// 2. قارن كل بصمة بالمحفوظة محلياً
/// 3. لو متساوية → لا تحميل إضافي
/// 4. لو مختلفة  → جلب delta فقط (صفوف updated_at >= synced_up_to - slack)
///    في حلقة بدفعات 1000 صف، ودمجها مع الكاش
class InventorySync {
  final SupabaseClient _client;
  final InventoryCache _cache;

  InventorySync(this._client, this._cache);

  // ── بصمات ────────────────────────────────────────────────────────────────

  /// جلب بصمات السيرفر لمجموعة مفاتيح
  Future<Map<String, int>> fetchStamps(List<String> keys) async {
    final res = await _client.rpc(
      'inventory_get_stamps',
      params: {'p_keys': keys},
    );
    if (res == null) return {};
    final map = res as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ── مزامنة الكتالوج ───────────────────────────────────────────────────────

  /// أعد الكتالوج من الكاش إذا كانت البصمة محدّثة، وإلا اجلب delta
  Future<CatalogSnapshot> syncCatalog() async {
    final localStamp = await _cache.getStamp(CacheKey.catalog);
    final serverStamps = await fetchStamps([CacheKey.catalog]);
    final serverStamp = serverStamps[CacheKey.catalog] ?? 0;

    if (serverStamp == localStamp && localStamp > 0) {
      // الكاش محدّث — قرأ من SQLite مباشرة
      return _catalogFromCache();
    }

    // جلب كامل أو delta — السيرفر يضيف هامش 10 ثوانٍ على p_since
    final cached = await _cache.get(CacheKey.catalog);
    final since = cached?.syncedUpTo;

    final catalogRes = await _client.rpc(
      'inventory_get_catalog',
      params: {'p_since': ?since},
    );
    final catalogMap = _asMap(catalogRes);
    final allItems = _toMaps(catalogMap['items']);
    final allCats = _toMaps(catalogMap['categories']);
    final allUnits = _toMaps(catalogMap['units']);
    final latestUpdatedAt = _syncTimestamp(catalogMap);

    // دمج مع الكاش الموجود
    if (since != null) {
      await _cache.mergeList(
        key: CacheKey.catalog,
        listField: 'items',
        delta: allItems,
        newStamp: serverStamp,
        newSyncedUpTo:
            latestUpdatedAt ?? DateTime.now().toUtc().toIso8601String(),
      );
      // دمج التصنيفات والوحدات (لا تُحذف — upsert)
      final existing = await _cache.get(CacheKey.catalog);
      final mergedCats = _mergeById(
        existing: _toMaps(
          (existing?.data['categories'] as List<dynamic>?) ?? [],
        ),
        delta: allCats,
      );
      final mergedUnits = _mergeByCode(
        existing: _toMaps((existing?.data['units'] as List<dynamic>?) ?? []),
        delta: allUnits,
      );
      final ex = existing?.data ?? {};
      await _cache.put(
        key: CacheKey.catalog,
        data: {...ex, 'categories': mergedCats, 'units': mergedUnits},
        stamp: serverStamp,
        syncedUpTo: latestUpdatedAt,
      );
    } else {
      // تحميل كامل (أول مرة)
      await _cache.put(
        key: CacheKey.catalog,
        data: {'units': allUnits, 'categories': allCats, 'items': allItems},
        stamp: serverStamp,
        syncedUpTo: latestUpdatedAt,
      );
    }

    return _catalogFromCache();
  }

  /// قراءة الكتالوج من SQLite دون أي شبكة
  Future<CatalogSnapshot> loadCatalogFromCache() => _catalogFromCache();

  Future<CatalogSnapshot> _catalogFromCache() async {
    final entry = await _cache.get(CacheKey.catalog);
    if (entry == null) return CatalogSnapshot.empty;
    final units = _toMaps(
      (entry.data['units'] as List<dynamic>?) ?? [],
    ).map(InventoryUnit.fromJson).toList();
    final cats = _toMaps(
      (entry.data['categories'] as List<dynamic>?) ?? [],
    ).map(InventoryCategory.fromJson).toList();
    final items = _toMaps(
      (entry.data['items'] as List<dynamic>?) ?? [],
    ).map(InventoryItem.fromJson).toList();
    return CatalogSnapshot(
      units: units,
      categories: cats,
      items: items,
      stamp: entry.stamp,
    );
  }

  // ── مزامنة الأرصدة ─────────────────────────────────────────────────────────

  Future<StockSnapshot> syncStock({String? warehouseId}) async {
    final cacheKey = warehouseId != null
        ? CacheKey.branchStock(warehouseId)
        : CacheKey.stock;

    final localStamp = await _cache.getStamp(cacheKey);
    final stampKey = warehouseId != null
        ? 'branch_stock:$warehouseId'
        : CacheKey.stock;
    final serverStamps = await fetchStamps([stampKey]);
    final serverStamp = serverStamps[stampKey] ?? 0;

    if (serverStamp == localStamp && localStamp > 0) {
      return _stockFromCache(cacheKey, localStamp);
    }

    final cached = await _cache.get(cacheKey);
    final since = cached?.syncedUpTo;

    final res = await _client.rpc(
      'inventory_get_stock',
      params: {'p_warehouse_id': ?warehouseId, 'p_since': ?since},
    );
    final stockMap = _asMap(res);

    final delta = _toMaps(stockMap['stock']);
    final latestUpdatedAt = _syncTimestamp(stockMap);

    await _cache.mergeList(
      key: cacheKey,
      listField: 'stock',
      delta: delta,
      newStamp: serverStamp,
      newSyncedUpTo:
          latestUpdatedAt ?? DateTime.now().toUtc().toIso8601String(),
      idField: 'item_id',
    );

    return _stockFromCache(cacheKey, serverStamp);
  }

  Future<StockSnapshot> loadStockFromCache({String? warehouseId}) async {
    final cacheKey = warehouseId != null
        ? CacheKey.branchStock(warehouseId)
        : CacheKey.stock;
    return _stockFromCache(cacheKey, await _cache.getStamp(cacheKey));
  }

  Future<StockSnapshot> _stockFromCache(String cacheKey, int stamp) async {
    final entry = await _cache.get(cacheKey);
    if (entry == null) return StockSnapshot(entries: [], stamp: 0);
    final entries = _toMaps(
      (entry.data['stock'] as List<dynamic>?) ?? [],
    ).map(StockEntry.fromJson).toList();
    return StockSnapshot(entries: entries, stamp: stamp);
  }

  // ── طبّق نتيجة RPC مباشرة على الكاش ───────────────────────────────────────
  // بعد كل عملية كتابة يرجع السيرفر { stock[], stamps } فنطبقها محلياً
  // بدون طلب إضافي

  Future<void> applyRpcResult(Map<String, dynamic> result) async {
    // تحديث الأرصدة المتغيرة
    final stockDelta = _toMaps(result['stock'] as List<dynamic>? ?? []);
    if (stockDelta.isNotEmpty) {
      final latestUpdatedAt = stockDelta
          .map((s) => s['updated_at'] as String? ?? '')
          .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      final stamps = (result['stamps'] as Map<String, dynamic>? ?? {});
      final stockStamp = (stamps[CacheKey.stock] as num?)?.toInt() ?? 0;

      await _cache.mergeList(
        key: CacheKey.stock,
        listField: 'stock',
        delta: stockDelta,
        newStamp: stockStamp,
        newSyncedUpTo: latestUpdatedAt,
        idField: 'item_id',
      );
    }

    // تحديث بصمة الكتالوج إن تغيرت (مثلاً بعد استيراد أصناف)
    final stamps = result['stamps'] as Map<String, dynamic>? ?? {};
    final catStamp = (stamps[CacheKey.catalog] as num?)?.toInt();
    if (catStamp != null) {
      final local = await _cache.getStamp(CacheKey.catalog);
      if (catStamp != local) {
        // علّم الكتالوج كـ dirty (stamp 0) حتى يُعاد تحميله
        final existing = await _cache.get(CacheKey.catalog);
        if (existing != null) {
          await _cache.put(
            key: CacheKey.catalog,
            data: existing.data,
            stamp: 0,
            syncedUpTo: existing.syncedUpTo,
          );
        }
      }
    }
  }

  // ── مسح عند تسجيل الخروج ────────────────────────────────────────────────────
  // الكتالوج لا يُمسح (يُحتفظ به بين الجلسات)

  Future<void> clearSessionData() async {
    await _cache.delete(CacheKey.stock);
  }

  // ── مساعدات داخلية ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _toMaps(dynamic list) {
    if (list == null) return [];
    return (list as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  String? _syncTimestamp(Map<String, dynamic> res) =>
      (res['synced_up_to'] ?? res['fetched_at']) as String?;

  List<Map<String, dynamic>> _mergeById({
    required List<Map<String, dynamic>> existing,
    required List<Map<String, dynamic>> delta,
  }) {
    final map = {for (final r in existing) r['id'] as String: r};
    for (final r in delta) {
      map[r['id'] as String] = r;
    }
    return map.values.toList();
  }

  List<Map<String, dynamic>> _mergeByCode({
    required List<Map<String, dynamic>> existing,
    required List<Map<String, dynamic>> delta,
  }) {
    final map = {for (final r in existing) r['code'] as String: r};
    for (final r in delta) {
      map[r['code'] as String] = r;
    }
    return map.values.toList();
  }
}
