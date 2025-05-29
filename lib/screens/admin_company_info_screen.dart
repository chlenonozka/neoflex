import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_info_model.dart';
import '../repositories/company_info_repository.dart';

class AdminCompanyInfoScreen extends StatefulWidget {
  const AdminCompanyInfoScreen({super.key});

  @override
  _AdminCompanyInfoScreenState createState() => _AdminCompanyInfoScreenState();
}

class _AdminCompanyInfoScreenState extends State<AdminCompanyInfoScreen> {
  final CompanyInfoRepository _repository = CompanyInfoRepository();
  late Future<List<CompanyInfo>> _infoFuture;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  CompanyInfo? _editingInfo;

  @override
  void initState() {
    super.initState();
    _infoFuture = _repository.getCompanyInfo();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _refreshInfo() {
    setState(() {
      _infoFuture = _repository.getCompanyInfo();
    });
  }

  void _startAddInfo() {
    setState(() {
      _editingInfo = null;
      _titleController.clear();
      _contentController.clear();
      _orderController.clear();
    });
    _showInfoDialog();
  }

  void _startEditInfo(CompanyInfo info) {
    setState(() {
      _editingInfo = info;
      _titleController.text = info.title;
      _contentController.text = info.content;
      _orderController.text = info.order.toString();
    });
    _showInfoDialog();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_editingInfo == null ? 'Добавить раздел' : 'Редактировать раздел'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Заголовок'),
                    validator: (value) => value?.isEmpty ?? true ? 'Введите заголовок' : null,
                  ),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Содержание'),
                    maxLines: 5,
                    validator: (value) => value?.isEmpty ?? true ? 'Введите содержание' : null,
                  ),
                  TextFormField(
                    controller: _orderController,
                    decoration: const InputDecoration(labelText: 'Порядок отображения'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Введите порядок' : null,
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
              onPressed: _saveInfo,
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveInfo() async {
    if (_formKey.currentState?.validate() ?? false) {
      final info = CompanyInfo(
        id: _editingInfo?.id ?? '',
        title: _titleController.text,
        content: _contentController.text,
        order: int.tryParse(_orderController.text) ?? 0,
      );

      if (_editingInfo == null) {
        await _repository.addCompanyInfo(info);
      } else {
        await _repository.updateCompanyInfo(info);
      }

      Navigator.of(context).pop();
      _refreshInfo();
    }
  }

  Future<void> _deleteInfo(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить раздел?'),
        content: const Text('Вы уверены, что хотите удалить этот раздел?'),
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
      await _repository.deleteCompanyInfo(id);
      _refreshInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление информацией о компании'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startAddInfo,
            tooltip: 'Добавить раздел',
          ),
        ],
      ),
      body: FutureBuilder<List<CompanyInfo>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final infoList = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: infoList.length,
            itemBuilder: (context, index) {
              final info = infoList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(info.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(info.content),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _startEditInfo(info),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteInfo(info.id),
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
}