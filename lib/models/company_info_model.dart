class CompanyInfo {
  final String id;
  final String title;
  final String content;
  final int order;

  CompanyInfo({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
  });

  factory CompanyInfo.fromMap(Map<String, dynamic> data, String id) {
    return CompanyInfo(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'order': order,
    };
  }
}