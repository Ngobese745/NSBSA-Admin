class CommentModel {
  final String id;
  final String? groupId;
  final String? vendorId;
  final String authorName;
  final String? authorRole;
  final String content;
  final List<String> mentionedVendorIds;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    this.groupId,
    this.vendorId,
    required this.authorName,
    this.authorRole,
    required this.content,
    this.mentionedVendorIds = const [],
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      groupId: json['group_id'],
      vendorId: json['vendor_id'],
      authorName: json['author_name'],
      authorRole: json['author_role'],
      content: json['content'],
      mentionedVendorIds: List<String>.from(json['mentioned_vendor_ids'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'vendor_id': vendorId,
      'author_name': authorName,
      'author_role': authorRole,
      'content': content,
      'mentioned_vendor_ids': mentionedVendorIds,
    };
  }
}
