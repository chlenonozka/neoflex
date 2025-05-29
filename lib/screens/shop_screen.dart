// screens/shop_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_item.dart';

class ShopScreen extends StatelessWidget {
  final int points;
  final Function(int) onPointsUpdated;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ShopScreen({
    super.key,
    required this.points,
    required this.onPointsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин Neoflex'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('shop_items')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Нет доступных товаров'));
          }
          
          final items = snapshot.data!.docs
              .map((doc) => ShopItem.fromFirestore(doc))
              .toList();
          
          final merchItems = items.where((item) => item.category == 'merch').toList();
          final courseItems = items.where((item) => item.category == 'courses').toList();
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Заголовок и текущие очки
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Ваши очки',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 30),
                          const SizedBox(width: 8),
                          Text(
                            '$points',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Товары
              if (merchItems.isNotEmpty) ...[
                const Text(
                  'Мерч Neoflex',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...merchItems.map((item) => _buildShopItem(context, item)).toList(),
              ],
              
              const SizedBox(height: 20),
              
              // Курсы
              if (courseItems.isNotEmpty) ...[
                const Text(
                  'Онлайн-курсы',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...courseItems.map((item) => _buildShopItem(context, item)).toList(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildShopItem(BuildContext context, ShopItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.category == 'merch' ? Icons.shopping_bag : Icons.school,
                  size: 40,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(item.description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text('${item.price}'),
                  ],
                ),
                ElevatedButton(
                  onPressed: points >= item.price
                      ? () async {
                          final newPoints = points - item.price;
                          onPointsUpdated(newPoints);
                          
                          // Обновляем данные в Firestore
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                    'points': newPoints,
                                  });
                              
                              // Добавляем вызов для обновления лидерборда
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop(true); // Возвращаем флаг обновления
                              }
                            }
                          } catch (e) {
                            print('Ошибка при обновлении очков: $e');
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Вы купили ${item.title}!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Купить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}