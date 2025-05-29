class Contact {
  final String id;
  final String title;
  final String value;
  final String icon;
  final String type; // 'contact', 'social', 'office'

  Contact({
    required this.id,
    required this.title,
    required this.value,
    required this.icon,
    required this.type,
  });

  factory Contact.fromMap(Map<String, dynamic> data, String id) {
    return Contact(
      id: id,
      title: data['title'] ?? '',
      value: data['value'] ?? '',
      icon: data['icon'] ?? '',
      type: data['type'] ?? 'contact',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'value': value,
      'icon': icon,
      'type': type,
    };
  }
}