// screens/admin/shop_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/shop_item.dart';

class ShopAdminScreen extends StatefulWidget {
  const ShopAdminScreen({super.key});

  @override
  _ShopAdminScreenState createState() => _ShopAdminScreenState();
}

class _ShopAdminScreenState extends State<ShopAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление магазином'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Товары магазина',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditShopItemScreen(),
                      ),
                    );
                  },
                  child: const Text('Добавить товар'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('shop_items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Нет товаров'));
                }
                
                final items = snapshot.data!.docs
                    .map((doc) => ShopItem.fromFirestore(doc))
                    .toList();
                
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ShopItemAdminCard(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ShopItemAdminCard extends StatelessWidget {
  final ShopItem item;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ShopItemAdminCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      item.isActive ? Icons.check_circle : Icons.remove_circle,
                      color: item.isActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text('${item.price} очков'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.description),
            const SizedBox(height: 8),
            Text('Категория: ${item.category == 'merch' ? 'Мерч' : 'Курсы'}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditShopItemScreen(item: item),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _showDeleteDialog(context, item.id);
                  },
                ),
                Switch(
                  value: item.isActive,
                  onChanged: (value) {
                    _firestore.collection('shop_items')
                      .doc(item.id)
                      .update({'isActive': value});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Вы уверены, что хотите удалить этот товар?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _firestore.collection('shop_items').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class EditShopItemScreen extends StatefulWidget {
  final ShopItem? item;

  const EditShopItemScreen({super.key, this.item});

  @override
  _EditShopItemScreenState createState() => _EditShopItemScreenState();
}

class _EditShopItemScreenState extends State<EditShopItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late String _title;
  late String _description;
  late int _price;
  late String _category;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _title = widget.item?.title ?? '';
    _description = widget.item?.description ?? '';
    _price = widget.item?.price ?? 0;
    _category = widget.item?.category ?? 'merch';
    _isActive = widget.item?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Добавить товар' : 'Редактировать товар'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Название товара'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите название';
                  }
                  return null;
                },
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите описание';
                  }
                  return null;
                },
                onSaved: (value) => _description = value!,
              ),
              TextFormField(
                initialValue: _price.toString(),
                decoration: const InputDecoration(labelText: 'Цена в очках'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите цену';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Введите корректное число';
                  }
                  return null;
                },
                onSaved: (value) => _price = int.parse(value!),
              ),
              DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  DropdownMenuItem(
                    value: 'merch',
                    child: Text('Мерч'),
                  ),
                  DropdownMenuItem(
                    value: 'courses',
                    child: Text('Курсы'),
                  ),
                ],
                decoration: const InputDecoration(labelText: 'Категория'),
                onChanged: (value) => _category = value!,
              ),
              SwitchListTile(
                title: const Text('Активен'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final shopItemData = {
        'title': _title,
        'description': _description,
        'price': _price,
        'category': _category,
        'isActive': _isActive,
      };
      
      if (widget.item == null) {
        _firestore.collection('shop_items').add(shopItemData);
      } else {
        _firestore.collection('shop_items')
          .doc(widget.item!.id)
          .update(shopItemData);
      }
      
      Navigator.pop(context);
    }
  }
}