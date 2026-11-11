import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/expense_model.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  bool _isLoading = true;
  int _activeView = 0; // 0 = Active Live Shift, 1 = Past Closings History
  Map<String, dynamic> _activeShift = {};
  List<Map<String, dynamic>> _history = [];
  int? _shopId;
  String _shopName = 'Sole What';

  @override
  void initState() {
    super.initState();
    _loadData();
    SupabaseService.instance.realtimeUpdateNotifier.addListener(_onRealtimeUpdate);
  }

  void _onRealtimeUpdate() {
    if (mounted) {
      _loadData(silent: true);
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.realtimeUpdateNotifier.removeListener(_onRealtimeUpdate);
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getInt('shop_id');
    _shopName = prefs.getString('shop_name') ?? 'Sole What';

    final shift = await SupabaseService.instance.fetchActiveShiftSummary(shopId: _shopId);
    final historyList = await SupabaseService.instance.fetchClosingHistory(shopId: _shopId);

    if (mounted) {
      setState(() {
        _activeShift = shift;
        _history = historyList;
        _isLoading = false;
      });
    }
  }

  void _showCloseRegisterDialog() {
    final gross = (_activeShift['grossSales'] as num?)?.toDouble() ?? 0.0;
    final cash = (_activeShift['cashSales'] as num?)?.toDouble() ?? 0.0;
    final online = (_activeShift['onlineSales'] as num?)?.toDouble() ?? 0.0;
    final expenses = (_activeShift['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final cashInDrawer = (_activeShift['cashInDrawer'] as num?)?.toDouble() ?? (cash - expenses);
    final totalOrders = (_activeShift['totalOrders'] as num?)?.toInt() ?? 0;

    final closedByCtrl = TextEditingController(text: _shopName);
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppConstants.cardLight,
          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: AppConstants.radius5,
                ),
                child: const Icon(Icons.lock_clock, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Close Register / Day End',
                style: TextStyle(
                  color: AppConstants.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will close the active shift, record financial totals into the database, and reset the live register for the new shift.',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Financial Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.surfaceLight,
                    borderRadius: AppConstants.radius5,
                    border: Border.all(color: AppConstants.borderLight),
                  ),
                  child: Column(
                    children: [
                      _dialogRow('Total Gross Sales:', "${AppConstants.currency}${gross.toStringAsFixed(0)} ($totalOrders orders)"),
                      const SizedBox(height: 6),
                      _dialogRow('Cash Sales:', "${AppConstants.currency}${cash.toStringAsFixed(0)}"),
                      const SizedBox(height: 6),
                      _dialogRow('Online / Card:', "${AppConstants.currency}${online.toStringAsFixed(0)}"),
                      const SizedBox(height: 6),
                      _dialogRow('Expenses Deducted:', "-${AppConstants.currency}${expenses.toStringAsFixed(0)}", isNegative: true),
                      const Divider(height: 14, color: AppConstants.borderLight),
                      _dialogRow(
                        '💵 CASH TO HAND OVER:',
                        "${AppConstants.currency}${cashInDrawer.toStringAsFixed(0)}",
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Closed By field
                const Text(
                  'CLOSED BY (CASHIER / MANAGER)',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: closedByCtrl,
                  style: const TextStyle(fontSize: 13, color: AppConstants.textDark, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppConstants.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: AppConstants.radius5, borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 12),

                // Closing Notes
                const Text(
                  'CLOSING NOTES (OPTIONAL)',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(fontSize: 13, color: AppConstants.textDark),
                  decoration: InputDecoration(
                    hintText: 'e.g., Drawer cash counted & handed over to Safe.',
                    hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppConstants.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: AppConstants.radius5, borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      setDlgState(() => isSubmitting = true);
                      final res = await SupabaseService.instance.closeRegisterSession(
                        shopId: _shopId,
                        closedBy: closedByCtrl.text.trim().isEmpty ? _shopName : closedByCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );

                      navigator.pop();

                      if (res['success'] == true) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('✓ Register closed successfully! Shift reconciliation completed.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadData();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error closing register: ${res['message']}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lock & Close Register', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool isNegative = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 12 : 11.5,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
            color: isHighlight ? AppConstants.textDark : AppConstants.textBody,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
            color: isNegative
                ? Colors.red
                : isHighlight
                    ? Colors.green.shade800
                    : AppConstants.textDark,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppConstants.primary));
    }

    final bool isClosed = _activeShift['isClosed'] == true;
    final String businessDate = _activeShift['businessDate']?.toString() ?? SupabaseService.getCurrentBusinessDate();
    final String? closedBy = _activeShift['closedBy']?.toString();
    final DateTime? closedAt = _activeShift['closedAt'] as DateTime?;

    final gross = (_activeShift['grossSales'] as num?)?.toDouble() ?? 0.0;
    final cash = (_activeShift['cashSales'] as num?)?.toDouble() ?? 0.0;
    final cashCount = (_activeShift['cashOrdersCount'] as num?)?.toInt() ?? 0;
    final online = (_activeShift['onlineSales'] as num?)?.toDouble() ?? 0.0;
    final onlineCount = (_activeShift['onlineOrdersCount'] as num?)?.toInt() ?? 0;
    final expenses = (_activeShift['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final cashInDrawer = (_activeShift['cashInDrawer'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (_activeShift['totalOrders'] as num?)?.toInt() ?? 0;
    final dineInSales = (_activeShift['dineInSales'] as num?)?.toDouble() ?? 0.0;
    final takeawaySales = (_activeShift['takeawaySales'] as num?)?.toDouble() ?? 0.0;
    final deliverySales = (_activeShift['deliverySales'] as num?)?.toDouble() ?? 0.0;
    final expenseList = (_activeShift['expenseList'] as List<ExpenseItem>?) ?? [];
    final shiftStart = _activeShift['shiftStartTime'] as DateTime?;

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      body: RefreshIndicator(
        color: AppConstants.primary,
        onRefresh: _loadData,
        child: RawScrollbar(
          thumbColor: Colors.black.withValues(alpha: 0.16),
          radius: const Radius.circular(8),
          thickness: 4.0,
          interactive: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── VIEW SWITCHER (Active Shift vs Past Closings) ─
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppConstants.cardLight,
                  borderRadius: AppConstants.radius5,
                  border: Border.all(color: AppConstants.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeView = 0),
                        borderRadius: AppConstants.radius5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeView == 0 ? AppConstants.textDark : Colors.transparent,
                            borderRadius: AppConstants.radius5,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '⚡ Active Open Shift',
                                  style: TextStyle(
                                    color: _activeView == 0 ? Colors.white : AppConstants.textBody,
                                    fontSize: 12,
                                    fontWeight: _activeView == 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeView = 1),
                        borderRadius: AppConstants.radius5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeView == 1 ? AppConstants.textDark : Colors.transparent,
                            borderRadius: AppConstants.radius5,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 13,
                                  color: _activeView == 1 ? Colors.white : AppConstants.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '📜 Past Closings (${_history.length})',
                                  style: TextStyle(
                                    color: _activeView == 1 ? Colors.white : AppConstants.textBody,
                                    fontSize: 12,
                                    fontWeight: _activeView == 1 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (_activeView == 0) ...[
                // ─── 🟢 ACTIVE SHIFT VIEW ─────────────────────

                // Header status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isClosed ? const Color(0xFFF0FDF4) : AppConstants.cardLight,
                    borderRadius: AppConstants.radius5,
                    border: Border.all(
                      color: isClosed ? const Color(0xFFBBF7D0) : AppConstants.borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isClosed ? const Color(0xFF16A34A) : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isClosed
                                      ? 'REGISTER STATUS: CLOSED & RECONCILED'
                                      : 'REGISTER STATUS: OPEN — LIVE SHIFT',
                                  style: TextStyle(
                                    color: isClosed ? const Color(0xFF15803D) : Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isClosed
                                  ? 'Reconciled for $businessDate${closedBy != null ? ' by $closedBy' : ''}${closedAt != null ? ' (${DateFormat('hh:mm a').format(closedAt)})' : ''}'
                                  : (shiftStart != null
                                      ? 'Shift $businessDate · Opened ${DateFormat('dd MMM hh:mm a').format(shiftStart.toLocal())}'
                                      : 'Live Shift: $totalOrders orders logged'),
                              style: TextStyle(
                                color: isClosed ? const Color(0xFF166534) : AppConstants.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isClosed ? const Color(0xFF16A34A) : Colors.green).withValues(alpha: 0.12),
                          borderRadius: AppConstants.radius5,
                        ),
                        child: Text(
                          isClosed ? 'LOCKED' : '$totalOrders Orders',
                          style: TextStyle(
                            color: isClosed ? const Color(0xFF15803D) : Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✓ Previous shift closed info strip (Web or App closing → new shift auto-started)
                if (!isClosed && _activeShift['latestClosingRecord'] != null) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final rec = _activeShift['latestClosingRecord'] as Map<String, dynamic>;
                    final recAt = DateTime.tryParse(rec['created_at']?.toString() ?? '')?.toLocal();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: AppConstants.radius5,
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last closing: ${rec['closing_date'] ?? ''}'
                              '${recAt != null ? ' at ${DateFormat('dd MMM hh:mm a').format(recAt)}' : ''}'
                              '${rec['closed_by'] != null ? ' by ${rec['closed_by']}' : ''}'
                              ' · Rs. ${((rec['total_sales'] as num?) ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 14),

                // 💵 Primary Financial Balance Card (Cash in Drawer)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppConstants.radius5,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'NET CASH IN DRAWER / HAND',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppConstants.radius5,
                            ),
                            child: const Text(
                              'Cash Sales - Expenses',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${AppConstants.currency}${cashInDrawer.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: cashInDrawer >= 0 ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _closingWhiteKpi('Gross Sales', "${AppConstants.currency}${gross.toStringAsFixed(0)}"),
                          _closingWhiteKpi('Cash Sales', "${AppConstants.currency}${cash.toStringAsFixed(0)}"),
                          _closingWhiteKpi('Expenses Out', "${AppConstants.currency}${expenses.toStringAsFixed(0)}"),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Breakdown Grid
                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        title: '💵 CASH SALES',
                        value: "${AppConstants.currency}${cash.toStringAsFixed(0)}",
                        subtitle: '$cashCount orders',
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        title: '💳 ONLINE SALES',
                        value: "${AppConstants.currency}${online.toStringAsFixed(0)}",
                        subtitle: '$onlineCount orders',
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        title: '🍽️ DINE-IN',
                        value: "${AppConstants.currency}${dineInSales.toStringAsFixed(0)}",
                        subtitle: 'Table QR & Dine',
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        title: '🛍️ TAKEAWAY & DELIV',
                        value: "${AppConstants.currency}${(takeawaySales + deliverySales).toStringAsFixed(0)}",
                        subtitle: 'Pickup & Riders',
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Shift Expenses Deductions
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
                            'SHIFT OUTGOINGS DEDUCTED',
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${AppConstants.currency}${expenses.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (expenseList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No expenses logged in this active shift.',
                            style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                          ),
                        )
                      else
                        ...expenseList.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "• ${e.title} (${e.category})",
                                  style: const TextStyle(color: AppConstants.textBody, fontSize: 12),
                                ),
                                Text(
                                  "${AppConstants.currency}${e.amount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Button: Close Register OR Closed Banner
                if (isClosed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Register Closed for $businessDate (${closedBy ?? 'Admin'})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text(
                        'Re-reconcile / Update Closing Notes',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.textDark,
                        side: const BorderSide(color: AppConstants.borderLight),
                        shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                      ),
                      onPressed: _showCloseRegisterDialog,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text(
                        'CLOSE REGISTER & LOCK SHIFT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                        elevation: 0,
                      ),
                      onPressed: _showCloseRegisterDialog,
                    ),
                  ),
                ],
              ] else ...[
                // ─── 📜 PAST CLOSINGS HISTORY VIEW ─────────────
                if (_history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.history, size: 48, color: AppConstants.textMuted),
                        SizedBox(height: 10),
                        Text('No past register closings recorded yet.', style: TextStyle(color: AppConstants.textMuted)),
                      ],
                    ),
                  )
                else
                  ..._history.map((record) {
                    final dateStr = record['closing_date']?.toString() ?? 'Date';
                    final gross = (record['total_sales'] as num?)?.toDouble() ?? 0.0;
                    final totalOrders = (record['total_orders'] as num?)?.toInt() ?? 0;
                    final expenses = (record['total_expenses'] as num?)?.toDouble() ?? 0.0;
                    final net = (record['net_profit'] as num?)?.toDouble() ?? 0.0;
                    final closedBy = record['closed_by']?.toString() ?? 'Admin';
                    final notes = record['notes']?.toString() ?? '';
                    final created = record['created_at'] != null ? DateTime.tryParse(record['created_at'].toString())?.toLocal() : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      color: AppConstants.textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    created != null
                                        ? 'Closed at ${DateFormat('hh:mm a').format(created)} by $closedBy'
                                        : 'Closed by $closedBy',
                                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: AppConstants.radius5,
                                ),
                                child: Text(
                                  "$totalOrders Orders",
                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppConstants.borderLight),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _kpiSmall('Gross Sales', "${AppConstants.currency}${gross.toStringAsFixed(0)}"),
                              _kpiSmall('Expenses', "-${AppConstants.currency}${expenses.toStringAsFixed(0)}", isRed: true),
                              _kpiSmall('Net Profit', "${AppConstants.currency}${net.toStringAsFixed(0)}", isGreen: true),
                            ],
                          ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              notes,
                              style: const TextStyle(color: AppConstants.textMuted, fontSize: 10.5, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _closingWhiteKpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _statBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.cardLight,
        borderRadius: AppConstants.radius5,
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppConstants.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _kpiSmall(String label, String value, {bool isRed = false, bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isRed
                ? Colors.red
                : isGreen
                    ? Colors.green.shade800
                    : AppConstants.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
