import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _adminName = 'Администратор';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _adminName = userDoc.data()?['name'] ?? 'Администратор';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      // Если пользователь не авторизован, вернемся на экран авторизации
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Административная панель'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Приветствие с именем
                  Text(
                    'Добро пожаловать,',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _adminName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Подпись о входе под админом
                  Text(
                    'Вы вошли как администратор',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 40),
                  // Кнопки навигации
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildAdminButton(
                          icon: Icons.people,
                          label: 'Пользователи',
                          color: Colors.blue,
                          onTap: () => _navigateTo('/admin/users'),
                        ),
                        _buildAdminButton(
                          icon: Icons.quiz,
                          label: 'Тесты',
                          color: Colors.green,
                          onTap: () => _navigateTo('/admin/tests'),
                        ),
                        _buildAdminButton(
                          icon: Icons.shopping_cart,
                          label: 'Магазин',
                          color: Colors.orange,
                          onTap: () => _navigateTo('/admin/shop'),
                        ),
                        _buildAdminButton(
                          icon: Icons.contact_mail,
                          label: 'Контакты',
                          color: Colors.purple,
                          onTap: () => _navigateTo('/admin/contacts'),
                        ),
                        _buildAdminButton(
                          icon: Icons.business,
                          label: 'О компании',
                          color: Colors.indigo,
                          onTap: () => _navigateTo('/admin/company-info'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAdminButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}