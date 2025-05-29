import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAdmin = true;
  bool _checkingAdminStatus = false;
  bool _showDeletedUsers = false;

  Future<bool> _reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReauthDialog(userEmail: user.email!),
    );

    if (password == null) return false;

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка аутентификации: ${e.toString()}')),
      );
      return false;
    }
  }

  Future<void> _verifyAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.exists && (userDoc.data()?['isAdmin'] ?? false);
        _checkingAdminStatus = false;
      });
    } catch (e) {
      setState(() => _checkingAdminStatus = false);
    }
  }

  Future<void> _handleFirestoreOperation(Future<void> operation) async {
    try {
      await operation;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final reauthenticated = await _reauthenticate();
        if (reauthenticated) {
          await operation; // Повторяем операцию после аутентификации
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _verifyAdminStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdminStatus) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Доступ запрещен')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        actions: [
          IconButton(
            icon: Icon(_showDeletedUsers ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showDeletedUsers = !_showDeletedUsers;
              });
            },
            tooltip: _showDeletedUsers ? 'Скрыть удаленных' : 'Показать удаленных',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск пользователей',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildUsersQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;

                if (users.isEmpty) {
                  return const Center(child: Text('Пользователи не найдены'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    
                    // Безопасное получение полей мягкого удаления
                    final isDeleted = data['isDeleted'] ?? false;
                    final deletedAt = data['deletedAt']?.toDate();
                    final deletedBy = data['deletedBy']?.toString();

                    return _UserCard(
                      userId: user.id,
                      name: data['name'] ?? 'Без имени',
                      email: data['email'] ?? 'Нет email',
                      points: data['points'] ?? 0,
                      maxPoints: data['maxPoints'] ?? 0,
                      createdAt: data['createdAt']?.toDate(),
                      lastActive: data['lastActive']?.toDate(),
                      maxActiveDays: data['maxActiveDays'] ?? 0,
                      isAdmin: data['isAdmin'] ?? false,
                      isDeleted: isDeleted,
                      deletedAt: deletedAt,
                      deletedBy: deletedBy,
                      onSave: (updates) => _handleFirestoreOperation(
                        _firestore.collection('users').doc(user.id).update(updates),
                      ),
                      onDelete: () => _softDeleteUser(user.id, true),
                      onRestore: () => _softDeleteUser(user.id, false),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildUsersQuery() {
    Query query = _firestore.collection('users');

    if (!_showDeletedUsers) {
      query = query.where('isDeleted', isNotEqualTo: true);
    }

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThan: '${_searchQuery}z');
    }

    return query.snapshots();
  }

  Future<void> _softDeleteUser(String userId, bool delete) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final updates = {
      'isDeleted': delete,
      'deletedAt': delete ? DateTime.now() : null,
      'deletedBy': delete ? currentUser.uid : null,
    };

    await _handleFirestoreOperation(
      _firestore.collection('users').doc(userId).update(updates),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(delete ? 'Пользователь удален' : 'Пользователь восстановлен')),
    );
  }
}

class _ReauthDialog extends StatefulWidget {
  final String userEmail;

  const _ReauthDialog({required this.userEmail});

  @override
  __ReauthDialogState createState() => __ReauthDialogState();
}

class __ReauthDialogState extends State<_ReauthDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Требуется аутентификация'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Введите пароль для ${widget.userEmail}'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
              ? const CircularProgressIndicator()
              : const Text('Продолжить'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    Navigator.pop(context, _passwordController.text);
  }
}

class _UserCard extends StatefulWidget {
  final String userId;
  final String name;
  final String email;
  final int points;
  final int maxPoints;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final int maxActiveDays;
  final bool isAdmin;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final Future<void> Function(Map<String, dynamic> updates) onSave;
  final Future<void> Function() onDelete;
  final Future<void> Function() onRestore;

  const _UserCard({
    required this.userId,
    required this.name,
    required this.email,
    required this.points,
    required this.maxPoints,
    this.createdAt,
    this.lastActive,
    required this.maxActiveDays,
    required this.isAdmin,
    required this.isDeleted,
    this.deletedAt,
    this.deletedBy,
    required this.onSave,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  __UserCardState createState() => __UserCardState();
}

class __UserCardState extends State<_UserCard> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _pointsController;
  late TextEditingController _maxPointsController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _pointsController = TextEditingController(text: widget.points.toString());
    _maxPointsController = TextEditingController(text: widget.maxPoints.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pointsController.dispose();
    _maxPointsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave({
        'name': _nameController.text,
        'email': _emailController.text,
        'points': int.tryParse(_pointsController.text) ?? widget.points,
        'maxPoints': int.tryParse(_maxPointsController.text) ?? widget.maxPoints,
      });

      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изменения сохранены')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final cardColor = widget.isDeleted ? Colors.grey[300] : null;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isDeleted) ...[
              const Text(
                'УДАЛЕНО',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.deletedAt != null)
                _buildInfoRow('Дата удаления:', dateFormat.format(widget.deletedAt!)),
              if (widget.deletedBy != null)
                _buildInfoRow('Удалил:', widget.deletedBy!),
              const SizedBox(height: 8),
            ],
            if (!_isEditing) ...[
              _buildInfoRow('Имя:', widget.name),
              _buildInfoRow('Email:', widget.email),
              _buildInfoRow('Очки:', widget.points.toString()),
              _buildInfoRow('Макс. очки:', widget.maxPoints.toString()),
              _buildInfoRow('Макс. дней активности:', widget.maxActiveDays.toString()),
              _buildInfoRow('Статус:', widget.isAdmin ? 'Администратор' : 'Пользователь'),
              if (widget.createdAt != null)
                _buildInfoRow('Дата создания:', dateFormat.format(widget.createdAt!)),
              if (widget.lastActive != null)
                _buildInfoRow('Последняя активность:', dateFormat.format(widget.lastActive!)),
            ] else ...[
              _buildEditableField('Имя:', _nameController),
              _buildEditableField('Email:', _emailController),
              _buildEditableField('Очки:', _pointsController, isNumber: true),
              _buildEditableField('Макс. очки:', _maxPointsController, isNumber: true),
              _buildInfoRow('Макс. дней активности:', widget.maxActiveDays.toString()),
              _buildInfoRow('Статус:', widget.isAdmin ? 'Администратор' : 'Пользователь'),
              if (widget.createdAt != null)
                _buildInfoRow('Дата создания:', dateFormat.format(widget.createdAt!)),
              if (widget.lastActive != null)
                _buildInfoRow('Последняя активность:', dateFormat.format(widget.lastActive!)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isEditing && !widget.isDeleted)
                  ElevatedButton(
                    onPressed: () => setState(() => _isEditing = true),
                    child: const Text('Редактировать'),
                  ),
                if (!_isEditing && widget.isDeleted)
                  ElevatedButton(
                    onPressed: widget.onRestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Восстановить'),
                  ),
                if (!_isEditing && !widget.isDeleted)
                  const SizedBox(width: 8),
                if (!_isEditing && !widget.isDeleted)
                  ElevatedButton(
                    onPressed: widget.onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Удалить'),
                  ),
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isSaving ? null : () {
                      setState(() {
                        _isEditing = false;
                        _nameController.text = widget.name;
                        _emailController.text = widget.email;
                        _pointsController.text = widget.points.toString();
                        _maxPointsController.text = widget.maxPoints.toString();
                      });
                    },
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving 
                        ? const CircularProgressIndicator()
                        : const Text('Сохранить'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}