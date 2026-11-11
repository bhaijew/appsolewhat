import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/order_model.dart';
import 'create_order_modal.dart';

class OrderDetailScreen extends StatefulWidget {
  final PizzaOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String _currentStatus;
  String? _assignedRiderInfo;
  bool _isUpdating = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _assignedRiderInfo = _extractRiderInfo(widget.order.notes);
  }

  String? _extractRiderInfo(String? notes) {
    if (notes == null || !notes.contains('[RIDER:')) return null;
    final match = RegExp(r'\[RIDER:\s*([^\]|]+)(?:\|\s*([^\]]+))?\]').firstMatch(notes);
    if (match != null) {
      final name = match.group(1)?.trim() ?? '';
      final phone = match.group(2)?.trim();
      if (phone != null && phone.isNotEmpty) {
        return '$name • $phone';
      }
      return name;
    }
    return null;
  }

  String? _extractRiderPhone(String? notes) {
    if (notes == null || !notes.contains('[RIDER:')) return null;
    final match = RegExp(r'\[RIDER:\s*([^\]|]+)(?:\|\s*([^\]]+))?\]').firstMatch(notes);
    return match?.group(2)?.trim();
  }

  void _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final success = await SupabaseService.instance
        .updateOrderStatus(widget.order.id, newStatus);
    setState(() {
      _isUpdating = false;
      if (success) _currentStatus = newStatus;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Status updated to $newStatus' : 'Failed to update status'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCounterPrint(String type) async {
    setState(() => _isPrinting = true);
    final label = type == 'bill' ? 'Customer Bill' : 'Kitchen KOT';
    final success = await SupabaseService.instance.triggerCounterPrint(
      widget.order.id,
      type: type,
    );
    setState(() => _isPrinting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.print, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? '$label sent to Counter POS printer!'
                      : 'Failed to send print request',
                ),
              ),
            ],
          ),
          backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openRecreateOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderModal(recreateOrder: widget.order),
        fullscreenDialog: true,
      ),
    );
  }

  void _showAssignRiderSheet() async {
    final riderCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    // Fetch riders
    final riders = await SupabaseService.instance.fetchDeliveryRiders(
      shopId: widget.order.shopId,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppConstants.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.delivery_dining, color: Colors.deepPurple, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Assign Delivery Rider',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #${widget.order.orderNumber} • ${widget.order.customerName}',
                      style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                    ),
                    const Divider(height: 24, color: AppConstants.borderLight),

                    if (riders.isNotEmpty) ...[
                      const Text(
                        'SAVED RIDERS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...riders.map((r) {
                        final rName = r['name']?.toString() ?? 'Rider';
                        final rPhone = r['phone']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceLight,
                            borderRadius: AppConstants.radius5,
                            border: Border.all(color: AppConstants.borderLight),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.deepPurple,
                              child: Icon(Icons.person, color: Colors.white, size: 16),
                            ),
                            title: Text(
                              rName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppConstants.textDark,
                              ),
                            ),
                            subtitle: rPhone.isNotEmpty
                                ? Text(rPhone, style: const TextStyle(fontSize: 11, color: AppConstants.textMuted))
                                : null,
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                              ),
                              child: const Text('Assign', style: TextStyle(color: Colors.white, fontSize: 11)),
                              onPressed: () async {
                                Navigator.pop(modalCtx);
                                await _doAssignRider(rName, rPhone);
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    const Text(
                      'OR ENTER NEW RIDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: riderCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rider Name (e.g. Ali Raza)',
                        hintStyle: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        border: OutlineInputBorder(borderRadius: AppConstants.radius5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Rider Phone (optional)',
                        hintStyle: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: AppConstants.radius5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Assign & Dispatch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                        ),
                        onPressed: () async {
                          final name = riderCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter rider name')),
                            );
                            return;
                          }
                          Navigator.pop(modalCtx);
                          await _doAssignRider(name, phoneCtrl.text.trim());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _doAssignRider(String name, String phone) async {
    setState(() => _isUpdating = true);
    final ok = await SupabaseService.instance.assignRiderToOrder(
      widget.order.id,
      name,
      phone,
      shopId: widget.order.shopId,
    );
    setState(() {
      _isUpdating = false;
      if (ok) {
        _currentStatus = 'ready';
        _assignedRiderInfo = phone.isNotEmpty ? '$name • $phone' : name;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '🛵 Rider "$name" assigned! Order is Out for Delivery.' : 'Failed to assign rider',
          ),
          backgroundColor: ok ? Colors.deepPurple : Colors.red,
        ),
      );
    }
  }

  void _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openWhatsApp(String? phone, String orderNum) async {
    if (phone == null || phone.isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '92${clean.substring(1)}';
    final text = Uri.encodeComponent("Salam! Regarding your Sole What Order #$orderNum.");
    final uri = Uri.parse("https://wa.me/$clean?text=$text");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(order.createdAt);
    final isCash = order.paymentMethod.contains('cash');
    final isDelivery = order.orderType == 'delivery';

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        backgroundColor: AppConstants.cardLight,
        elevation: 0,
        title: Text(
          order.orderNumber,
          style: const TextStyle(
            color: AppConstants.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCash ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
              borderRadius: AppConstants.radius5,
            ),
            child: Center(
              child: Text(
                isCash ? '💵 Cash' : '💳 Online',
                style: TextStyle(
                  color: isCash ? Colors.green.shade800 : Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Switcher Bar (5px square UI)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UPDATE ORDER STATUS',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _statusChip('pending', 'Pending ⏳', AppConstants.statusPending),
                      _statusChip('preparing', 'Kitchen 🔥', AppConstants.statusPreparing),
                      _statusChip('out_for_delivery', 'On Way 🛵', AppConstants.statusDelivery),
                      _statusChip('delivered', 'Delivered ✅', AppConstants.statusDelivered),
                      _statusChip('cancelled', 'Cancel ❌', AppConstants.statusCancelled),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // QUICK ACTIONS: Counter Thermal Print & Recreate Order
            Container(
              padding: const EdgeInsets.all(14),
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
                        'COUNTER POS PRINTER (OPTION A)',
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (_isPrinting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.receipt, size: 16),
                          label: const Text('Customer Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.primary,
                            side: const BorderSide(color: AppConstants.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                          ),
                          onPressed: _isPrinting ? null : () => _handleCounterPrint('bill'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.soup_kitchen, size: 16),
                          label: const Text('Kitchen KOT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                          ),
                          onPressed: _isPrinting ? null : () => _handleCounterPrint('kot'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Recreate This Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.textDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                      ),
                      onPressed: _openRecreateOrder,
                    ),
                  ),
                ],
              ),
            ),

            if (isDelivery) ...[
              const SizedBox(height: 14),
              // Rider Assignment Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.cardLight,
                  borderRadius: AppConstants.radius5,
                  border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.delivery_dining, size: 18, color: Colors.deepPurple),
                            SizedBox(width: 6),
                            Text(
                              'DELIVERY RIDER',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: Icon(
                            _assignedRiderInfo != null ? Icons.edit : Icons.add,
                            size: 14,
                            color: Colors.deepPurple,
                          ),
                          label: Text(
                            _assignedRiderInfo != null ? 'Reassign' : 'Assign Rider',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          onPressed: _showAssignRiderSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_assignedRiderInfo != null) ...[
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.deepPurple,
                            child: Icon(Icons.person, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _assignedRiderInfo!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textDark,
                              ),
                            ),
                          ),
                          if (_extractRiderPhone(widget.order.notes) != null) ...[
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _call(_extractRiderPhone(widget.order.notes)),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'No rider assigned yet. Tap "Assign Rider" to assign.',
                        style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Customer Details Card (5px square UI)
            Container(
              padding: const EdgeInsets.all(16),
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
                        'CUSTOMER DETAILS',
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _call(order.customerPhone),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.teal, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _openWhatsApp(order.customerPhone, order.orderNumber),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        order.customerPhone!,
                        style: const TextStyle(color: AppConstants.textBody, fontSize: 13),
                      ),
                    ),
                  const Divider(color: AppConstants.borderLight, height: 20),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppConstants.textMuted),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        order.orderType == 'dine_in'
                            ? Icons.table_restaurant
                            : order.orderType == 'delivery'
                                ? Icons.delivery_dining
                                : Icons.takeout_dining,
                        size: 14,
                        color: AppConstants.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.orderType == 'dine_in'
                              ? "Dine-In • Table #${order.tableNumber ?? 'N/A'}"
                              : order.orderType == 'delivery'
                                  ? "Delivery Address: ${order.deliveryAddress ?? 'No address'}"
                                  : "Takeaway • Token #${order.tokenNumber ?? 'N/A'}",
                          style: const TextStyle(color: AppConstants.textDark, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceLight,
                        borderRadius: AppConstants.radius5,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.notes!,
                              style: const TextStyle(color: AppConstants.textBody, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Order Items Table (5px square UI)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECEIPT ITEMS',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map((it) {
                    final itemTotal = it.price * it.qty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.primary.withValues(alpha: 0.1),
                              borderRadius: AppConstants.radius5,
                            ),
                            child: Text(
                              "${it.qty}x",
                              style: const TextStyle(
                                color: AppConstants.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.name,
                                  style: const TextStyle(
                                    color: AppConstants.textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (it.variationName != null && it.variationName!.isNotEmpty)
                                  Text(
                                    "Size: ${it.variationName}",
                                    style: const TextStyle(color: AppConstants.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                if (it.toppings.isNotEmpty)
                                  Text(
                                    "Toppings: ${it.toppings.join(', ')}",
                                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            "${AppConstants.currency}${itemTotal.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: AppConstants.textDark,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(color: AppConstants.borderLight, height: 16),

                  if (order.deliveryFee > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                          Text(
                            "${AppConstants.currency}${order.deliveryFee.toStringAsFixed(0)}",
                            style: const TextStyle(color: AppConstants.textDark, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          color: AppConstants.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${AppConstants.currency}${order.total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String statusKey, String label, Color color) {
    final isSelected = _currentStatus == statusKey ||
        ((_currentStatus == 'ready' || _currentStatus == 'out_for_delivery') &&
            (statusKey == 'ready' || statusKey == 'out_for_delivery'));
    return InkWell(
      onTap: _isUpdating ? null : () => _updateStatus(statusKey == 'out_for_delivery' ? 'ready' : statusKey),
      borderRadius: AppConstants.radius5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : AppConstants.surfaceLight,
          borderRadius: AppConstants.radius5,
          border: Border.all(color: isSelected ? color : AppConstants.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppConstants.textBody,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
