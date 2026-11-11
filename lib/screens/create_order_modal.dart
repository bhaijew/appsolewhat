import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class CreateOrderModal extends StatefulWidget {
  final PizzaOrder? recreateOrder;
  const CreateOrderModal({super.key, this.recreateOrder});

  @override
  State<CreateOrderModal> createState() => _CreateOrderModalState();
}

class _CreateOrderModalState extends State<CreateOrderModal> {
  String _orderType = 'takeaway'; // dine_in, takeaway, delivery
  final TextEditingController _nameCtrl = TextEditingController(text: 'Walk-in Customer');
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _tableCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _feeCtrl = TextEditingController(text: '0');
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _paymentMethod = 'cash'; // cash, online

  List<ProductItem> _allProducts = [];
  bool _isLoadingProducts = true;
  final List<OrderItem> _cart = [];
  bool _isSubmitting = false;
  int? _shopId;

  @override
  void initState() {
    super.initState();
    if (widget.recreateOrder != null) {
      final o = widget.recreateOrder!;
      _orderType = o.orderType;
      _nameCtrl.text = o.customerName;
      _phoneCtrl.text = o.customerPhone ?? '';
      _tableCtrl.text = o.tableNumber ?? '';
      _addressCtrl.text = o.deliveryAddress ?? '';
      _feeCtrl.text = o.deliveryFee > 0 ? o.deliveryFee.toStringAsFixed(0) : '0';
      _paymentMethod = o.paymentMethod.toLowerCase().contains('online') ? 'online' : 'cash';
      for (final it in o.items) {
        _cart.add(OrderItem(
          name: it.name,
          price: it.price,
          qty: it.qty,
          variationName: it.variationName,
          toppings: it.toppings,
        ));
      }
    }
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getInt('shop_id');
    final prods = await SupabaseService.instance.fetchProducts(shopId: _shopId);
    if (mounted) {
      setState(() {
        _allProducts = prods.where((p) => p.isAvailable).toList();
        _isLoadingProducts = false;
      });
    }
  }

