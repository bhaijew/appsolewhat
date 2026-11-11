import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

/// Background live alerts for online orders awaiting verification.
/// Runs as an Android foreground service so alerts keep arriving even when the
/// app is minimised or swiped away from recents.
class OrderAlertService {
  OrderAlertService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.solepizza.pizza_admin/notifications');
  static bool _listenerAttached = false;

  /// Call once from main() before runApp.
  static void initMain() {
    FlutterForegroundTask.initCommunicationPort();
    if (!_listenerAttached) {
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      _listenerAttached = true;
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'live_order_service_v2',
        channelName: 'Live Order Alerts',
        channelDescription: 'Alerts when a new online order needs verification.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        enableVibration: true,
        playSound: true,
        onlyAlertOnce: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(8000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static void _onReceiveTaskData(Object data) {
    if (data is Map) {
      final id = (data['id'] as num?)?.toInt() ?? 1001;
      final title = data['title']?.toString() ?? '🍕 New Online Order';
      final body = data['body']?.toString() ?? 'Open app to verify order';
      showOrderAlert(id: id, title: title, body: body);
    }
  }

  static Future<void> showOrderAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _nativeChannel.invokeMethod('showAlert', {
        'id': id,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  /// Ask permissions and start the background watcher for this branch.
  static Future<void> start({int? shopId}) async {
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      await FlutterForegroundTask.saveData(key: 'shop_id', value: shopId ?? -1);

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.remoteMessaging],
          serviceId: 712,
          notificationTitle: 'Sole What — Live Orders Active',
          notificationText: 'Watching for new online orders',
          callback: orderAlertStartCallback,
        );
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void orderAlertStartCallback() {
  FlutterForegroundTask.setTaskHandler(_OrderAlertTaskHandler());
}

class _OrderAlertTaskHandler extends TaskHandler {
  final Set<int> _seen = {};
  bool _seeded = false;
  bool _busy = false;
  int? _shopId;
  int _lastPendingCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final sid = await FlutterForegroundTask.getData<int>(key: 'shop_id');
    _shopId = (sid == null || sid < 0) ? null : sid;
    final saved = await FlutterForegroundTask.getData<String>(key: 'seen_ids');
    if (saved != null && saved.isNotEmpty) {
      _seen.addAll(saved.split(',').map(int.tryParse).whereType<int>());
      _seeded = true;
    }
    await _poll();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _poll();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final params = <String, String>{
        'select': 'id,order_number,customer_name,total,created_at',
        'notes': 'ilike.*AWAITING_VERIFICATION*',
        'status': 'neq.cancelled',
        'order': 'id.desc',
        'limit': '25',
      };
      if (_shopId != null) params['shop_id'] = 'eq.$_shopId';

      final uri = Uri.parse('${AppConstants.supabaseUrl}/rest/v1/orders')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: {
        'apikey': AppConstants.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;

      final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
      final pendingCount = rows.length;

      final fresh = <Map<String, dynamic>>[];
      for (final r in rows) {
        final id = (r['id'] as num?)?.toInt();
        if (id == null) continue;
        if (!_seen.contains(id)) {
          _seen.add(id);
          if (_seeded) fresh.add(r as Map<String, dynamic>);
        }
      }

      if (!_seeded) {
        _seeded = true;
        if (pendingCount > 0) {
          final title = '⚠️ $pendingCount Online Order${pendingCount > 1 ? 's' : ''} Awaiting Verification';
          const body = 'Tap to open app and verify order.';
          FlutterForegroundTask.sendDataToMain({
            'id': 1001,
            'title': title,
            'body': body,
          });
          FlutterForegroundTask.updateService(
            notificationTitle: title,
            notificationText: body,
          );
        }
      }

      for (final r in fresh) {
        final id = (r['id'] as num).toInt();
        final total = (r['total'] as num?)?.toStringAsFixed(0) ?? '0';
        final title = '🍕 New Online Order — ${r['order_number'] ?? '#$id'}';
        final body = '${r['customer_name'] ?? 'Customer'} · Rs. $total · Tap to verify';

        // 1. Trigger high-priority alert notification if main engine is alive
        FlutterForegroundTask.sendDataToMain({
          'id': id,
          'title': title,
          'body': body,
        });

        // 2. Always update foreground service notification (chimes & vibrates even if app is closed)
        FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: body,
        );
      }

      // Keep persisted set small
      final keep = _seen.toList()..sort((a, b) => b.compareTo(a));
      final trimmed = keep.take(200).join(',');
      await FlutterForegroundTask.saveData(key: 'seen_ids', value: trimmed);

      // Update idle text only when pending count changes and no fresh alert just fired
      if (fresh.isEmpty && pendingCount != _lastPendingCount) {
        _lastPendingCount = pendingCount;
        FlutterForegroundTask.updateService(
          notificationTitle: pendingCount > 0
              ? '⚠️ $pendingCount Online Order${pendingCount > 1 ? 's' : ''} Awaiting Verification'
              : 'Sole What — Live Orders Active',
          notificationText: pendingCount > 0
              ? 'Tap to verify & send to kitchen'
              : 'Watching for new online orders',
        );
      }
    } catch (_) {
      // Offline / timeout: silently retry on next tick
    } finally {
      _busy = false;
    }
  }
}
