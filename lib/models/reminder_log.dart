class ReminderLogModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorPhone;
  final String vendorEmail;
  final String vendorWhatsApp;
  final double loanAmount;
  final double balance;
  final String loanRef;
  final DateTime dueDate;
  final String reminderType; // 'initial' or 'follow_up'
  final String channel; // 'Email', 'WhatsApp', 'SMS'
  final String status; // 'pending', 'sent', 'delivered', 'failed'
  final String? errorMessage;
  final DateTime createdAt;

  ReminderLogModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorPhone,
    required this.vendorEmail,
    required this.vendorWhatsApp,
    required this.loanAmount,
    required this.balance,
    required this.loanRef,
    required this.dueDate,
    required this.reminderType,
    required this.channel,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  factory ReminderLogModel.fromJson(Map<String, dynamic> json) {
    return ReminderLogModel(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      vendorName: json['vendor_name'] ?? '',
      vendorPhone: json['vendor_phone'] ?? '',
      vendorEmail: json['vendor_email'] ?? '',
      vendorWhatsApp: json['vendor_whatsapp'] ?? '',
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      loanRef: json['loan_ref'] ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : DateTime.now(),
      reminderType: json['reminder_type'] ?? 'initial',
      channel: json['channel'] ?? '',
      status: json['status'] ?? 'pending',
      errorMessage: json['error_message'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'vendor_id': vendorId,
    'vendor_name': vendorName,
    'vendor_phone': vendorPhone,
    'vendor_email': vendorEmail,
    'vendor_whatsapp': vendorWhatsApp,
    'loan_amount': loanAmount,
    'balance': balance,
    'loan_ref': loanRef,
    'due_date': dueDate.toIso8601String(),
    'reminder_type': reminderType,
    'channel': channel,
    'status': status,
    'error_message': errorMessage,
  };

  ReminderLogModel copyWith({String? status, String? errorMessage}) =>
      ReminderLogModel(
        id: id,
        vendorId: vendorId,
        vendorName: vendorName,
        vendorPhone: vendorPhone,
        vendorEmail: vendorEmail,
        vendorWhatsApp: vendorWhatsApp,
        loanAmount: loanAmount,
        balance: balance,
        loanRef: loanRef,
        dueDate: dueDate,
        reminderType: reminderType,
        channel: channel,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt,
      );
}
