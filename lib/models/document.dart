class DocumentModel {
  final String id;
  final String? groupId;
  final String? vendorId;
  final String fileName;
  final String filePath;
  final String? fileType;
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    this.groupId,
    this.vendorId,
    required this.fileName,
    required this.filePath,
    this.fileType,
    required this.uploadedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      groupId: json['group_id'],
      vendorId: json['vendor_id'],
      fileName: json['file_name'],
      filePath: json['file_path'],
      fileType: json['file_type'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'vendor_id': vendorId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
    };
  }
}
