import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/product_model.dart';

class MenuStockTab extends StatefulWidget {
  const MenuStockTab({super.key});

  @override
  State<MenuStockTab> createState() => _MenuStockTabState();
}

class _MenuStockTabState extends State<MenuStockTab> {
  bool _isLoading = true;
  List<ProductItem> _products = [];
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int? _shopId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getInt('shop_id');
    final list = await SupabaseService.instance.fetchProducts(shopId: _shopId);
    if (mounted) {
      setState(() {
        _products = list;
        _isLoading = false;
      });
    }
  }

  void _toggleStock(ProductItem item, bool newValue) async {
    setState(() {
      final idx = _products.indexWhere((p) => p.id == item.id);
      if (idx != -1) {
        _products[idx] = ProductItem(
          id: item.id,
          name: item.name,
          price: item.price,
          imageUrl: item.imageUrl,
          description: item.description,
          isAvailable: newValue,
          categoryId: item.categoryId,
          shopId: item.shopId,
          variations: item.variations,
        );
      }
    });

    final ok = await SupabaseService.instance.toggleProductStock(item.id, newValue);
    if (!ok && mounted) {
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) {
      if (_search.isEmpty) return true;
      return p.name.toLowerCase().contains(_search);
    }).toList();

    return Column(
      children: [
        // Search header (5px Square UI)
        Container(
          color: AppConstants.cardLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppConstants.textDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search food item (e.g. Tikka, Burger, Wings)...',
              hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: AppConstants.textMuted, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppConstants.textMuted, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _search = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppConstants.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: AppConstants.radius5,
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
          ),
        ),

        const Divider(height: 1, color: AppConstants.borderLight),

        // Product Cards List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        _search.isNotEmpty ? 'No items found matching "$_search"' : 'No products found',
                        style: const TextStyle(color: AppConstants.textMuted),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppConstants.primary,
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isAvailable = item.isAvailable;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppConstants.cardLight,
                              borderRadius: AppConstants.radius5,
                              border: Border.all(
                                color: isAvailable ? AppConstants.borderLight : Colors.red.shade200,
                                width: isAvailable ? 1 : 1.2,
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
                                  // Image / Icon
                                  ClipRRect(
                                    borderRadius: AppConstants.radius5,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      color: AppConstants.surfaceLight,
                                      child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                                          ? Image.network(
                                              item.imageUrl!,
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

                                  // Name, Price & Stock Status Badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            color: isAvailable ? AppConstants.textDark : AppConstants.textMuted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            decoration: isAvailable ? null : TextDecoration.lineThrough,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              "${AppConstants.currency}${item.price.toStringAsFixed(0)}",
                                              style: TextStyle(
                                                color: isAvailable ? AppConstants.primary : AppConstants.textMuted,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isAvailable
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.red.withValues(alpha: 0.12),
                                                borderRadius: AppConstants.radius5,
                                              ),
                                              child: Text(
                                                isAvailable ? 'AVAILABLE' : 'OFFLINE',
                                                style: TextStyle(
                                                  color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Toggle Switch
                                  Switch(
                                    value: isAvailable,
                                    activeThumbColor: Colors.green,
                                    activeTrackColor: Colors.green.withValues(alpha: 0.35),
                                    inactiveThumbColor: Colors.red,
                                    inactiveTrackColor: Colors.red.withValues(alpha: 0.25),
                                    onChanged: (val) => _toggleStock(item, val),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
