import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactRepository {
  final CollectionReference _contactsCollection =
      FirebaseFirestore.instance.collection('contacts');

  Future<List<Contact>> getContacts() async {
    final querySnapshot = await _contactsCollection.get();
    return querySnapshot.docs
        .map((doc) => Contact.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> addContact(Contact contact) async {
    await _contactsCollection.add(contact.toMap());
  }

  Future<void> updateContact(Contact contact) async {
    await _contactsCollection.doc(contact.id).update(contact.toMap());
  }

  Future<void> deleteContact(String id) async {
    await _contactsCollection.doc(id).delete();
  }
}