import 'provider_payout_model.dart';

class HubBankDetailsModel {
  final int id;
  final String hubCode;
  final String name;
  final String managerName;
  final String managerPhone;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountMasked;
  final String bankIfsc;
  final String bankAccountHolder;
  final String upiId;

  HubBankDetailsModel({
    required this.id,
    required this.hubCode,
    required this.name,
    required this.managerName,
    required this.managerPhone,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountMasked,
    required this.bankIfsc,
    required this.bankAccountHolder,
    required this.upiId,
  });

  factory HubBankDetailsModel.fromJson(Map<String, dynamic> json) {
    final bAcc = json['bank_account_number']?.toString() ?? '';
    return HubBankDetailsModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      hubCode: json['hub_code']?.toString() ?? 'HUB-KDD-01',
      name: json['name']?.toString() ?? 'Operations Hub',
      managerName: json['manager_name']?.toString() ?? 'Hub Manager',
      managerPhone: json['manager_phone']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? 'Primary Bank Account',
      bankAccountNumber: bAcc,
      bankAccountMasked: json['bank_account_masked']?.toString() ?? (bAcc.length >= 4 ? '•••• ${bAcc.substring(bAcc.length - 4)}' : bAcc),
      bankIfsc: json['bank_ifsc']?.toString() ?? '',
      bankAccountHolder: json['bank_account_holder']?.toString() ?? '',
      upiId: json['upi_id']?.toString() ?? '',
    );
  }
}

class ProviderEarningsSummaryModel {
  final String period;
  final String startDate;
  final String endDate;
  final HubBankDetailsModel hub;
  final int totalDeliveries;
  final int completedDeliveries;
  final int pendingDeliveries;
  final double grossRevenue;
  final double cashCollected;
  final double prepaidRevenue;
  final double platformCommission;
  final double totalLitres;
  final double netWithdrawableAmount;
  final double periodNetWithdrawable;
  final double alreadySettledAmount;
  final Map<String, dynamic> productBreakdown;
  final List<ProviderPayoutModel> recentPayouts;

  ProviderEarningsSummaryModel({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.hub,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.pendingDeliveries,
    required this.grossRevenue,
    required this.cashCollected,
    required this.prepaidRevenue,
    required this.platformCommission,
    required this.totalLitres,
    required this.netWithdrawableAmount,
    required this.periodNetWithdrawable,
    required this.alreadySettledAmount,
    required this.productBreakdown,
    required this.recentPayouts,
  });

  factory ProviderEarningsSummaryModel.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] is Map<String, dynamic> ? json['metrics'] : <String, dynamic>{};
    final hubJson = json['hub'] is Map<String, dynamic> ? json['hub'] : <String, dynamic>{};
    final payoutsList = json['recent_payouts'] is List
        ? (json['recent_payouts'] as List).map((p) => ProviderPayoutModel.fromJson(p)).toList()
        : <ProviderPayoutModel>[];

    return ProviderEarningsSummaryModel(
      period: json['period']?.toString() ?? 'TODAY',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      hub: HubBankDetailsModel.fromJson(hubJson),
      totalDeliveries: int.tryParse(metrics['total_deliveries']?.toString() ?? '0') ?? 0,
      completedDeliveries: int.tryParse(metrics['completed_deliveries']?.toString() ?? '0') ?? 0,
      pendingDeliveries: int.tryParse(metrics['pending_deliveries']?.toString() ?? '0') ?? 0,
      grossRevenue: double.tryParse(metrics['gross_revenue']?.toString() ?? '0') ?? 0.0,
      cashCollected: double.tryParse(metrics['cash_collected']?.toString() ?? '0') ?? 0.0,
      prepaidRevenue: double.tryParse(metrics['prepaid_revenue']?.toString() ?? '0') ?? 0.0,
      platformCommission: double.tryParse(metrics['platform_commission']?.toString() ?? '0') ?? 0.0,
      totalLitres: double.tryParse(metrics['total_litres']?.toString() ?? '0') ?? 0.0,
      netWithdrawableAmount: double.tryParse(metrics['net_withdrawable_amount']?.toString() ?? '0') ?? 0.0,
      periodNetWithdrawable: double.tryParse(metrics['period_net_withdrawable']?.toString() ?? '0') ?? 0.0,
      alreadySettledAmount: double.tryParse(metrics['already_settled_amount']?.toString() ?? '0') ?? 0.0,
      productBreakdown: json['product_breakdown'] is Map<String, dynamic>
          ? json['product_breakdown']
          : <String, dynamic>{},
      recentPayouts: payoutsList,
    );
  }
}
