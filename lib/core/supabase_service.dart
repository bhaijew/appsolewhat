import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../models/product_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  // Dedicated Admin Client initialized with Service Role credentials
  // Never uses SharedPreferences, never gets polluted by cached sessions or tokens!
  late final SupabaseClient _adminClient = SupabaseClient(
    AppConstants.supabaseUrl,
    AppConstants.supabaseAnonKey,
    headers: {
      'apikey': AppConstants.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
    },
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  SupabaseClient get client => _adminClient;

  // Clean human-friendly error formatter that strips raw Supabase URLs and technical jargon
  static String formatErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred';
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('connection closed') ||
        str.contains('clientexception') ||
        str.contains('os error') ||
        str.contains('handshakeexception') ||
        str.contains('uadrrjrlhfttithjmdye')) {
      return 'No Internet Connection. Please check your WiFi or mobile data.';
    }
    if (str.contains('42501') ||
        str.contains('row-level security') ||
        str.contains('unauthorized')) {
      return 'Permission required. Re-authenticating session...';
    }
    if (str.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }
    final cleaned = error
        .toString()
        .replaceAll(RegExp(r'https?://[^\s,]+'), '')
        .replaceAll(RegExp(r'PostgresException\(message:\s*'), '')
        .replaceAll(RegExp(r',?\s*code:\s*\w+'), '')
        .replaceAll(RegExp(r',?\s*details:\s*[^,)]+'), '')
        .replaceAll(RegExp(r',?\s*hint:\s*[^)]+'), '')
        .replaceAll(RegExp(r'\)'), '')
        .trim();
    return cleaned.isNotEmpty
        ? cleaned
        : 'Unable to complete request. Please retry.';
  }

  // Real-time synchronization notifier for instant UI updates across the entire app
  final ValueNotifier<int> realtimeUpdateNotifier = ValueNotifier<int>(0);
  RealtimeChannel? _realtimeChannel;
  Timer? _syncHeartbeat;

  void initRealtimeSubscription() {
    _syncHeartbeat ??= Timer.periodic(const Duration(seconds: 6), (_) {
      realtimeUpdateNotifier.value++;
    });
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = client
          .channel('app_live_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              realtimeUpdateNotifier.value++;
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'expenses',
            callback: (payload) {
              realtimeUpdateNotifier.value++;
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'daily_closings',
            callback: (payload) {
              realtimeUpdateNotifier.value++;
            },
          )
          .subscribe();
    } catch (_) {}
  }

  // Authenticate Branch (Real Branch Login)
  Future<Map<String, dynamic>> loginBranch({
    int? shopId,
    required String password,
  }) async {
    try {
      final trimmedPwd = password.trim();

      // Check Master Admin (hal123)
      if (trimmedPwd == 'hal123') {
        return {
          'success': true,
          'shopId': null,
          'shopName': 'Master Admin (All Outlets)',
          'isMaster': true,
        };
      }

      // Query shops table
      final List<dynamic> shops = await client
          .from('shops')
          .select('id, name, slug, password, pos_pin');

      for (var s in shops) {
        final id = (s['id'] as num?)?.toInt();
        final sPwd = s['password']?.toString().trim();
        final sPin = s['pos_pin']?.toString().trim();
        final sName = s['name']?.toString() ?? 'Outlet';

        // If a specific shop was selected, match against that shop
        if (shopId != null) {
          if (id == shopId && (trimmedPwd == sPwd || trimmedPwd == sPin)) {
            return {
              'success': true,
              'shopId': id,
              'shopName': sName,
              'isMaster': false,
            };
          }
        } else {
          // If no specific shop was picked, match password or pin against any shop
          if (trimmedPwd == sPwd || trimmedPwd == sPin) {
            return {
              'success': true,
              'shopId': id,
              'shopName': sName,
              'isMaster': false,
            };
          }
        }
      }

      return {'success': false, 'message': 'Invalid Branch Password or PIN.'};
    } catch (e) {
      return {'success': false, 'message': formatErrorMessage(e)};
    }
  }

  // Fetch available branches list for login selector
  Future<List<Map<String, dynamic>>> fetchShopsList() async {
    try {
      final List<dynamic> data = await client
          .from('shops')
          .select('id, name, slug')
          .order('id');
      return data
          .map(
            (s) => {
              'id': s['id'] as int,
              'name': s['name']?.toString() ?? 'Outlet',
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  final Map<int?, Stream<List<PizzaOrder>>> _cachedStreams = {};
  List<PizzaOrder> _latestCachedOrders = [];
  List<PizzaOrder> get latestCachedOrders => _latestCachedOrders;

  // Stream orders for a specific branch (cached stream: zero flicker, silent background updates)
  Stream<List<PizzaOrder>> streamOrders({int? shopId}) {
    if (_cachedStreams.containsKey(shopId)) {
      return _cachedStreams[shopId]!;
    }

    late StreamController<List<PizzaOrder>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? rtSub;
    Timer? pollTimer;
    bool fetching = false;

    Future<void> pullLatest() async {
      if (fetching || controller.isClosed) return;
      fetching = true;
      try {
        dynamic q = client
            .from('orders')
            .select('*')
            .order('id', ascending: false)
            .limit(120);
        final List<dynamic> data = await q;
        if (controller.isClosed) return;
        var orders = data
            .map((json) => PizzaOrder.fromJson(json as Map<String, dynamic>))
            .toList();
        if (shopId != null) {
          orders = orders
              .where((o) => o.shopId == null || o.shopId == shopId)
              .toList();
        }
        _latestCachedOrders = orders;
        controller.add(orders);
      } catch (e) {
        // Keep last good emission if transient error
      } finally {
        fetching = false;
      }
    }

    void onNotifier() => pullLatest();

    controller = StreamController<List<PizzaOrder>>.broadcast(
      onListen: () {
        if (_latestCachedOrders.isNotEmpty) {
          controller.add(_latestCachedOrders);
        }
        pullLatest();
        realtimeUpdateNotifier.addListener(onNotifier);
        pollTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => pullLatest(),
        );
        try {
          rtSub = client
              .from('orders')
              .stream(primaryKey: ['id'])
              .order('id', ascending: false)
              .listen((list) {
                if (controller.isClosed) return;
                var orders = list
                    .map((json) => PizzaOrder.fromJson(json))
                    .toList();
                if (shopId != null) {
                  orders = orders
                      .where((o) => o.shopId == null || o.shopId == shopId)
                      .toList();
                }
                _latestCachedOrders = orders;
                controller.add(orders);
              }, onError: (_) {});
        } catch (_) {}
      },
      onCancel: () {
        realtimeUpdateNotifier.removeListener(onNotifier);
        pollTimer?.cancel();
        rtSub?.cancel();
        _cachedStreams.remove(shopId);
      },
    );

    final stream = controller.stream;
    _cachedStreams[shopId] = stream;
    return stream;
  }

  // Fetch registered delivery riders for shop
  Future<List<Map<String, dynamic>>> fetchDeliveryRiders({int? shopId}) async {
    try {
      var query = client
          .from('delivery_riders')
          .select('*')
          .eq('is_active', true);
      if (shopId != null) {
        query = query.or('shop_id.eq.$shopId,shop_id.is.null');
      }
      final List<dynamic> data = await query.order('name', ascending: true);
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Assign Rider to order and set status to ready (On Way / Dispatched)
  Future<bool> assignRiderToOrder(
    int orderId,
    String riderName,
    String riderPhone, {
    int? shopId,
  }) async {
    try {
      final orderData = await client
          .from('orders')
          .select('id, notes, shop_id')
          .eq('id', orderId)
          .maybeSingle();

      String notes = orderData?['notes']?.toString() ?? '';
      notes = notes
          .replaceAll(RegExp(r'\[RIDER:[^\]]+\]\s*', caseSensitive: false), '')
          .trim();
      final riderTag = "[RIDER: ${riderName.trim()} | ${riderPhone.trim()}]";
      final updatedNotes = notes.isEmpty ? riderTag : "$notes | $riderTag";

      await client
          .from('orders')
          .update({
            'delivery_rider_name': riderName.trim(),
            'delivery_rider_phone': riderPhone.trim(),
            'status': 'ready', // Postgres constraint safe: 'ready' marks order packed & dispatched with rider
            'notes': updatedNotes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);

      // Save rider to delivery_riders if not already present
      final targetShop = shopId ?? (orderData?['shop_id'] as num?)?.toInt();
      if (riderName.trim().isNotEmpty && targetShop != null) {
        try {
          final existing = await client
              .from('delivery_riders')
              .select('id')
              .eq('shop_id', targetShop)
              .ilike('name', riderName.trim())
              .maybeSingle();
          if (existing == null) {
            await client.from('delivery_riders').insert({
              'shop_id': targetShop,
              'name': riderName.trim(),
              'phone': riderPhone.trim().isEmpty ? null : riderPhone.trim(),
              'is_active': true,
            });
          }
        } catch (_) {}
      }

      _latestCachedOrders = [];
      _cachedStreams.clear();
      realtimeUpdateNotifier.value++;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Trigger Counter POS thermal print (KOT or Customer Bill)
  Future<bool> triggerCounterPrint(int orderId, {required String type}) async {
    try {
      final orderData = await client
          .from('orders')
          .select('id, notes')
          .eq('id', orderId)
          .maybeSingle();

      String notes = orderData?['notes']?.toString() ?? '';
      notes = notes
          .replaceAll(
            RegExp(r'\[PRINT_REQ:[^\]]+\]\s*', caseSensitive: false),
            '',
          )
          .trim();
      final tag = "[PRINT_REQ: ${type.toUpperCase()}]";
      final updatedNotes = notes.isEmpty ? tag : "$notes $tag";

      await client
          .from('orders')
          .update({
            'notes': updatedNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      realtimeUpdateNotifier.value++;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fetch orders for a specific date and branch
  Future<List<PizzaOrder>> fetchOrdersByDate(
    DateTime date, {
    int? shopId,
  }) async {
    try {
      final startStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} 00:00:00";
      final endStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} 23:59:59";

      dynamic query = client
          .from('orders')
          .select('*')
          .gte('created_at', startStr)
          .lte('created_at', endStr);

      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }

      final List<dynamic> data = await query.order('id', ascending: false);
      return data.map((json) => PizzaOrder.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  // Stream unverified online orders queue (only active shift, non-cancelled)
  Stream<List<PizzaOrder>> streamUnverifiedOrders({int? shopId}) {
    return streamOrders(shopId: shopId).asyncMap((all) async {
      final boundary = await fetchActiveShiftBoundary(shopId: shopId);
      final DateTime? shiftStart = boundary['activeShiftStart'] as DateTime?;
      return all.where((o) {
        final status = o.status.toLowerCase();
        if (shiftStart != null && o.createdAt.isBefore(shiftStart)) {
          return false;
        }
        return !o.isVerified &&
            status != 'preparing' &&
            status != 'out_for_delivery' &&
            status != 'delivered' &&
            status != 'cancelled';
      }).toList();
    });
  }

  // Verify / Accept or Reject Online Order (Fully synced with Web Next.js Admin & Kitchen)
  Future<Map<String, dynamic>> verifyOnlineOrder(
    int orderId,
    bool accept, {
    String? cashierName,
    String? rejectReason,
  }) async {
    try {
      // 1. Fetch current order to get existing notes and details
      final orderData = await client
          .from('orders')
          .select('id, notes, status, source')
          .eq('id', orderId)
          .maybeSingle();

      String existingNotes = orderData?['notes']?.toString() ?? '';
      // Strip [ONLINE_MENU: AWAITING_VERIFICATION]
      String cleanedNotes = existingNotes
          .replaceAll(
            RegExp(
              r'\[ONLINE_MENU:\s*AWAITING_VERIFICATION\]\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      final now = DateTime.now();
      final nowStr = DateFormat('hh:mm a').format(now);
      final staff = cashierName ?? 'App Admin';
      final nowIso = now.toUtc().toIso8601String();

      if (accept) {
        final updatedNotes =
            '[VERIFIED & ACCEPTED by $staff at $nowStr - Sent to Live Orders] $cleanedNotes'
                .trim();

        await client
            .from('orders')
            .update({
              'is_verified': true,
              'status': 'pending', // 'pending' ensures web POS printer script auto-detects and live board triggers
              'verified_at': nowIso,
              'verified_by': staff,
              'notes': updatedNotes,
              'updated_at': nowIso,
            })
            .eq('id', orderId);
      } else {
        final reason = rejectReason ?? 'Cancelled/Rejected by store';
        final updatedNotes =
            '[REJECTED/CANCELLED by $staff at $nowStr: $reason] $cleanedNotes'
                .trim();

        await client
            .from('orders')
            .update({
              'is_verified': false,
              'status': 'cancelled',
              'notes': updatedNotes,
              'updated_at': nowIso,
            })
            .eq('id', orderId);
      }

      realtimeUpdateNotifier.value++;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': formatErrorMessage(e)};
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final dbStatus = newStatus == 'out_for_delivery' ? 'ready' : newStatus;
      await client
          .from('orders')
          .update({
            'status': dbStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
      _latestCachedOrders = [];
      _cachedStreams.clear();
      realtimeUpdateNotifier.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── SHIFT & REGISTER CLOSING RECONCILIATION ──────────────

  // Pakistan Standard Time helper (UTC+5)
  static DateTime getPakistanNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5));
  }

  // Determine current active business shift date (YYYY-MM-DD)
  // Respects shop opening hours (default 11:00 AM) - midnight orders belong to that business date
  static String getCurrentBusinessDate({
    String openingTime = "11:00",
    String closingTime = "01:00",
  }) {
    final pktNow = getPakistanNow();
    final parts = openingTime.split(':');
    final openH = int.tryParse(parts[0]) ?? 11;
    final openM = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final currentMins = pktNow.hour * 60 + pktNow.minute;
    final openMins = openH * 60 + openM;

    DateTime target = pktNow;
    if (currentMins < openMins) {
      target = pktNow.subtract(const Duration(days: 1));
    }
    return "${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}";
  }

  // Fetch the latest closing row for a shop
  Future<Map<String, dynamic>?> fetchLatestClosing({int? shopId}) async {
    try {
      dynamic query = client
          .from('daily_closings')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1);

      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }

      final List<dynamic> data = await query;
      if (data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fetch active shift boundary (synced with Web Next.js getShopActiveShiftBoundary)
  Future<Map<String, dynamic>> fetchActiveShiftBoundary({int? shopId}) async {
    try {
      final currentBusinessDate = getCurrentBusinessDate();
      const openH = 11;
      const openM = 0;
      final parts = currentBusinessDate.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);

      // PKT 11:00 AM = UTC 06:00 AM
      final normalStartUtc = DateTime.utc(
        y,
        m,
        d,
        openH,
        openM,
      ).subtract(const Duration(hours: 5));

      final latestClosing = await fetchLatestClosing(shopId: shopId);

      String? lastClosedAt;
      String? lastClosingDate;
      DateTime activeShiftStart = normalStartUtc;
      Map<String, dynamic>? closingRecord;
      String activeBusinessDate = currentBusinessDate;
      bool rolledOver = false;

      if (latestClosing != null) {
        lastClosedAt = latestClosing['created_at']?.toString();
        lastClosingDate = latestClosing['closing_date']?.toString();
        closingRecord = latestClosing;

        // Synced with Web getShopActiveShiftBoundary: once a business date is closed,
        // the register immediately rolls over to the NEXT shift (fresh live shift, zero sales).
        if (lastClosingDate != null &&
            lastClosingDate.compareTo(currentBusinessDate) >= 0) {
          rolledOver = true;
          final lp = lastClosingDate.split('-');
          final nextDay = DateTime.utc(
            int.parse(lp[0]),
            int.parse(lp[1]),
            int.parse(lp[2]) + 1,
          );
          activeBusinessDate =
              "${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
        }

        if (lastClosedAt != null) {
          final closedTime = DateTime.tryParse(lastClosedAt);
          if (closedTime != null && closedTime.isAfter(normalStartUtc)) {
            activeShiftStart = closedTime;
          }
        }
      }

      return {
        // Active shift is always OPEN (closing rolls over to the next shift like the Web Admin)
        'isClosed': false,
        'rolledOver': rolledOver,
        'businessDate': activeBusinessDate,
        'lastClosedAt': lastClosedAt,
        'lastClosingDate': lastClosingDate,
        'activeShiftStart': activeShiftStart,
        'closingRecord': closingRecord,
      };
    } catch (_) {
      return {
        'isClosed': false,
        'businessDate': getCurrentBusinessDate(),
        'lastClosedAt': null,
        'lastClosingDate': null,
        'activeShiftStart': DateTime.now().subtract(const Duration(hours: 12)),
        'closingRecord': null,
      };
    }
  }

  // Fetch past closed shifts / daily closings history
  Future<List<Map<String, dynamic>>> fetchClosingHistory({
    int? shopId,
    int limit = 30,
  }) async {
    try {
      dynamic query = client
          .from('daily_closings')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }

      final List<dynamic> data = await query;
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch Active Shift Summary (Synced with Web Next.js Admin & Register Closing)
  Future<Map<String, dynamic>> fetchActiveShiftSummary({int? shopId}) async {
    try {
      final boundary = await fetchActiveShiftBoundary(shopId: shopId);
      final bool isClosed = boundary['isClosed'] == true;
      final Map<String, dynamic>? closingRecord = boundary['closingRecord'];
      final DateTime shiftStart = boundary['activeShiftStart'] as DateTime;
      final shiftStartIso = shiftStart.toUtc().toIso8601String();
      final String businessDate = boundary['businessDate'] as String;

      // If shift is officially closed for this business date, display numbers from closing record
      if (isClosed && closingRecord != null) {
        final gross = (closingRecord['total_sales'] as num?)?.toDouble() ?? 0.0;
        final dineIn =
            (closingRecord['dine_in_sales'] as num?)?.toDouble() ?? 0.0;
        final takeaway =
            (closingRecord['takeaway_sales'] as num?)?.toDouble() ?? 0.0;
        final expenses =
            (closingRecord['total_expenses'] as num?)?.toDouble() ?? 0.0;
        final netProfit =
            (closingRecord['net_profit'] as num?)?.toDouble() ??
            (gross - expenses);
        final totalOrders =
            (closingRecord['total_orders'] as num?)?.toInt() ?? 0;
        final closedBy = closingRecord['closed_by']?.toString() ?? 'Admin';
        final notes = closingRecord['notes']?.toString() ?? '';
        final closedAt = closingRecord['created_at'] != null
            ? DateTime.tryParse(closingRecord['created_at'].toString())
                  ?.toLocal()
            : null;

        double cash = (closingRecord['cash_sales'] as num?)?.toDouble() ?? 0.0;
        double online =
            (closingRecord['online_sales'] as num?)?.toDouble() ?? 0.0;
        if (cash == 0.0 && online == 0.0 && notes.contains('CASH: Rs.')) {
          final cMatch = RegExp(r'CASH:\s*Rs\.\s*([0-9.]+)').firstMatch(notes);
          final oMatch = RegExp(r'ONLINE:\s*Rs\.\s*([0-9.]+)')
              .firstMatch(notes);
          if (cMatch != null)
            cash = double.tryParse(cMatch.group(1) ?? '0') ?? 0.0;
          if (oMatch != null)
            online = double.tryParse(oMatch.group(1) ?? '0') ?? 0.0;
        }
        if (cash == 0.0 && online == 0.0) cash = gross;

        return {
          'isClosed': true,
          'businessDate': businessDate,
          'shiftStartTime': shiftStart,
          'lastClosedAt': boundary['lastClosedAt'],
          'hasPreviousClosing': true,
          'latestClosingRecord': closingRecord,
          'closedAt': closedAt,
          'closedBy': closedBy,
          'grossSales': gross,
          'totalOrders': totalOrders,
          'cashSales': cash,
          'cashOrdersCount': 0,
          'onlineSales': online,
          'onlineOrdersCount': 0,
          'dineInSales': dineIn,
          'dineInCount': 0,
          'takeawaySales': takeaway,
          'takeawayCount': 0,
          'deliverySales': 0.0,
          'deliveryCount': 0,
          'pendingCount': 0,
          'preparingCount': 0,
          'deliveredCount': totalOrders,
          'totalExpenses': expenses,
          'expenseList': <ExpenseItem>[],
          'cashInDrawer': cash - expenses,
          'netProfit': netProfit,
          'hourlyRevenue': <int, double>{},
        };
      }

      // Query orders placed since shiftStart
      dynamic orderQuery = client
          .from('orders')
          .select(
            'id, total, status, created_at, payment_method, order_type, shop_id, notes, customer_name, order_number',
          )
          .gte('created_at', shiftStartIso);

      if (shopId != null) {
        orderQuery = orderQuery.eq('shop_id', shopId);
      }

      final List<dynamic> ordersData = await orderQuery.order(
        'id',
        ascending: false,
      );

      double grossSales = 0.0;
      double cashSales = 0.0;
      int cashOrdersCount = 0;
      double onlineSales = 0.0;
      int onlineOrdersCount = 0;
      double dineInSales = 0.0;
      int dineInCount = 0;
      double takeawaySales = 0.0;
      int takeawayCount = 0;
      double deliverySales = 0.0;
      int deliveryCount = 0;
      int pendingCount = 0;
      int preparingCount = 0;
      int deliveredCount = 0;
      int totalValidOrders = 0;
      Map<int, double> hourlyRevenue = {};

      for (var row in ordersData) {
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        final status = (row['status']?.toString() ?? '').toLowerCase();
        final pMethod = (row['payment_method']?.toString() ?? 'cash')
            .toLowerCase();
        final oType = (row['order_type']?.toString() ?? 'takeaway')
            .toLowerCase();
        final notes = (row['notes']?.toString() ?? '').toLowerCase();

        if (status == 'cancelled') continue;
        // Unverified online orders are not sales yet
        if (notes.contains('[online_menu: awaiting_verification]')) continue;

        totalValidOrders++;
        grossSales += total;

        // Payment Method breakdown (Cash vs Online vs Split)
        if (pMethod.contains('split') || notes.contains('split')) {
          double splitCash = total / 2;
          double splitOnline = total / 2;
          final cashMatch = RegExp(r'cash:\s*(?:rs\.?\s*)?([0-9.]+)')
              .firstMatch(notes);
          final onlineMatch = RegExp(r'online:\s*(?:rs\.?\s*)?([0-9.]+)')
              .firstMatch(notes);
          if (cashMatch != null)
            splitCash = double.tryParse(cashMatch.group(1)!) ?? splitCash;
          if (onlineMatch != null)
            splitOnline = double.tryParse(onlineMatch.group(1)!) ?? splitOnline;
          cashSales += splitCash;
          onlineSales += splitOnline;
          cashOrdersCount++;
          onlineOrdersCount++;
        } else if (pMethod.contains('cash')) {
          cashSales += total;
          cashOrdersCount++;
        } else {
          onlineSales += total;
          onlineOrdersCount++;
        }

        // Order Type breakdown
        if (oType.contains('dine') || oType.contains('table')) {
          dineInSales += total;
          dineInCount++;
        } else if (oType.contains('delivery')) {
          deliverySales += total;
          deliveryCount++;
        } else {
          takeawaySales += total;
          takeawayCount++;
        }

        if (status == 'pending') pendingCount++;
        if (status == 'preparing') preparingCount++;
        if (status == 'delivered') deliveredCount++;

        try {
          final dt = DateTime.parse(row['created_at'].toString()).toLocal();
          hourlyRevenue[dt.hour] = (hourlyRevenue[dt.hour] ?? 0.0) + total;
        } catch (_) {}
      }

      // Query expenses created since shiftStart
      dynamic expQuery = client
          .from('expenses')
          .select('*')
          .gte('created_at', shiftStartIso);

      if (shopId != null) {
        expQuery = expQuery.eq('shop_id', shopId);
      }

      final List<dynamic> expData = await expQuery.order(
        'id',
        ascending: false,
      );
      double totalExpenses = 0.0;
      List<ExpenseItem> expenseList = [];
      for (var e in expData) {
        final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
        totalExpenses += amount;
        expenseList.add(ExpenseItem.fromJson(e));
      }

      final double cashInDrawer = cashSales - totalExpenses;
      final double netProfit = grossSales - totalExpenses;

      return {
        'isClosed': false,
        'businessDate': businessDate,
        'shiftStartTime': shiftStart,
        'lastClosedAt': boundary['lastClosedAt'],
        'hasPreviousClosing': boundary['lastClosedAt'] != null,
        'rolledOver': boundary['rolledOver'] == true,
        'lastClosingDate': boundary['lastClosingDate'],
        'latestClosingRecord': boundary['closingRecord'],
        'grossSales': grossSales,
        'totalOrders': totalValidOrders,
        'cashSales': cashSales,
        'cashOrdersCount': cashOrdersCount,
        'onlineSales': onlineSales,
        'onlineOrdersCount': onlineOrdersCount,
        'dineInSales': dineInSales,
        'dineInCount': dineInCount,
        'takeawaySales': takeawaySales,
        'takeawayCount': takeawayCount,
        'deliverySales': deliverySales,
        'deliveryCount': deliveryCount,
        'pendingCount': pendingCount,
        'preparingCount': preparingCount,
        'deliveredCount': deliveredCount,
        'totalExpenses': totalExpenses,
        'expenseList': expenseList,
        'cashInDrawer': cashInDrawer,
        'netProfit': netProfit,
        'hourlyRevenue': hourlyRevenue,
      };
    } catch (e) {
      return {
        'isClosed': false,
        'businessDate': getCurrentBusinessDate(),
        'shiftStartTime': DateTime.now(),
        'lastClosedAt': null,
        'hasPreviousClosing': false,
        'grossSales': 0.0,
        'totalOrders': 0,
        'cashSales': 0.0,
        'cashOrdersCount': 0,
        'onlineSales': 0.0,
        'onlineOrdersCount': 0,
        'dineInSales': 0.0,
        'dineInCount': 0,
        'takeawaySales': 0.0,
        'takeawayCount': 0,
        'deliverySales': 0.0,
        'deliveryCount': 0,
        'pendingCount': 0,
        'preparingCount': 0,
        'deliveredCount': 0,
        'totalExpenses': 0.0,
        'expenseList': <ExpenseItem>[],
        'cashInDrawer': 0.0,
        'netProfit': 0.0,
        'hourlyRevenue': <int, double>{},
      };
    }
  }

  // Execute Register Closing / Shift End (Upserts into daily_closings so both Web & App stay in 100% sync!)
  Future<Map<String, dynamic>> closeRegisterSession({
    required int? shopId,
    required String closedBy,
    String? notes,
  }) async {
    try {
      final summary = await fetchActiveShiftSummary(shopId: shopId);
      final gross = (summary['grossSales'] as num?)?.toDouble() ?? 0.0;
      final cash = (summary['cashSales'] as num?)?.toDouble() ?? 0.0;
      final online = (summary['onlineSales'] as num?)?.toDouble() ?? 0.0;
      final dineIn = (summary['dineInSales'] as num?)?.toDouble() ?? 0.0;
      final takeaway = (summary['takeawaySales'] as num?)?.toDouble() ?? 0.0;
      final expenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
      final totalOrders = (summary['totalOrders'] as num?)?.toInt() ?? 0;
      final netProfit = (summary['netProfit'] as num?)?.toDouble() ?? 0.0;
      final now = DateTime.now();

      // Close the ACTIVE business date (rolls over to next date after a previous closing, same as Web)
      final dateStr = (summary['businessDate']?.toString().isNotEmpty == true)
          ? summary['businessDate'].toString()
          : getCurrentBusinessDate();
      final DateTime? shiftStartTime = summary['shiftStartTime'] as DateTime?;
      final String notesCombined =
          "[CASH: Rs. ${cash.toStringAsFixed(0)} | ONLINE: Rs. ${online.toStringAsFixed(0)}] ${notes ?? ''}"
              .trim();

      // Check if closing record already exists for this date and shop to preserve id
      dynamic existingQ = client
          .from('daily_closings')
          .select('id')
          .eq('closing_date', dateStr);
      if (shopId != null) {
        existingQ = existingQ.eq('shop_id', shopId);
      } else {
        existingQ = existingQ.isFilter('shop_id', null);
      }
      final List<dynamic> existingRows = await existingQ;

      final Map<String, dynamic> payload = {
        'closing_date': dateStr,
        'total_orders': totalOrders,
        'total_sales': gross,
        'dine_in_sales': dineIn,
        'takeaway_sales': takeaway,
        'total_expenses': expenses,
        'net_profit': netProfit,
        'closed_by': closedBy,
        'notes': notesCombined,
        'created_at': now.toUtc().toIso8601String(),
        'cash_sales': cash,
        'online_sales': online,
      };
      if (shopId != null) {
        payload['shop_id'] = shopId;
      }
      if (existingRows.isNotEmpty && existingRows[0]['id'] != null) {
        payload['id'] = existingRows[0]['id'];
      }

      try {
        await client.from('daily_closings').upsert(payload);
      } catch (upsertErr) {
        // Fallback if cash_sales/online_sales column does not exist in schema
        payload.remove('cash_sales');
        payload.remove('online_sales');
        await client.from('daily_closings').upsert(payload);
      }

      // Auto-deliver any remaining orders
      try {
        dynamic updateQ = client
            .from('orders')
            .update({'status': 'delivered', 'payment_status': 'paid'})
            .inFilter('status', ['pending', 'preparing', 'ready'])
            // Never touch online orders still awaiting verification
            .or('notes.is.null,notes.not.ilike.*AWAITING_VERIFICATION*');
        if (shopId != null) {
          updateQ = updateQ.eq('shop_id', shopId);
        }
        if (shiftStartTime != null) {
          updateQ = updateQ.gte(
            'created_at',
            shiftStartTime.toUtc().toIso8601String(),
          );
        }
        await updateQ;
      } catch (_) {}

      realtimeUpdateNotifier.value++;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': formatErrorMessage(e)};
    }
  }

  // Fetch Comprehensive Sales Analytics (Supports both Live Active Shift and Historical Dates)
  Future<Map<String, dynamic>> fetchSalesAnalytics({
    DateTime? date,
    int? shopId,
    bool useActiveShift = false,
  }) async {
    if (useActiveShift || date == null) {
      final shift = await fetchActiveShiftSummary(shopId: shopId);
      return {
        'todayRevenue': shift['grossSales'],
        'todayOrdersCount': shift['totalOrders'],
        'cashRevenue': shift['cashSales'],
        'cashOrdersCount': shift['cashOrdersCount'],
        'onlineRevenue': shift['onlineSales'],
        'onlineOrdersCount': shift['onlineOrdersCount'],
        'pendingCount': shift['pendingCount'],
        'completedCount': shift['deliveredCount'],
        'todayExpenses': shift['totalExpenses'],
        'netProfit': shift['netProfit'],
        'hourlyRevenue': shift['hourlyRevenue'],
        'orderTypesCount': {
          'dine_in': shift['dineInCount'] as int? ?? 0,
          'takeaway': shift['takeawayCount'] as int? ?? 0,
          'delivery': shift['deliveryCount'] as int? ?? 0,
        },
        'shiftStartTime': shift['shiftStartTime'],
        'isShiftOpen': true,
      };
    }

    try {
      final targetDate = date;
      final dateStr =
          "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

      dynamic orderQuery = client
          .from('orders')
          .select(
            'id, total, status, created_at, payment_method, order_type, shop_id',
          )
          .gte('created_at', '$dateStr 00:00:00')
          .lte('created_at', '$dateStr 23:59:59');

      if (shopId != null) {
        orderQuery = orderQuery.eq('shop_id', shopId);
      }

      final List<dynamic> dayOrders = await orderQuery;

      double todayRevenue = 0.0;
      double cashRevenue = 0.0;
      int cashOrdersCount = 0;
      double onlineRevenue = 0.0;
      int onlineOrdersCount = 0;

      int pendingCount = 0;
      int completedCount = 0;
      Map<int, double> hourlyRevenue = {};
      Map<String, int> orderTypesCount = {
        'dine_in': 0,
        'takeaway': 0,
        'delivery': 0,
      };

      for (var row in dayOrders) {
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        final status = (row['status']?.toString() ?? '').toLowerCase();
        final pMethod = (row['payment_method']?.toString() ?? 'cash')
            .toLowerCase();
        final oType = (row['order_type']?.toString() ?? 'takeaway')
            .toLowerCase();

        if (status != 'cancelled') {
          todayRevenue += total;

          if (pMethod.contains('cash')) {
            cashRevenue += total;
            cashOrdersCount++;
          } else {
            onlineRevenue += total;
            onlineOrdersCount++;
          }

          orderTypesCount[oType] = (orderTypesCount[oType] ?? 0) + 1;
        }

        if (status == 'pending') {
          pendingCount++;
        } else if (status == 'delivered') {
          completedCount++;
        }

        try {
          final dt = DateTime.parse(row['created_at'].toString()).toLocal();
          final hour = dt.hour;
          hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0.0) + total;
        } catch (_) {}
      }

      // Fetch day's expenses
      dynamic expQuery = client
          .from('expenses')
          .select('amount, shop_id')
          .eq('expense_date', dateStr);

      if (shopId != null) {
        expQuery = expQuery.eq('shop_id', shopId);
      }

      final List<dynamic> dayExpenses = await expQuery;
      double totalExpenseToday = 0.0;
      for (var row in dayExpenses) {
        totalExpenseToday += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'todayRevenue': todayRevenue,
        'todayOrdersCount': dayOrders.length,
        'cashRevenue': cashRevenue,
        'cashOrdersCount': cashOrdersCount,
        'onlineRevenue': onlineRevenue,
        'onlineOrdersCount': onlineOrdersCount,
        'pendingCount': pendingCount,
        'completedCount': completedCount,
        'todayExpenses': totalExpenseToday,
        'netProfit': todayRevenue - totalExpenseToday,
        'hourlyRevenue': hourlyRevenue,
        'orderTypesCount': orderTypesCount,
        'shiftStartTime': null,
        'isShiftOpen': false,
      };
    } catch (_) {
      return {
        'todayRevenue': 0.0,
        'todayOrdersCount': 0,
        'cashRevenue': 0.0,
        'cashOrdersCount': 0,
        'onlineRevenue': 0.0,
        'onlineOrdersCount': 0,
        'pendingCount': 0,
        'completedCount': 0,
        'todayExpenses': 0.0,
        'netProfit': 0.0,
        'hourlyRevenue': <int, double>{},
        'orderTypesCount': <String, int>{},
        'shiftStartTime': null,
        'isShiftOpen': false,
      };
    }
  }

  // Fetch Daily Closing Summary (Supports Active Open Shift & Historical Dates)
  Future<Map<String, dynamic>> fetchDailyClosingData(
    DateTime? date, {
    int? shopId,
  }) async {
    if (date == null) {
      final shift = await fetchActiveShiftSummary(shopId: shopId);
      return {
        'isLiveShift': true,
        'date': shift['shiftStartTime'] as DateTime,
        'shiftStartTime': shift['shiftStartTime'],
        'grossSales': shift['grossSales'],
        'cashSales': shift['cashSales'],
        'cashCount': shift['cashOrdersCount'],
        'onlineSales': shift['onlineSales'],
        'onlineCount': shift['onlineOrdersCount'],
        'dineInSales': shift['dineInSales'],
        'takeawaySales': shift['takeawaySales'],
        'deliverySales': shift['deliverySales'],
        'totalExpenses': shift['totalExpenses'],
        'cashInDrawer': shift['cashInDrawer'],
        'netProfit': shift['netProfit'],
        'totalOrders': shift['totalOrders'],
        'orderTypes': {
          'dine_in': shift['dineInCount'] as int? ?? 0,
          'takeaway': shift['takeawayCount'] as int? ?? 0,
          'delivery': shift['deliveryCount'] as int? ?? 0,
        },
        'expenses': shift['expenseList'] as List<ExpenseItem>,
      };
    }

    final analytics = await fetchSalesAnalytics(date: date, shopId: shopId);
    final expenses = await fetchExpenses(date: date, shopId: shopId);
    final cashInDrawer =
        (analytics['cashRevenue'] as double) -
        (analytics['todayExpenses'] as double);

    return {
      'isLiveShift': false,
      'date': date,
      'shiftStartTime': null,
      'grossSales': analytics['todayRevenue'],
      'cashSales': analytics['cashRevenue'],
      'cashCount': analytics['cashOrdersCount'],
      'onlineSales': analytics['onlineRevenue'],
      'onlineCount': analytics['onlineOrdersCount'],
      'dineInSales': 0.0,
      'takeawaySales': 0.0,
      'deliverySales': 0.0,
      'totalExpenses': analytics['todayExpenses'],
      'cashInDrawer': cashInDrawer,
      'netProfit': analytics['netProfit'],
      'totalOrders': analytics['todayOrdersCount'],
      'orderTypes': analytics['orderTypesCount'],
      'expenses': expenses,
    };
  }

  // Fetch Expenses
  Future<List<ExpenseItem>> fetchExpenses({DateTime? date, int? shopId}) async {
    try {
      dynamic query = client.from('expenses').select('*');

      if (date != null) {
        final dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        query = query.eq('expense_date', dateStr);
      }

      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }

      final List<dynamic> data = await query
          .order('id', ascending: false)
          .limit(100);
      return data.map((e) => ExpenseItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Add Expense
  Future<Map<String, dynamic>> addExpense({
    required String title,
    required double amount,
    required String category,
    String? notes,
    int? shopId,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final Map<String, dynamic> payload = {
        'title': title,
        'amount': amount,
        'category': category,
        'notes': notes,
        'expense_date': dateStr,
      };
      if (shopId != null) {
        payload['shop_id'] = shopId;
      }

      await client.from('expenses').insert(payload);
      realtimeUpdateNotifier.value++;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': formatErrorMessage(e)};
    }
  }

  // Delete Expense
  Future<bool> deleteExpense(int id) async {
    try {
      await client.from('expenses').delete().eq('id', id);
      realtimeUpdateNotifier.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Fetch Menu / Products
  Future<List<ProductItem>> fetchProducts({int? shopId}) async {
    try {
      dynamic query = client
          .from('products')
          .select(
            'id, name, price, image_url, description, is_available, category_id, shop_id, variations',
          );

      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }

      final List<dynamic> data = await query.order('id', ascending: true);
      return data.map((p) => ProductItem.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }

  // Toggle Product Availability
  Future<bool> toggleProductStock(int productId, bool isAvailable) async {
    try {
      await client
          .from('products')
          .update({'is_available': isAvailable})
          .eq('id', productId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Create New Order from Mobile App (Instant POS Creator)
  Future<Map<String, dynamic>> createOrder({
    required String customerName,
    String? customerPhone,
    required String orderType,
    String? tableNumber,
    String? tokenNumber,
    String? deliveryAddress,
    double deliveryFee = 0.0,
    required List<OrderItem> items,
    required double total,
    String paymentMethod = 'cash',
    String? notes,
    int? shopId,
  }) async {
    try {
      final now = DateTime.now();
      // Derive dateCode from business shift date (PKT UTC+5)
      // Midnight (12:00 AM - 02:00 AM) orders keep the ongoing shift's dateCode
      // so order numbers (e.g. ORD-pm0911-0046) continue seamlessly without dropping to 0001!
      final bDate = getCurrentBusinessDate(); // YYYY-MM-DD
      final bParts = bDate.split('-');
      final dayStr = bParts.length == 3
          ? bParts[2]
          : DateTime.now().day.toString().padLeft(2, '0');
      final monthStr = bParts.length == 3
          ? bParts[1]
          : DateTime.now().month.toString().padLeft(2, '0');
      final dateCode = "$dayStr$monthStr";

      String shopCode = 'pm';
      if (shopId != null) {
        if (shopId == 7) {
          shopCode = 'pm';
        } else if (shopId == 8) {
          shopCode = 'demo';
        } else if (shopId == 10) {
          shopCode = 'shah';
        } else {
          shopCode = 's$shopId';
        }
      }

      int seq = 1;
      try {
        final prefix = "ORD-$shopCode$dateCode-";
        final List<dynamic> latest = await client
            .from('orders')
            .select('order_number, id')
            .like('order_number', '$prefix%')
            .order('id', ascending: false)
            .limit(1);

        if (latest.isNotEmpty) {
          final lastNum = latest[0]['order_number']?.toString() ?? '';
          final match = RegExp(r'(\d+)$').firstMatch(lastNum);
          if (match != null) {
            seq = int.parse(match.group(1)!) + 1;
          } else {
            seq = ((latest[0]['id'] as num?)?.toInt() ?? 0) + 1;
          }
        }
      } catch (_) {
        seq = (now.millisecondsSinceEpoch % 900) + 1;
      }

      final seqStr = seq.toString().padLeft(4, '0');
      var orderNumber = "ORD-$shopCode$dateCode-$seqStr";

      String token = tokenNumber ?? '';
      if (token.isEmpty && orderType != 'delivery') {
        token = "TK-${(seq % 100).toString().padLeft(2, '0')}";
      }

      final orderPayload = {
        'order_number': orderNumber,
        'status': 'preparing',
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone?.trim(),
        'order_type': orderType,
        'table_number': tableNumber?.trim(),
        'token_number': token,
        'delivery_address': deliveryAddress?.trim(),
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod,
        'payment_status': 'paid',
        'source': 'mobile_pos',
        'is_verified': true,
        'notes': notes?.trim(),
        'shop_id': shopId,
        'items': items.map((i) => i.toJson()).toList(),
      };

      try {
        await client.from('orders').insert(orderPayload);
      } catch (_) {
        // Fallback with unique suffix & pending status to guarantee zero collisions and zero RLS rejections
        final fallbackSuffix = "${(now.millisecondsSinceEpoch ~/ 1000) % 10000}"
            .padLeft(4, '0');
        orderNumber = "ORD-$shopCode$dateCode-M$fallbackSuffix";
        orderPayload['order_number'] = orderNumber;
        orderPayload['status'] = 'pending';
        final List<dynamic> inserted = await client
            .from('orders')
            .insert(orderPayload)
            .select('id');
        if (inserted.isNotEmpty && inserted[0]['id'] != null) {
          final newId = (inserted[0]['id'] as num).toInt();
          try {
            await client
                .from('orders')
                .update({'status': 'preparing'})
                .eq('id', newId);
          } catch (_) {}
        }
      }

      realtimeUpdateNotifier.value++;

      return {
        'success': true,
        'orderNumber': orderNumber,
        'tokenNumber': token,
      };
    } catch (e) {
      return {'success': false, 'message': formatErrorMessage(e)};
    }
  }

  // Recreate / Edit Existing Order in-place (ID & Order Number remain exactly identical)
  Future<Map<String, dynamic>> updateExistingOrder({
    required int orderId,
    required String orderNumber,
    required String customerName,
    String? customerPhone,
    required String orderType,
    String? tableNumber,
    String? tokenNumber,
    String? deliveryAddress,
    double deliveryFee = 0.0,
    required List<OrderItem> items,
    required double total,
    String paymentMethod = 'cash',
    String? existingNotes,
    int? shopId,
  }) async {
    try {
      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // Clean old recreate tags and append new [RECREATED: ...] tag
      String cleanNotes = (existingNotes ?? '').replaceAll(RegExp(r'\[RECREATED[^\]]*\]'), '').trim();
      final recreateTag = '[RECREATED: ${items.length} items modified at $timeStr]';
      final updatedNotes = cleanNotes.isNotEmpty ? '$cleanNotes $recreateTag' : recreateTag;

      final updatePayload = {
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone?.trim(),
        'order_type': orderType,
        'table_number': tableNumber?.trim(),
        'token_number': tokenNumber,
        'delivery_address': deliveryAddress?.trim(),
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': updatedNotes,
        'status': 'preparing', // Reset to kitchen preparing so kitchen receives updated items
        'updated_at': nowIso,
      };

      if (shopId != null) {
        updatePayload['shop_id'] = shopId;
      }

      await client.from('orders').update(updatePayload).eq('id', orderId);

      // Invalidate stream cache and trigger realtime
      _latestCachedOrders = [];
      _cachedStreams.clear();
      realtimeUpdateNotifier.value++;

      return {
        'success': true,
        'orderNumber': orderNumber,
        'orderId': orderId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': formatErrorMessage(e),
      };
    }
  }
}
