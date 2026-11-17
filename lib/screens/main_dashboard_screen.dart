import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../core/order_alert_service.dart';
import '../models/order_model.dart';
import 'orders_tab.dart';
import 'verify_orders_screen.dart';
import 'analytics_tab.dart';
import 'daily_closing_screen.dart';
import 'expenses_tab.dart';
import 'menu_stock_tab.dart';
import 'create_order_modal.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import '../core/app_update_service.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;
  int _inventorySubTab = 0;
  int? _shopId;
  String _shopName = 'Sole What';

  @override
  void initState() {
    super.initState();
    _loadBranchSession();
    SupabaseService.instance.initRealtimeSubscription();
    _checkAppUpdateSilently();
  }

  Future<void> _checkAppUpdateSilently() async {
    try {
      final info = await AppUpdateService.instance.checkForUpdate();
      if (info.hasUpdate && mounted) {
        _showUpdateDialog(info);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.deepOrange, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Update Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'v${info.currentVersion}  →  v${info.latestVersion}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
              Text(
                'What\'s New:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  info.releaseNotes!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purani app delete karne ki zaroorat nahi. Aap ka PIN aur settings mehfooz rahengi.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!info.forceUpdate)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Baad Mein', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (!info.forceUpdate) const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      AppUpdateService.instance.launchDownload(
                        info.downloadUrl ?? AppUpdateService.defaultApkUrl,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBranchSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _shopId = prefs.getInt('shop_id');
      _shopName = prefs.getString('shop_name') ?? 'Sole What';
    });
    // Start background live alerts for new online orders (works when app is closed)
    OrderAlertService.start(shopId: _shopId);
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardLight,
        shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
        title: const Text(
          'Logout Branch?',
          style: TextStyle(color: AppConstants.textDark),
        ),
        content: Text(
          'Log out from "$_shopName"?',
          style: const TextStyle(color: AppConstants.textBody),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textMuted),
            ),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primary,
              shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('shop_id');
      await prefs.remove('shop_name');
      await OrderAlertService.stop();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _openCreateOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateOrderModal(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      OrdersTab(onOpenVerify: () => setState(() => _currentIndex = 1)),
      const VerifyOrdersScreen(),
      const AnalyticsTab(),
      const DailyClosingScreen(),
      _buildInventoryExpensesScreen(),
    ];

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: AppConstants.cardLight,
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Image.asset(
                AppConstants.brandIcon,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Icon(
                  Icons.local_pizza,
                  color: AppConstants.primary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _shopName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppConstants.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Command Center',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppConstants.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'Order',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppConstants.radius5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
                minimumSize: const Size(0, 32),
              ),
              onPressed: _openCreateOrder,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppConstants.textMuted,
              size: 20,
            ),
            tooltip: 'Settings & Updates',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppConstants.textMuted,
              size: 18,
            ),
            tooltip: 'Logout Branch',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedIndexedStack(index: _currentIndex, children: screens),

      // 🌟 FLOATING GLASS NAVBAR (With Compact Small Page Names)
      bottomNavigationBar: _buildGlassFloatingNavBar(),
    );
  }

  Widget _buildInventoryExpensesScreen() {
    return Column(
      children: [
        Container(
          color: AppConstants.cardLight,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _inventorySubTab = 0),
                  borderRadius: AppConstants.radius5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _inventorySubTab == 0
                          ? AppConstants.textDark
                          : AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                    ),
                    child: Center(
                      child: Text(
                        '💸 Daily Outgoings',
                        style: TextStyle(
                          color: _inventorySubTab == 0
                              ? Colors.white
                              : AppConstants.textBody,
                          fontSize: 11,
                          fontWeight: _inventorySubTab == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _inventorySubTab = 1),
                  borderRadius: AppConstants.radius5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _inventorySubTab == 1
                          ? AppConstants.textDark
                          : AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                    ),
                    child: Center(
                      child: Text(
                        '🍕 Stock Toggle',
                        style: TextStyle(
                          color: _inventorySubTab == 1
                              ? Colors.white
                              : AppConstants.textBody,
                          fontSize: 11,
                          fontWeight: _inventorySubTab == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppConstants.borderLight),
        Expanded(
          child: _inventorySubTab == 0
              ? const ExpensesTab()
              : const MenuStockTab(),
        ),
      ],
    );
  }

  Widget _buildGlassFloatingNavBar() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            decoration: BoxDecoration(
              borderRadius: AppConstants.radius5,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppConstants.radius5,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 56, // Sleek compact height
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: AppConstants.radius5,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _glassNavItem(0, Icons.receipt_long, 'Orders'),
                      _glassNavItem(
                        1,
                        Icons.verified_user_outlined,
                        'Verify',
                        hasBadge: true,
                      ),
                      _glassNavItem(2, Icons.insights, 'Analytics'),
                      _glassNavItem(3, Icons.calculate_outlined, 'Closing'),
                      _glassNavItem(4, Icons.tune, 'Inventory'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Developer: Syed Zeeshan Haider',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppConstants.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassNavItem(
    int index,
    IconData icon,
    String label, {
    bool hasBadge = false,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: AppConstants.radius5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: AppConstants.radius5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                offset: isSelected ? const Offset(0, -0.06) : Offset.zero,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        icon,
                        size: 19,
                        color: isSelected
                            ? AppConstants.primary
                            : AppConstants.textMuted,
                      ),
                    ),
                    if (hasBadge)
                      StreamBuilder<List<PizzaOrder>>(
                        stream: SupabaseService.instance.streamUnverifiedOrders(
                          shopId: _shopId,
                        ),
                        builder: (ctx, snap) {
                          final count = snap.data?.length ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Positioned(
                            right: -5,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Compact 8.5px sleek label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                  color: isSelected
                      ? AppConstants.primary
                      : AppConstants.textMuted,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.04), // Subtle modern lift-up animation
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: IndexedStack(
          index: widget.index,
          children: widget.children,
        ),
      ),
    );
  }
}
