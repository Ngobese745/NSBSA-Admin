class VendorModel {
  final String id;
  final String groupId;
  final String name;
  final String? phone;
  final String? email;
  final String? whatsappNumber;
  final String? idNumber;
  final String? businessType;
  final String? dfId;
  final String? dfName;
  final String? gender;
  final String? address;
  final String? role;
  final String? referenceNumber;
  final double? savingsAmount;
  final String? savingsFrequency;
  final DateTime? savingsStartDate;
  final String? avatarUrl;
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
    this.dfId,
    this.dfName,
    this.gender,
    this.address,
    this.role,
    this.referenceNumber,
    this.savingsAmount,
    this.savingsFrequency,
    this.savingsStartDate,
    this.avatarUrl,
    required this.createdAt,
  });

  VendorModel copyWith({
    String? id,
    String? groupId,
    String? name,
    String? phone,
    String? email,
    String? whatsappNumber,
    String? idNumber,
    String? businessType,
    String? dfId,
    String? dfName,
    String? gender,
    String? address,
    String? role,
    String? referenceNumber,
    double? savingsAmount,
    String? savingsFrequency,
    DateTime? savingsStartDate,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return VendorModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      idNumber: idNumber ?? this.idNumber,
      businessType: businessType ?? this.businessType,
      dfId: dfId ?? this.dfId,
      dfName: dfName ?? this.dfName,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      role: role ?? this.role,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      savingsAmount: savingsAmount ?? this.savingsAmount,
      savingsFrequency: savingsFrequency ?? this.savingsFrequency,
      savingsStartDate: savingsStartDate ?? this.savingsStartDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      whatsappNumber: json['whatsapp_number'],
      idNumber: json['id_number'],
      businessType: json['business_type'],
      dfId: json['df_id'],
      dfName: json['df_name'],
      gender: json['gender'],
      address: json['address'],
      role: json['role'],
      referenceNumber: json['reference_number'],
      savingsAmount: json['savings_amount'] != null
          ? (json['savings_amount'] as num).toDouble()
          : null,
      savingsFrequency: json['savings_frequency'],
      savingsStartDate: json['savings_start_date'] != null
          ? DateTime.parse(json['savings_start_date'])
          : null,
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
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
      'df_id': dfId,
      'df_name': dfName,
      'gender': gender,
      'address': address,
      'role': role,
      'reference_number': referenceNumber,
      'savings_amount': savingsAmount,
      'savings_frequency': savingsFrequency,
      'savings_start_date': savingsStartDate?.toIso8601String(),
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
