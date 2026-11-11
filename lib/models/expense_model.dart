class ExpenseItem {
  final int id;
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final String expenseDate;
  final DateTime createdAt;
  final int? shopId;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    required this.expenseDate,
    required this.createdAt,
    this.shopId,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated;
    try {
      parsedCreated = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    return ExpenseItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'General',
      notes: json['notes']?.toString(),
      expenseDate: json['expense_date']?.toString() ?? '',
      createdAt: parsedCreated,
      shopId: (json['shop_id'] as num?)?.toInt(),
    );
  }
}

