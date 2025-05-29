import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';
import '../repositories/contact_repository.dart';

class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});

  @override
  _AdminContactsScreenState createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> {
  final ContactRepository _contactRepository = ContactRepository();
  late Future<List<Contact>> _contactsFuture;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  String _selectedType = 'contact';
  Contact? _editingContact;

  @override
  void initState() {
    super.initState();
    _contactsFuture = _contactRepository.getContacts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _refreshContacts() {
    setState(() {
      _contactsFuture = _contactRepository.getContacts();
    });
  }

  void _startAddContact() {
    setState(() {
      _editingContact = null;
      _titleController.clear();
      _valueController.clear();
      _iconController.clear();
      _selectedType = 'contact';
    });
    _showContactDialog();
  }

  void _startEditContact(Contact contact) {
    setState(() {
      _editingContact = contact;
      _titleController.text = contact.title;
      _valueController.text = contact.value;
      _iconController.text = contact.icon;
      _selectedType = contact.type;
    });
    _showContactDialog();
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_editingContact == null ? 'Добавить контакт' : 'Редактировать контакт'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (value) => value?.isEmpty ?? true ? 'Введите название' : null,
                  ),
                  TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(labelText: 'Значение (URL, телефон и т.д.)'),
                    validator: (value) => value?.isEmpty ?? true ? 'Введите значение' : null,
                  ),
                  TextFormField(
                    controller: _iconController,
                    decoration: const InputDecoration(labelText: 'Иконка (код из Icons)'),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: const [
                      DropdownMenuItem(value: 'contact', child: Text('Контакт')),
                      DropdownMenuItem(value: 'social', child: Text('Соцсеть')),
                      DropdownMenuItem(value: 'office', child: Text('Офис')),
                    ],
                    onChanged: (value) => setState(() => _selectedType = value!),
                    decoration: const InputDecoration(labelText: 'Тип контакта'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: _saveContact,
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveContact() async {
    if (_formKey.currentState?.validate() ?? false) {
      final contact = Contact(
        id: _editingContact?.id ?? '',
        title: _titleController.text,
        value: _valueController.text,
        icon: _iconController.text,
        type: _selectedType,
      );

      if (_editingContact == null) {
        await _contactRepository.addContact(contact);
      } else {
        await _contactRepository.updateContact(contact);
      }

      Navigator.of(context).pop();
      _refreshContacts();
    }
  }

  Future<void> _deleteContact(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контакт?'),
        content: const Text('Вы уверены, что хотите удалить этот контакт?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _contactRepository.deleteContact(id);
      _refreshContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление контактами'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startAddContact,
            tooltip: 'Добавить контакт',
          ),
        ],
      ),
      body: FutureBuilder<List<Contact>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final contacts = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_getIconFromString(contact.icon)),
                  title: Text(contact.title),
                  subtitle: Text(contact.value),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _startEditContact(contact),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteContact(contact.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    // Это простой способ преобразовать строку в IconData
    // В реальном приложении вам может понадобиться более сложное решение
    switch (iconName) {
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'language':
        return Icons.language;
      case 'map':
        return Icons.map;
      case 'send':
        return Icons.send;
      case 'group':
        return Icons.group;
      case 'play_circle_fill':
        return Icons.play_circle_fill;
      case 'article':
        return Icons.article;
      case 'work':
        return Icons.work;
      default:
        return Icons.contact_page;
    }
  }
}