class ProviderPayoutModel {
  final String id;
  final int rawId;
  final int hubId;
  final String hubName;
  final String periodStart;
  final String periodEnd;
  final int totalDeliveries;
  final double totalRevenue;
  final double cashCollected;
  final double prepaidRevenue;
  final double driverSalaries;
  final double platformCommission;
  final double amount;
  final String status; // PENDING, PROCESSING, COMPLETED, SETTLED ✅
  final String paymentReference;
  final String bank;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountMasked;
  final String bankIfsc;
  final String upiId;
  final String notes;
  final String date;

  ProviderPayoutModel({
    required this.id,
    required this.rawId,
    required this.hubId,
    required this.hubName,
    required this.periodStart,
    required this.periodEnd,
    required this.totalDeliveries,
    required this.totalRevenue,
    this.cashCollected = 0.0,
    this.prepaidRevenue = 0.0,
    required this.driverSalaries,
    required this.platformCommission,
    required this.amount,
    required this.status,
    required this.paymentReference,
    required this.bank,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountMasked = '',
    this.bankIfsc = '',
    this.upiId = '',
    this.notes = '',
    required this.date,
  });

  factory ProviderPayoutModel.fromJson(Map<String, dynamic> json) {
    final bName = json['bank_name']?.toString() ?? 'Primary Bank Account';
    final bAcc = json['bank_account_number']?.toString() ?? '';
    final bMasked = json['bank_account_masked']?.toString() ?? (bAcc.length >= 4 ? '•••• ${bAcc.substring(bAcc.length - 4)}' : bAcc);
    final bankDesc = json['bank']?.toString() ?? (bAcc.isNotEmpty ? '$bName (A/C $bMasked)' : bName);

    return ProviderPayoutModel(
      id: json['id']?.toString() ?? json['payment_reference']?.toString() ?? 'PAY-0001',
      rawId: json['raw_id'] is int ? json['raw_id'] : int.tryParse(json['raw_id']?.toString() ?? '0') ?? 0,
      hubId: json['hub_id'] is int ? json['hub_id'] : int.tryParse(json['hub_id']?.toString() ?? '0') ?? 0,
      hubName: json['hub_name'] ?? 'Operations Hub',
      periodStart: json['period_start'] ?? '',
      periodEnd: json['period_end'] ?? '',
      totalDeliveries: json['total_deliveries'] is int ? json['total_deliveries'] : int.tryParse(json['total_deliveries']?.toString() ?? '0') ?? 0,
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
      cashCollected: double.tryParse(json['cash_collected']?.toString() ?? '0') ?? 0.0,
      prepaidRevenue: double.tryParse(json['prepaid_revenue']?.toString() ?? '0') ?? 0.0,
      driverSalaries: double.tryParse(json['driver_salaries']?.toString() ?? '0') ?? 0.0,
      platformCommission: double.tryParse(json['platform_commission']?.toString() ?? '0') ?? 0.0,
      amount: double.tryParse(json['amount']?.toString() ?? json['net_payout']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'SETTLED ✅',
      paymentReference: json['payment_reference'] ?? json['id']?.toString() ?? '',
      bank: bankDesc,
      bankName: bName,
      bankAccountNumber: bAcc,
      bankAccountMasked: bMasked,
      bankIfsc: json['bank_ifsc']?.toString() ?? '',
      upiId: json['upi_id']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'raw_id': rawId,
      'hub_id': hubId,
      'hub_name': hubName,
      'period_start': periodStart,
      'period_end': periodEnd,
      'total_deliveries': totalDeliveries,
      'total_revenue': totalRevenue,
      'cash_collected': cashCollected,
      'prepaid_revenue': prepaidRevenue,
      'driver_salaries': driverSalaries,
      'platform_commission': platformCommission,
      'amount': amount,
      'status': status,
      'payment_reference': paymentReference,
      'bank': bank,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_masked': bankAccountMasked,
      'bank_ifsc': bankIfsc,
      'upi_id': upiId,
      'notes': notes,
      'date': date,
    };
  }
}
