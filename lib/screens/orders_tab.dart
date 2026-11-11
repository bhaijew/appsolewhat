import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/order_model.dart';
import 'order_detail_screen.dart';

class OrdersTab extends StatefulWidget {
  final VoidCallback? onOpenVerify;
  const OrdersTab({super.key, this.onOpenVerify});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Date Filter Mode: null = Today (Realtime live stream), or specific DateTime
  DateTime? _selectedDate;
  bool _isLoadingDateOrders = false;
  List<PizzaOrder> _dateOrders = [];
  int? _shopId;

  final List<Map<String, String>> _statusFilters = [
    {'key': 'all', 'label': 'All Orders'},
    {'key': 'pending', 'label': 'Pending ⏳'},
    {'key': 'preparing', 'label': 'Kitchen 🔥'},
    {'key': 'out_for_delivery', 'label': 'On Way 🛵'},
    {'key': 'delivered', 'label': 'Delivered ✅'},
    {'key': 'cancelled', 'label': 'Cancelled ❌'},
  ];

  Map<String, dynamic>? _shiftBoundary;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.realtimeUpdateNotifier.addListener(_onRealtimeUpdate);
    _loadShopId();
  }

  void _onRealtimeUpdate() {
    if (mounted) {
      _refreshShiftBoundary();
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.realtimeUpdateNotifier.removeListener(_onRealtimeUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _shopId = prefs.getInt('shop_id'));
      _refreshShiftBoundary();
    }
  }

  Future<void> _refreshShiftBoundary() async {
    final boundary = await SupabaseService.instance.fetchActiveShiftBoundary(shopId: _shopId);
    if (mounted) {
      final oldStart = _shiftBoundary?['activeShiftStart'];
      final newStart = boundary['activeShiftStart'];
      if (oldStart != newStart || _shiftBoundary == null) {
        setState(() => _shiftBoundary = boundary);
      } else {
        _shiftBoundary = boundary;
      }
    }
  }

  void _loadDateOrders(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoadingDateOrders = true;
    });
    final orders = await SupabaseService.instance.fetchOrdersByDate(
      date,
      shopId: _shopId,
    );
    if (mounted) {
      setState(() {
        _dateOrders = orders;
        _isLoadingDateOrders = false;
      });
    }
  }

  void _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConstants.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppConstants.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _loadDateOrders(picked);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppConstants.statusPending;
      case 'preparing':
        return AppConstants.statusPreparing;
      case 'ready':
      case 'out_for_delivery':
        return AppConstants.statusDelivery;
      case 'delivered':
        return AppConstants.statusDelivered;
      case 'cancelled':
        return AppConstants.statusCancelled;
      default:
        return AppConstants.textMuted;
    }
  }

  void _callCustomer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openWhatsApp(String? phone, String orderNum) async {
    if (phone == null || phone.trim().isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '92${clean.substring(1)}';
    final text = Uri.encodeComponent(
      "Salam! Regarding your Sole What Order #$orderNum.",
    );
    final uri = Uri.parse("https://wa.me/$clean?text=$text");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top White Card: Date Switcher & Search
        Container(
          color: AppConstants.cardLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              // Date Switcher Row (Today Live, Yesterday, Pick Date)
              Row(
                children: [
                  _dateChip(
                    label: '⚡ Live Today',
                    isSelected: _selectedDate == null,
                    onTap: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _dateChip(
                    label: 'Yesterday',
                    isSelected:
                        _selectedDate != null &&
                        _isSameDay(
                          _selectedDate!,
                          DateTime.now().subtract(const Duration(days: 1)),
                        ),
                    onTap: () {
                      _loadDateOrders(
                        DateTime.now().subtract(const Duration(days: 1)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _dateChip(
                    label:
                        _selectedDate != null &&
                            !_isSameDay(
                              _selectedDate!,
                              DateTime.now().subtract(const Duration(days: 1)),
                            )
                        ? DateFormat('dd MMM').format(_selectedDate!)
                        : '📅 Pick Date',
                    isSelected:
                        _selectedDate != null &&
                        !_isSameDay(
                          _selectedDate!,
                          DateTime.now().subtract(const Duration(days: 1)),
                        ),
                    onTap: _pickCustomDate,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Search Bar with 5px Square corners
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                  color: AppConstants.textDark,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Order #, Customer, Phone...',
                  hintStyle: const TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppConstants.textMuted,
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppConstants.textMuted,
                            size: 16,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchCtrl.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppConstants.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppConstants.radius5,
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
              ),

              const SizedBox(height: 10),

              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((f) {
                    final isSelected = _selectedFilter == f['key'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedFilter = f['key']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppConstants.primary
                                : AppConstants.surfaceLight,
                            borderRadius: AppConstants.radius5,
                            border: Border.all(
                              color: isSelected
                                  ? AppConstants.primary
                                  : AppConstants.borderLight,
                            ),
                          ),
                          child: Text(
                            f['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppConstants.textBody,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppConstants.borderLight),

        // Orders View (Live Stream vs Historical Date Query)
        Expanded(
          child: _selectedDate == null
              ? StreamBuilder<List<PizzaOrder>>(
                  stream: SupabaseService.instance.streamOrders(
                    shopId: _shopId,
                  ),
                  initialData: SupabaseService.instance.latestCachedOrders.isNotEmpty
                      ? SupabaseService.instance.latestCachedOrders
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primary,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Internet Connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Please check your WiFi or mobile data to reconnect live orders.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                                  elevation: 0,
                                ),
                                onPressed: () => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final orders = snapshot.data ?? [];
                    DateTime? shiftStart = _shiftBoundary?['activeShiftStart'] as DateTime?;
                    final unverifiedCount = orders.where((o) {
                      final st = o.status.toLowerCase();
                      if (shiftStart != null && o.createdAt.isBefore(shiftStart)) return false;
                      if (st == 'cancelled' || st == 'delivered' || st == 'preparing' || st == 'out_for_delivery') {
                        return false;
                      }
                      return !o.isVerified ||
                          (o.notes != null && o.notes!.contains('[ONLINE_MENU: AWAITING_VERIFICATION]'));
                    }).length;

                    return Column(
                      children: [
                        if (unverifiedCount > 0 && _selectedDate == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                            child: InkWell(
                              onTap: widget.onOpenVerify,
                              borderRadius: AppConstants.radius5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: AppConstants.radius5,
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$unverifiedCount Online Order${unverifiedCount > 1 ? 's' : ''} Awaiting Verification!',
                                        style: const TextStyle(
                                          color: Color(0xFF92400E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: AppConstants.radius5,
                                      ),
                                      child: const Text(
                                        'Verify →',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Expanded(child: _buildOrderList(orders)),
                      ],
                    );
                  },
                )
              : _isLoadingDateOrders
              ? const Center(
                  child: CircularProgressIndicator(color: AppConstants.primary),
                )
              : _buildOrderList(_dateOrders),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _dateChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppConstants.radius5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.textDark : AppConstants.surfaceLight,
          borderRadius: AppConstants.radius5,
          border: Border.all(
            color: isSelected
                ? AppConstants.textDark
                : AppConstants.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppConstants.textBody,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(List<PizzaOrder> allOrders) {
    DateTime? shiftStart = _shiftBoundary?['activeShiftStart'] as DateTime?;
    if (shiftStart == null) {
      final now = DateTime.now();
      shiftStart = now.hour < 5
          ? DateTime(now.year, now.month, now.day - 1, 11, 0, 0)
          : DateTime(now.year, now.month, now.day, 5, 0, 0);
    }

    final filtered = allOrders.where((order) {
      // 0. Hold back unverified online orders from Live Board! (They belong in Verify tab)
      if (!order.isVerified || (order.notes != null && order.notes!.contains('[ONLINE_MENU: AWAITING_VERIFICATION]'))) {
        return false;
      }

      // 1. If in "Live Today" mode, strictly filter out orders placed before active shift start!
      if (_selectedDate == null) {
        if (order.createdAt.isBefore(shiftStart!)) {
          return false;
        }
      }

      // 2. Branch isolation check
      if (_shopId != null && order.shopId != null && order.shopId != _shopId) {
        return false;
      }

      // 3. Status filter
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'pending' && order.status != 'pending')
          return false;
        if (_selectedFilter == 'preparing' && order.status != 'preparing')
          return false;
        if (_selectedFilter == 'out_for_delivery' &&
            order.status != 'out_for_delivery' &&
            order.status != 'ready')
          return false;
        if (_selectedFilter == 'delivered' && order.status != 'delivered')
          return false;
        if (_selectedFilter == 'cancelled' && order.status != 'cancelled')
          return false;
      }

      // 4. Search query
      if (_searchQuery.isNotEmpty) {
        final matchNum = order.orderNumber.toLowerCase().contains(_searchQuery);
        final matchName = order.customerName.toLowerCase().contains(
          _searchQuery,
        );
        final matchPhone = (order.customerPhone ?? '').toLowerCase().contains(
          _searchQuery,
        );
        return matchNum || matchName || matchPhone;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      final bool isRegisterClosed = _shiftBoundary?['isClosed'] == true && _selectedDate == null;
      final String businessDate = _shiftBoundary?['businessDate']?.toString() ?? '';

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRegisterClosed ? Icons.lock_clock_outlined : Icons.receipt_long_outlined,
                size: 54,
                color: isRegisterClosed
                    ? Colors.green.withValues(alpha: 0.6)
                    : AppConstants.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                isRegisterClosed
                    ? 'Register Closed for Today ($businessDate)'
                    : (_searchQuery.isNotEmpty
                        ? 'No matching orders found'
                        : _selectedDate == null
                            ? 'No active orders in this shift yet'
                            : 'No orders logged on this date'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isRegisterClosed ? FontWeight.bold : FontWeight.normal,
                  color: isRegisterClosed ? Colors.green.shade900 : AppConstants.textDark,
                  fontSize: 14,
                ),
              ),
              if (isRegisterClosed) ...[
                const SizedBox(height: 6),
                const Text(
                  'The daily register has been closed and reconciled. New orders arriving for the next shift will appear here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RawScrollbar(
      thumbColor: Colors.black.withValues(alpha: 0.16),
      radius: const Radius.circular(8),
      thickness: 4.0,
      interactive: true,
      fadeDuration: const Duration(milliseconds: 300),
      timeToFade: const Duration(milliseconds: 1200),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          return _build5pxOrderCard(order);
        },
      ),
    );
  }

  Widget _build5pxOrderCard(PizzaOrder order) {
    final statusColor = _getStatusColor(order.status);
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);
    final isPending = order.status == 'pending';
    final isPreparing = order.status == 'preparing';
    final isDelivery = order.orderType == 'delivery';
    final isCash = order.paymentMethod.contains('cash');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - anim)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppConstants.cardLight,
          borderRadius: AppConstants.radius5,
          border: Border.all(
            color: isPending
                ? AppConstants.statusPending.withValues(alpha: 0.6)
                : AppConstants.borderLight,
            width: isPending ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: AppConstants.radius5,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => OrderDetailScreen(order: order),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Number + Date + Status + Cash/Online Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.primary.withValues(alpha: 0.08),
                            borderRadius: AppConstants.radius5,
                            border: Border.all(
                              color: AppConstants.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            order.orderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppConstants.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        // Cash vs Online tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isCash
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: AppConstants.radius5,
                          ),
                          child: Text(
                            isCash ? '💵 Cash' : '💳 Online',
                            style: TextStyle(
                              color: isCash
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status Badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: AppConstants.radius5,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        (order.status == 'out_for_delivery' || order.status == 'ready')
                            ? (order.orderType == 'delivery' ? 'ON WAY' : 'READY')
                            : order.status.replaceAll('_', ' ').toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Customer & Order Type Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              color: AppConstants.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (order.customerPhone != null &&
                              order.customerPhone!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                order.customerPhone!,
                                style: const TextStyle(
                                  color: AppConstants.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Order Type Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceLight,
                        borderRadius: AppConstants.radius5,
                        border: Border.all(color: AppConstants.borderLight),
                      ),
                      child: Text(
                        order.orderType == 'dine_in'
                            ? '🍽️ Table ${order.tableNumber ?? ""}'
                            : order.orderType == 'delivery'
                            ? '🛵 Delivery'
                            : '🥡 Token ${order.tokenNumber ?? ""}',
                        style: const TextStyle(
                          color: AppConstants.textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // Items summary
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: order.items.map((it) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Text(
                                "${it.qty}x ",
                                style: const TextStyle(
                                  color: AppConstants.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  "${it.name}${it.variationName != null ? " (${it.variationName})" : ""}",
                                  style: const TextStyle(
                                    color: AppConstants.textDark,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                "${AppConstants.currency}${(it.price * it.qty).toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppConstants.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Total & Fast Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Bill',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "${AppConstants.currency}${order.total.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppConstants.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Action Buttons
                    Row(
                      children: [
                        if (order.customerPhone != null &&
                            order.customerPhone!.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.phone,
                              color: Colors.green,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _callCustomer(order.customerPhone),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.chat,
                              color: Colors.teal,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _openWhatsApp(
                              order.customerPhone,
                              order.orderNumber,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        if (isPending)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.soup_kitchen, size: 14),
                            label: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppConstants.radius5,
                              ),
                            ),
                            onPressed: () async {
                              await SupabaseService.instance.updateOrderStatus(
                                order.id,
                                'preparing',
                              );
                            },
                          )
                        else if (isPreparing)
                          ElevatedButton.icon(
                            icon: Icon(
                              isDelivery
                                  ? Icons.delivery_dining
                                  : Icons.check_circle,
                              size: 14,
                            ),
                            label: Text(
                              isDelivery ? 'Dispatch' : 'Deliver',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDelivery
                                  ? Colors.deepPurple
                                  : Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppConstants.radius5,
                              ),
                            ),
                            onPressed: () async {
                              final next = isDelivery
                                  ? 'ready'
                                  : 'delivered';
                              await SupabaseService.instance.updateOrderStatus(
                                order.id,
                                next,
                              );
                            },
                          )
                        else if ((order.status == 'ready' || order.status == 'out_for_delivery') && isDelivery)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 14),
                            label: const Text(
                              'Delivered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppConstants.radius5,
                              ),
                            ),
                            onPressed: () async {
                              await SupabaseService.instance.updateOrderStatus(
                                order.id,
                                'delivered',
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
