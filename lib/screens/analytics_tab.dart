import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import 'daily_closing_screen.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  bool _isLoading = true;
  bool _isLiveShift = true; // Default to Live Active Shift (Never resets at midnight!)
  DateTime? _selectedDate;
  Map<String, dynamic> _data = {};
  int? _shopId;

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

    Map<String, dynamic> res;
    if (_isLiveShift || _selectedDate == null) {
      res = await SupabaseService.instance.fetchActiveShiftSummary(shopId: _shopId);
    } else {
      res = await SupabaseService.instance
          .fetchSalesAnalytics(date: _selectedDate!, shopId: _shopId);
    }

    if (mounted) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  void _pickHistoricalDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
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
      setState(() {
        _selectedDate = picked;
        _isLiveShift = false;
      });
      _loadData();
    }
  }

  void _switchToLiveShift() {
    setState(() {
      _isLiveShift = true;
      _selectedDate = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppConstants.primary));
    }

    final grossRev = (_data['grossSales'] ?? _data['todayRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (_data['totalOrders'] ?? _data['todayOrdersCount'] as num?)?.toInt() ?? 0;
    final cashRev = (_data['cashSales'] ?? _data['cashRevenue'] as num?)?.toDouble() ?? 0.0;
    final cashCount = (_data['cashOrdersCount'] as num?)?.toInt() ?? 0;
    final onlineRev = (_data['onlineSales'] ?? _data['onlineRevenue'] as num?)?.toDouble() ?? 0.0;
    final onlineCount = (_data['onlineOrdersCount'] as num?)?.toInt() ?? 0;
    final totalExpenses = (_data['totalExpenses'] ?? _data['todayExpenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (_data['netProfit'] as num?)?.toDouble() ?? 0.0;
    final cashInDrawer = (_data['cashInDrawer'] as num?)?.toDouble() ?? (cashRev - totalExpenses);
    final hourlyMap = (_data['hourlyRevenue'] as Map<int, double>?) ?? {};
    final shiftStart = _data['shiftStartTime'] as DateTime?;

    final double cashPercent = grossRev > 0 ? (cashRev / grossRev) : 0.0;

    return RefreshIndicator(
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
            // ─── SHIFT MODE SELECTOR ─────────────────────────
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
                      onTap: _switchToLiveShift,
                      borderRadius: AppConstants.radius5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isLiveShift ? AppConstants.textDark : Colors.transparent,
                          borderRadius: AppConstants.radius5,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _isLiveShift ? Colors.greenAccent : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '⚡ Active Shift (Live)',
                                style: TextStyle(
                                  color: _isLiveShift ? Colors.white : AppConstants.textBody,
                                  fontSize: 12,
                                  fontWeight: _isLiveShift ? FontWeight.bold : FontWeight.normal,
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
                      onTap: _pickHistoricalDate,
                      borderRadius: AppConstants.radius5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isLiveShift ? AppConstants.textDark : Colors.transparent,
                          borderRadius: AppConstants.radius5,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 13,
                                color: !_isLiveShift ? Colors.white : AppConstants.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedDate != null
                                    ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                    : '📅 History / Date',
                                style: TextStyle(
                                  color: !_isLiveShift ? Colors.white : AppConstants.textBody,
                                  fontSize: 12,
                                  fontWeight: !_isLiveShift ? FontWeight.bold : FontWeight.normal,
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

            const SizedBox(height: 12),

            // ─── SHIFT STATUS BANNER (When Register is Open) ──
            if (_isLiveShift)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: AppConstants.radius5,
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIVE OPEN REGISTER SHIFT',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            shiftStart != null
                                ? 'Accumulating orders since ${DateFormat('dd MMM, hh:mm a').format(shiftStart)}'
                                : 'Live register session in progress (does not reset at midnight)',
                            style: const TextStyle(
                              color: AppConstants.textDark,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DailyClosingScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade800,
                          borderRadius: AppConstants.radius5,
                        ),
                        child: const Text(
                          'Close Register',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── GROSS SALES CARD ────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLiveShift ? "CURRENT SHIFT GROSS SALES" : "DAY'S GROSS SALES",
                        style: const TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: AppConstants.radius5,
                        ),
                        child: Text(
                          "$totalOrders Orders",
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${AppConstants.currency}${grossRev.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppConstants.borderLight, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _kpiItem('Cash Drawer', "${AppConstants.currency}${cashInDrawer.toStringAsFixed(0)}", color: Colors.blue.shade800),
                      _kpiItem('Expenses Out', "${AppConstants.currency}${totalExpenses.toStringAsFixed(0)}", color: Colors.red.shade700),
                      _kpiItem('Net Profit', "${AppConstants.currency}${netProfit.toStringAsFixed(0)}", color: netProfit >= 0 ? Colors.green.shade700 : Colors.red),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── 💰 CASH VS ONLINE BREAKDOWN ─────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                        "PAYMENT RECONCILIATION",
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        "${(cashPercent * 100).toStringAsFixed(0)}% Cash Share",
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: AppConstants.radius5,
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (cashPercent * 100).toInt(),
                            child: Container(color: Colors.green.shade600),
                          ),
                          Expanded(
                            flex: ((1.0 - cashPercent) * 100).toInt(),
                            child: Container(color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _paymentBadge(
                          title: '💵 CASH SALES',
                          amount: "${AppConstants.currency}${cashRev.toStringAsFixed(0)}",
                          count: "$cashCount orders",
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _paymentBadge(
                          title: '💳 ONLINE / CARD',
                          amount: "${AppConstants.currency}${onlineRev.toStringAsFixed(0)}",
                          count: "$onlineCount orders",
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── 📊 HOURLY SALES TREND CHART ─────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                        "HOURLY SALES VELOCITY",
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Text(
                        "Shift Rush Hours",
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 160,
                    child: _buildHourlyBarChart(hourlyMap),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _kpiItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppConstants.textDark,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _paymentBadge({
    required String title,
    required String amount,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppConstants.radius5,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              color: AppConstants.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(count, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildHourlyBarChart(Map<int, double> hourly) {
    if (hourly.isEmpty) {
      return const Center(
        child: Text(
          'No hourly sales registered yet in this shift.',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
        ),
      );
    }

    final hours = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 0, 1, 2];
    double maxRev = 1000.0;
    for (var h in hours) {
      final v = hourly[h] ?? 0.0;
      if (v > maxRev) maxRev = v;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRev * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final h = hours[group.x.toInt()];
              final v = rod.toY;
              final hourLabel = h == 0 ? "12 AM" : h < 12 ? "$h AM" : h == 12 ? "12 PM" : "${h - 12} PM";
              return BarTooltipItem(
                "$hourLabel\n${AppConstants.currency}${v.toStringAsFixed(0)}",
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= hours.length) return const SizedBox.shrink();
                final h = hours[idx];
                if (idx % 2 != 0) return const SizedBox.shrink();
                final label = h == 0 ? "12A" : h < 12 ? "${h}A" : h == 12 ? "12P" : "${h - 12}P";
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: hours.asMap().entries.map((entry) {
          final idx = entry.key;
          final h = entry.value;
          final rev = hourly[h] ?? 0.0;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: rev,
                color: rev > 0 ? AppConstants.primary : Colors.grey.shade200,
                width: 10,
                borderRadius: BorderRadius.zero,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
