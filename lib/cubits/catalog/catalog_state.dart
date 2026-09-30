import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';

/// حالات الكاتالوج
enum CatalogStatus { initial, loading, loaded, failure }

/// حالة CatalogCubit
class CatalogState extends Equatable {
  final CatalogStatus status;
  final List<ProductCategory> categories;
  final List<Product> products;
  final String? errorMessage;

  const CatalogState({
    this.status = CatalogStatus.initial,
    this.categories = const [],
    this.products = const [],
    this.errorMessage,
  });

  CatalogState copyWith({
    CatalogStatus? status,
    List<ProductCategory>? categories,
    List<Product>? products,
    String? errorMessage,
  }) {
    return CatalogState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ── Getters مساعدة ─────────────────────────────────────────────────────────

  /// تصنيف "الوجبات"
  ProductCategory? get mealsCategory =>
      _findCategory('الوجبات');

  /// تصنيف "الإضافات"
  ProductCategory? get addonsCategory =>
      _findCategory('الإضافات');

  ProductCategory? _findCategory(String name) {
    try {
      return categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// المنتجات النشطة من تصنيف الوجبات (has_variants = true)
  List<Product> get mealProducts {
    final cat = mealsCategory;
    if (cat == null) return [];
    return products
        .where((p) => p.categoryId == cat.id && p.isActive)
        .toList();
  }

  /// المنتجات النشطة من تصنيف الإضافات (has_variants = false)
  List<Product> get addonProducts {
    final cat = addonsCategory;
    if (cat == null) return [];
    return products
        .where((p) => p.categoryId == cat.id && p.isActive)
        .toList();
  }

  @override
  List<Object?> get props =>
      [status, categories, products, errorMessage];
}
