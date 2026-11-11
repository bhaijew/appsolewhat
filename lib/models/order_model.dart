class OrderItem {
  final String name;
  final double price;
  final int qty;
  final String? variationName;
  final List<String> toppings;

  OrderItem({
    required this.name,
    required this.price,
    required this.qty,
    this.variationName,
    this.toppings = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? varName;
    if (json['selected_variation'] != null &&
        json['selected_variation'] is Map) {
      varName = json['selected_variation']['name']?.toString();
    } else if (json['selected_variation'] != null) {
      varName = json['selected_variation'].toString();
    } else if (json['variant_selection'] != null) {
      varName = json['variant_selection'].toString();
    } else if (json['size'] != null) {
      varName = json['size'].toString();
    } else if (json['variant'] != null) {
      varName = json['variant'].toString();
    } else if (json['variation'] != null) {
      varName = json['variation'].toString();
    }

    List<String> topList = [];
    if (json['selected_toppings'] != null && json['selected_toppings'] is List) {
      for (var top in json['selected_toppings']) {
        if (top is Map && top['name'] != null) {
          topList.add(top['name'].toString());
        } else if (top is String) {
          topList.add(top);
        }
      }
    }

    return OrderItem(
      name: json['name']?.toString() ?? json['product_name']?.toString() ?? 'Item',
      price: (json['price'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      qty: (json['qty'] as num?)?.toInt() ??
          (json['quantity'] as num?)?.toInt() ??
          1,
      variationName: varName,
      toppings: topList,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'product_name': name,
        'price': price,
        'unit_price': price,
        'qty': qty,
        'quantity': qty,
        if (variationName != null && variationName!.trim().isNotEmpty) ...{
          'variation': variationName!.trim(),
          'variant': variationName!.trim(),
          'size': variationName!.trim(),
          'selected_variation': variationName!.trim(),
          'variant_selection': variationName!.trim(),
        },
        'selected_toppings': toppings,
      };
}

class PizzaOrder {
  final int id;
  final String orderNumber;
  final String status;
  final String customerName;
  final String? customerPhone;
  final double total;
  final String orderType;
  final String? tableNumber;
  final String? tokenNumber;
  final String? deliveryAddress;
  final double deliveryFee;
  final String? notes;
  final DateTime createdAt;
  final int? shopId;
  final String paymentMethod;
  final String paymentStatus;
  final String source;
  final bool isVerified;
  final List<OrderItem> items;

  PizzaOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.customerName,
    this.customerPhone,
    required this.total,
    required this.orderType,
    this.tableNumber,
    this.tokenNumber,
    this.deliveryAddress,
    this.deliveryFee = 0.0,
    this.notes,
    required this.createdAt,
    this.shopId,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'paid',
    this.source = 'pos',
    this.isVerified = true,
    required this.items,
  });

  factory PizzaOrder.fromJson(Map<String, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] != null && json['items'] is List) {
      for (var it in json['items']) {
        if (it is Map<String, dynamic>) {
          parsedItems.add(OrderItem.fromJson(it));
        }
      }
    }

    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawSource = json['source']?.toString().toLowerCase() ?? 'pos';
    final rawNotes = json['notes']?.toString() ?? '';
    final bool hasAwaitingTag = rawNotes.contains('[ONLINE_MENU: AWAITING_VERIFICATION]');
    final bool rawVerified = !hasAwaitingTag &&
        (json['is_verified'] == true ||
            (json['is_verified'] == null && rawSource != 'online_menu'));

    return PizzaOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? 'ORD-000',
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      customerName: json['customer_name']?.toString() ?? 'Walk-in Customer',
      customerPhone: json['customer_phone']?.toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      orderType: json['order_type']?.toString() ?? 'takeaway',
      tableNumber: json['table_number']?.toString(),
      tokenNumber: json['token_number']?.toString(),
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: parsedDate,
      shopId: (json['shop_id'] as num?)?.toInt(),
      paymentMethod: json['payment_method']?.toString().toLowerCase() ?? 'cash',
      paymentStatus: json['payment_status']?.toString().toLowerCase() ?? 'paid',
      source: rawSource,
      isVerified: rawVerified,
      items: parsedItems,
    );
  }
}