  void _addItemToCart(ProductItem product) {
    if (product.variations.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppConstants.cardLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Size for ${product.name}",
                  style: const TextStyle(
                    color: AppConstants.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...product.variations.map((v) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        v.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      trailing: Text(
                        "${AppConstants.currency}${v.price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _cart.add(
                            OrderItem(
                              name: product.name,
                              price: v.price > 0 ? v.price : product.price,
                              qty: 1,
                              variationName: v.name,
                            ),
                          );
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );
    } else {
      setState(() {
        _cart.add(
          OrderItem(
            name: product.name,
            price: product.price,
            qty: 1,
          ),
        );
      });
    }
  }

  double get _subtotal {
    return _cart.fold<double>(0.0, (acc, it) => acc + (it.price * it.qty));
  }

  double get _deliveryFee {
    if (_orderType != 'delivery') return 0.0;
    return double.tryParse(_feeCtrl.text.trim()) ?? 0.0;
  }

  double get _total => _subtotal + _deliveryFee;

  void _submitOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 item to the order.')),
      );
      return;
    }

    final name = _nameCtrl.text.trim().isEmpty ? 'Walk-in Customer' : _nameCtrl.text.trim();
    final isRecreating = widget.recreateOrder != null;

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> res;
    if (isRecreating) {
      // Recreate existing order with SAME ID & SAME Order Number
      res = await SupabaseService.instance.updateExistingOrder(
        orderId: widget.recreateOrder!.id,
        orderNumber: widget.recreateOrder!.orderNumber,
        customerName: name,
        customerPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        orderType: _orderType,
        tableNumber: _orderType == 'dine_in' ? _tableCtrl.text.trim() : null,
        tokenNumber: widget.recreateOrder!.tokenNumber,
        deliveryAddress: _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
        deliveryFee: _deliveryFee,
        items: _cart,
        total: _total,
        paymentMethod: _paymentMethod,
        existingNotes: widget.recreateOrder!.notes,
        shopId: _shopId ?? widget.recreateOrder!.shopId,
      );
    } else {
      // Create fresh new order
      res = await SupabaseService.instance.createOrder(
        customerName: name,
        customerPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        orderType: _orderType,
        tableNumber: _orderType == 'dine_in' ? _tableCtrl.text.trim() : null,
        deliveryAddress: _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
        deliveryFee: _deliveryFee,
        items: _cart,
        total: _total,
        paymentMethod: _paymentMethod,
        shopId: _shopId,
      );
    }

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      final ordNum = res['orderNumber'] ?? (isRecreating ? widget.recreateOrder!.orderNumber : '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRecreating
                ? '✓ Order #$ordNum Recreated & Updated! (Same ID preserved) Sent to Kitchen 🔥'
                : '✓ Order $ordNum Created Successfully! Sent to Kitchen 🔥',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order: ${res['message'] ?? 'Network or DB error'}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecreating = widget.recreateOrder != null;
    final filtered = _allProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        backgroundColor: AppConstants.cardLight,
        elevation: 0,
        title: Text(
          isRecreating
              ? 'Recreate Order #${widget.recreateOrder!.orderNumber}'
              : 'Create POS Order',
          style: const TextStyle(
            color: AppConstants.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppConstants.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RawScrollbar(
              thumbColor: Colors.black.withValues(alpha: 0.16),
              radius: const Radius.circular(8),
              thickness: 4.0,
              interactive: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Type Selector (5px square)
                  Row(
                    children: [
                      _typeButton('takeaway', '🥡 Takeaway'),
                      const SizedBox(width: 8),
                      _typeButton('dine_in', '🍽️ Dine-In'),
                      const SizedBox(width: 8),
                      _typeButton('delivery', '🛵 Delivery'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Customer Details Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.cardLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                                decoration: InputDecoration(
                                  labelText: 'Customer Name',
                                  labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                  filled: true,
                                  fillColor: AppConstants.surfaceLight,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: AppConstants.radius5,
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                  filled: true,
                                  fillColor: AppConstants.surfaceLight,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: AppConstants.radius5,
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_orderType == 'dine_in') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tableCtrl,
                            style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                            decoration: InputDecoration(
                              labelText: 'Table Number (e.g. Table 3)',
                              labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              filled: true,
                              fillColor: AppConstants.surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: AppConstants.radius5,
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ] else if (_orderType == 'delivery') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addressCtrl,
                            style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                            decoration: InputDecoration(
                              labelText: 'Delivery Address',
                              labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              filled: true,
                              fillColor: AppConstants.surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: AppConstants.radius5,
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _feeCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                            decoration: InputDecoration(
                              labelText: 'Delivery Fee (Rs.)',
                              labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              filled: true,
                              fillColor: AppConstants.surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: AppConstants.radius5,
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 🔍 PRODUCT SEARCH BAR (Requested Feature)
                  Container(
                    decoration: BoxDecoration(
                      color: AppConstants.cardLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search from ${_allProducts.length} menu items (Tikka, Fajita, Deal)...',
                        hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: AppConstants.primary, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Products List (Proper 5px Square responsive cards)
                  _isLoadingProducts
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: AppConstants.primary),
                        ))
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text('No food item matching "$_searchQuery"',
                                    style: const TextStyle(color: AppConstants.textMuted)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final p = filtered[i];
                                final hasVars = p.variations.isNotEmpty;

                                final inCartCount = _cart
                                    .where((it) => it.name == p.name || it.name.startsWith("${p.name} ("))
                                    .fold<int>(0, (sum, it) => sum + it.qty);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppConstants.cardLight,
                                    borderRadius: AppConstants.radius5,
                                    border: Border.all(
                                      color: inCartCount > 0 ? AppConstants.primary.withValues(alpha: 0.4) : AppConstants.borderLight,
                                      width: inCartCount > 0 ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Product Thumbnail (Clean 50x50 with rounded border)
                                        ClipRRect(
                                          borderRadius: AppConstants.radius5,
                                          child: Container(
                                            width: 50,
                                            height: 50,
                                            color: AppConstants.surfaceLight,
                                            child: p.imageUrl != null && p.imageUrl!.startsWith('http')
                                                ? Image.network(
                                                    p.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, st) => const Icon(
                                                      Icons.local_pizza,
                                                      color: AppConstants.primary,
                                                      size: 24,
                                                    ),
                                                  )
                                                : const Icon(Icons.local_pizza, color: AppConstants.primary, size: 24),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Product Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      p.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color: AppConstants.textDark,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (inCartCount > 0)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade700,
                                                        borderRadius: AppConstants.radius5,
                                                      ),
                                                      child: Text(
                                                        '$inCartCount in cart',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (hasVars)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppConstants.surfaceLight,
                                                    borderRadius: AppConstants.radius5,
                                                    border: Border.all(color: AppConstants.borderLight),
                                                  ),
                                                  child: Text(
                                                    "${p.variations.length} Sizes (${p.variations.map((v) => v.name).join(', ')})",
                                                    style: const TextStyle(
                                                      color: AppConstants.textMuted,
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  "${AppConstants.currency}${p.price.toStringAsFixed(0)}",
                                                  style: const TextStyle(
                                                    color: AppConstants.primary,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Action Button: Add or Select Size
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasVars ? AppConstants.textDark : AppConstants.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                                            minimumSize: const Size(0, 34),
                                          ),
                                          onPressed: () => _addItemToCart(p),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(hasVars ? Icons.tune : Icons.add, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                hasVars ? 'Select Size' : 'Add',
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                  const SizedBox(height: 14),

                  // Current Cart Items Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.cardLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ORDER ITEMS IN CART',
                              style: TextStyle(
                                color: AppConstants.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_cart.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _cart.clear()),
                                child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_cart.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Cart is empty. Tap items above to add.',
                                style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ..._cart.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: AppConstants.textDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (item.variationName != null)
                                          Text("Size: ${item.variationName}",
                                              style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        if (item.qty > 1) {
                                          _cart[idx] = OrderItem(
                                            name: item.name,
                                            price: item.price,
                                            qty: item.qty - 1,
                                            variationName: item.variationName,
                                          );
                                        } else {
                                          _cart.removeAt(idx);
                                        }
                                      });
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('${item.qty}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 16, color: AppConstants.primary),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _cart[idx] = OrderItem(
                                          name: item.name,
                                          price: item.price,
                                          qty: item.qty + 1,
                                          variationName: item.variationName,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${AppConstants.currency}${(item.price * item.qty).toStringAsFixed(0)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment method selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.cardLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Channel:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppConstants.textDark),
                        ),
                        Row(
                          children: [
                            _payPill('cash', '💵 Cash'),
                            const SizedBox(width: 8),
                            _payPill('online', '💳 Online'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),

          // Sticky Bottom Checkout Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppConstants.cardLight,
              border: Border(top: BorderSide(color: AppConstants.borderLight)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total Payable', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                      Text(
                        "${AppConstants.currency}${_total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox.shrink()
                            : const Icon(Icons.soup_kitchen, size: 16),
                        label: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isRecreating ? 'Update & Recreate Order 🔥' : 'Confirm & Kitchen 🔥',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                        ),
                        onPressed: _isSubmitting ? null : _submitOrder,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String typeKey, String label) {
    final isSel = _orderType == typeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _orderType = typeKey),
        borderRadius: AppConstants.radius5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? AppConstants.textDark : AppConstants.cardLight,
            borderRadius: AppConstants.radius5,
            border: Border.all(
              color: isSel ? AppConstants.textDark : AppConstants.borderLight,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSel ? Colors.white : AppConstants.textBody,
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payPill(String key, String label) {
    final isSel = _paymentMethod == key;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = key),
      borderRadius: AppConstants.radius5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? (key == 'cash' ? Colors.green.shade700 : Colors.blue.shade700) : AppConstants.surfaceLight,
          borderRadius: AppConstants.radius5,
          border: Border.all(
            color: isSel ? Colors.transparent : AppConstants.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : AppConstants.textDark,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
