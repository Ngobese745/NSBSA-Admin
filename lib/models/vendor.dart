class VendorModel {
  final String id;
  final String groupId;
  final String name;
  final String? phone;
  final String? email;
  final String? whatsappNumber;
  final String? idNumber;
  final String? businessType;
  final String? dfName;
  final String? gender;
  final String? address;
  final String? role;
  final String? referenceNumber;
  final double? savingsAmount;
  final String? savingsFrequency;
  final DateTime? savingsStartDate;
  final DateTime createdAt;

  VendorModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.phone,
    this.email,
    this.whatsappNumber,
    this.idNumber,
    this.businessType,
    this.dfName,
    this.gender,
    this.address,
    this.role,
    this.referenceNumber,
    this.savingsAmount,
    this.savingsFrequency,
    this.savingsStartDate,
    required this.createdAt,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'],
      groupId: json['group_id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      whatsappNumber: json['whatsapp_number'],
      idNumber: json['id_number'],
      businessType: json['business_type'],
      dfName: json['df_name'],
      gender: json['gender'],
      address: json['address'],
      role: json['role'],
      referenceNumber: json['reference_number'],
      savingsAmount: json['savings_amount'] != null ? (json['savings_amount'] as num).toDouble() : null,
      savingsFrequency: json['savings_frequency'],
      savingsStartDate: json['savings_start_date'] != null ? DateTime.parse(json['savings_start_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'group_id': groupId,
      'name': name,
      'phone': phone,
      'email': email,
      'whatsapp_number': whatsappNumber,
      'id_number': idNumber,
      'business_type': businessType,
      'df_name': dfName,
      'gender': gender,
      'address': address,
      'role': role,
      'reference_number': referenceNumber,
      'savings_amount': savingsAmount,
      'savings_frequency': savingsFrequency,
      'savings_start_date': savingsStartDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
