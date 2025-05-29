import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neoflex/models/shop_item.dart';

class ShopRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ShopItem>> getShopItems() {
    return _firestore.collection('shop_items')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ShopItem.fromFirestore(doc))
          .toList());
  }

  Stream<List<ShopItem>> getAllShopItems() {
    return _firestore.collection('shop_items')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ShopItem.fromFirestore(doc))
          .toList());
  }

  Future<void> addShopItem(ShopItem item) {
    return _firestore.collection('shop_items').add(item.toMap());
  }

  Future<void> updateShopItem(ShopItem item) {
    return _firestore.collection('shop_items').doc(item.id).update(item.toMap());
  }

  Future<void> toggleShopItemStatus(String id, bool isActive) {
    return _firestore.collection('shop_items').doc(id).update({'isActive': isActive});
  }

  Future<void> deleteShopItem(String id) {
    return _firestore.collection('shop_items').doc(id).delete();
  }
}