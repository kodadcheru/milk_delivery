class WalletTransactionModel {
  final int id;
  final double amount;
  final String transactionType; // CREDIT, DEBIT
  final String description;
  final String createdAt;

  WalletTransactionModel({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      transactionType: json['transaction_type'] ?? 'CREDIT',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
