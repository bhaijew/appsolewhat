class ProductVariation {
  final String id;
  final String name;
  final double price;
  final bool isDefault;

  ProductVariation({
    required this.id,
    required this.name,
    required this.price,
    this.isDefault = false,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Regular',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isDefault: json['is_default'] == true,
    );
  }
}

class ProductItem {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final bool isAvailable;
  final int? categoryId;
  final int? shopId;
  final List<ProductVariation> variations;

  ProductItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    required this.isAvailable,
    this.categoryId,
    this.shopId,
    this.variations = const [],
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    List<ProductVariation> vars = [];
    if (json['variations'] != null && json['variations'] is List) {
      for (var v in json['variations']) {
        if (v is Map<String, dynamic>) {
          vars.add(ProductVariation.fromJson(v));
        } else if (v is Map) {
          vars.add(ProductVariation.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    return ProductItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      description: json['description']?.toString(),
      isAvailable: json['is_available'] == true,
      categoryId: (json['category_id'] as num?)?.toInt(),
      shopId: (json['shop_id'] as num?)?.toInt(),
      variations: vars,
    );
  }
}
