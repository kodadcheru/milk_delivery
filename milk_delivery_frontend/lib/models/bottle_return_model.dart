class BottleReturnModel {
  final int id;
  final String customerName;
  final String driverName;
  final String hubName;
  final String productName;
  final int quantity;
  final double depositAmount;
  final String status; // DEPOSITED, RETURNED, LOST
  final String collectedDate;
  final String? returnedDate;
  final String notes;

  BottleReturnModel({
    required this.id,
    required this.customerName,
    required this.driverName,
    required this.hubName,
    required this.productName,
    required this.quantity,
    required this.depositAmount,
    required this.status,
    required this.collectedDate,
    this.returnedDate,
    required this.notes,
  });

  factory BottleReturnModel.fromJson(Map<String, dynamic> json) {
    return BottleReturnModel(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? 'Customer',
      driverName: json['driver_name'] ?? 'Unassigned',
      hubName: json['hub_name'] ?? '',
      productName: json['product_name'] ?? 'Glass Bottle',
      quantity: json['quantity'] ?? 1,
      depositAmount: double.tryParse(json['deposit_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'DEPOSITED',
      collectedDate: json['collected_date'] ?? '',
      returnedDate: json['returned_date'],
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'driver_name': driverName,
      'hub_name': hubName,
      'product_name': productName,
      'quantity': quantity,
      'deposit_amount': depositAmount,
      'status': status,
      'collected_date': collectedDate,
      'returned_date': returnedDate,
      'notes': notes,
    };
  }
}
