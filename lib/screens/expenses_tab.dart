import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/expense_model.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  bool _isLoading = true;
  List<ExpenseItem> _expenses = [];
  int? _shopId;

  final List<Map<String, String>> _categories = [
    {'name': 'Ingredients', 'emoji': '🍅'},
    {'name': 'Oil', 'emoji': '🫒'},
    {'name': 'Utilities', 'emoji': '⚡'},
    {'name': 'Gas Cylinder', 'emoji': '🔥'},
    {'name': 'Wages / Staff', 'emoji': '👨‍🍳'},
    {'name': 'Packaging / Boxes', 'emoji': '📦'},
    {'name': 'Fuel / Petrol', 'emoji': '⛽'},
    {'name': 'Rent', 'emoji': '🏢'},
    {'name': 'Maintenance', 'emoji': '🔧'},
    {'name': 'Misc', 'emoji': '🏷️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    SupabaseService.instance.realtimeUpdateNotifier.addListener(_onRealtimeUpdate);
  }

  void _onRealtimeUpdate() {
    if (mounted) {
      _loadExpenses(silent: true);
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.realtimeUpdateNotifier.removeListener(_onRealtimeUpdate);
    super.dispose();
  }

  Future<void> _loadExpenses({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getInt('shop_id');
    final list = await SupabaseService.instance.fetchExpenses(shopId: _shopId);
    if (mounted) {
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    }
  }

  String _getCategoryEmoji(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('oil') || lower.contains('tel')) return '🫒';
    if (lower.contains('ingredient') || lower.contains('cheese') || lower.contains('flour')) return '🍅';
    if (lower.contains('electric') || lower.contains('bill') || lower.contains('utility')) return '⚡';
    if (lower.contains('gas') || lower.contains('cylinder')) return '🔥';
    if (lower.contains('wage') || lower.contains('salary') || lower.contains('staff')) return '👨‍🍳';
    if (lower.contains('pack') || lower.contains('box')) return '📦';
    if (lower.contains('fuel') || lower.contains('petrol')) return '⛽';
    if (lower.contains('rent')) return '🏢';
    if (lower.contains('repair') || lower.contains('maintenance')) return '🔧';
    return '🏷️';
  }

  void _showAddExpenseModal() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = _categories[0]['name']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Record Restaurant Expense 💸',
                          style: TextStyle(
                            color: AppConstants.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppConstants.textMuted),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: AppConstants.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (Rs.)',
                        labelStyle: const TextStyle(color: AppConstants.primary, fontSize: 13),
                        prefixIcon: const Icon(Icons.attach_money, color: AppConstants.primary),
                        filled: true,
                        fillColor: AppConstants.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: AppConstants.radius5,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Description / Title
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: AppConstants.textDark, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Title / Item Name',
                        labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                        hintText: 'e.g. 5L Oil, Cheese blocks, Rider petrol',
                        hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppConstants.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: AppConstants.radius5,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Presets (5px Square UI)
                    const Text(
                      'CATEGORY PRESETS',
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories.map((cat) {
                        final isSel = selectedCategory == cat['name'];
                        return InkWell(
                          onTap: () => setModalState(() => selectedCategory = cat['name']!),
                          borderRadius: AppConstants.radius5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppConstants.primary : AppConstants.surfaceLight,
                              borderRadius: AppConstants.radius5,
                              border: Border.all(
                                color: isSel ? AppConstants.primary : AppConstants.borderLight,
                              ),
                            ),
                            child: Text(
                              "${cat['emoji']} ${cat['name']}",
                              style: TextStyle(
                                color: isSel ? Colors.white : AppConstants.textBody,
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: AppConstants.textDark, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppConstants.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: AppConstants.radius5,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;

                          if (title.isEmpty || amount <= 0) return;

                          Navigator.pop(modalContext);
                          final res = await SupabaseService.instance.addExpense(
                            title: title,
                            amount: amount,
                            category: selectedCategory,
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            shopId: _shopId,
                          );

                          if (!mounted) return;

                          if (res['success'] == true) {
                            _loadExpenses(silent: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Expense of Rs. ${amount.toStringAsFixed(0)} logged successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save expense: ${res['message'] ?? 'Error'}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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

  void _deleteExpense(ExpenseItem exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardLight,
        shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
        title: const Text('Delete Expense?', style: TextStyle(color: AppConstants.textDark)),
        content: Text(
          'Delete "${exp.title}" (${AppConstants.currency}${exp.amount.toStringAsFixed(0)})?',
          style: const TextStyle(color: AppConstants.textBody),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await SupabaseService.instance.deleteExpense(exp.id);
      if (ok) _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSum = _expenses.fold<double>(0.0, (acc, item) => acc + item.amount);

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          backgroundColor: AppConstants.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
          icon: const Icon(Icons.add),
          label: const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          onPressed: _showAddExpenseModal,
        ),
      ),
      body: RefreshIndicator(
        color: AppConstants.primary,
        onRefresh: _loadExpenses,
        child: Column(
          children: [
            // Total Banner (5px Square UI)
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outgoings Logged',
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${AppConstants.currency}${totalSum.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                    ),
                    child: Text(
                      "${_expenses.length} Entries",
                      style: const TextStyle(color: AppConstants.textDark, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Expense List (5px Square UI)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                  : _expenses.isEmpty
                      ? const Center(
                          child: Text('No expenses recorded yet', style: TextStyle(color: AppConstants.textMuted)),
                        )
                      : RawScrollbar(
                          thumbColor: Colors.black.withValues(alpha: 0.16),
                          radius: const Radius.circular(8),
                          thickness: 4.0,
                          interactive: true,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                            final item = _expenses[index];
                            final emoji = _getCategoryEmoji(item.category);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppConstants.cardLight,
                                borderRadius: AppConstants.radius5,
                                border: Border.all(color: AppConstants.borderLight),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppConstants.surfaceLight,
                                    borderRadius: AppConstants.radius5,
                                  ),
                                  child: Center(
                                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: AppConstants.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  "${item.category} • ${item.expenseDate}",
                                  style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${AppConstants.currency}${item.amount.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                      onPressed: () => _deleteExpense(item),
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
        ),
      ),
    );
  }
}
