import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/order_model.dart';

class VerifyOrdersScreen extends StatefulWidget {
  const VerifyOrdersScreen({super.key});

  @override
  State<VerifyOrdersScreen> createState() => _VerifyOrdersScreenState();
}

class _VerifyOrdersScreenState extends State<VerifyOrdersScreen> {
  int? _shopId;
  String _shopName = 'Sole What';

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  void _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shopId = prefs.getInt('shop_id');
        _shopName = prefs.getString('shop_name') ?? 'Sole What';
      });
    }
  }
  void _callCustomer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openWhatsApp(String? phone, String orderNum) async {
    if (phone == null || phone.trim().isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '92${clean.substring(1)}';
    final text = Uri.encodeComponent("Salam! We received your Online Order #$orderNum. Confirming your details...");
    final uri = Uri.parse("https://wa.me/$clean?text=$text");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  final Set<int> _processingIds = {};

  void _verifyOrder(PizzaOrder order, bool accept) async {
    if (_processingIds.contains(order.id)) return;
    setState(() => _processingIds.add(order.id));

    final res = await SupabaseService.instance.verifyOnlineOrder(
      order.id,
      accept,
      cashierName: _shopName,
    );
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? '✓ Order #${order.orderNumber} Verified & Sent to Kitchen! 🔥'
              : '✗ Order #${order.orderNumber} Cancelled & Rejected.'),
          backgroundColor: accept ? Colors.green.shade700 : Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() => _processingIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: ${res['message'] ?? 'Network Error'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      body: StreamBuilder<List<PizzaOrder>>(
        stream: SupabaseService.instance.streamUnverifiedOrders(shopId: _shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.primary));
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
                      'Please check your WiFi or mobile data to sync incoming orders.',
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

          final queue = (snapshot.data ?? []).where((o) => !_processingIds.contains(o.id)).toList();

          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: AppConstants.radius5,
                    ),
                    child: const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Online Orders Verified!',
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Incoming website orders will ring and appear here for approval',
                    style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RawScrollbar(
            thumbColor: Colors.black.withValues(alpha: 0.16),
            radius: const Radius.circular(8),
            thickness: 4.0,
            interactive: true,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
              itemCount: queue.length,
              itemBuilder: (context, index) {
              final order = queue[index];
              final timeStr = DateFormat('hh:mm a').format(order.createdAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppConstants.cardLight,
                  borderRadius: AppConstants.radius5,
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Online Badge + Order # + Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: AppConstants.radius5,
                                  border: Border.all(color: Colors.amber.shade600),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      'AWAITING VERIFICATION',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppConstants.textDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Customer Info & Phone Call/WhatsApp
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textDark,
                                  ),
                                ),
                                if (order.customerPhone != null)
                                  Text(
                                    order.customerPhone!,
                                    style: const TextStyle(color: AppConstants.textBody, fontSize: 13),
                                  ),
                                if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "📍 ${order.deliveryAddress}",
                                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (order.customerPhone != null) ...[
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _callCustomer(order.customerPhone),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.teal),
                              onPressed: () => _openWhatsApp(order.customerPhone, order.orderNumber),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Order Items List
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.surfaceLight,
                          borderRadius: AppConstants.radius5,
                        ),
                        child: Column(
                          children: order.items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    "${it.qty}x ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "${it.name}${it.variationName != null ? ' (${it.variationName})' : ''}",
                                      style: const TextStyle(color: AppConstants.textDark, fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    "${AppConstants.currency}${(it.price * it.qty).toStringAsFixed(0)}",
                                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Total & Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Bill', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                              Text(
                                "${AppConstants.currency}${order.total.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppConstants.textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              // Reject Button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () => _verifyOrder(order, false),
                                child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),

                              // Verify & Accept Button
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Verify & Kitchen 🔥', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _verifyOrder(order, true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}
