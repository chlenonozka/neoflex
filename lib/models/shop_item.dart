// models/shop_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopItem {
  final String id;
  final String title;
  final String description;
  final int price;
  final String category; // 'merch' или 'courses'
  final String? imageUrl;
  final bool isActive;

  ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.isActive = true,
  });

  factory ShopItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? 0,
      category: data['category'] ?? 'merch',
      imageUrl: data['imageUrl'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }
}