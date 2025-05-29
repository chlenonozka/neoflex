import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const AuthScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastUid;
  String? _lastName;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUid = prefs.getString('lastUid');
      _lastName = prefs.getString('lastName');
      if (_lastUid != null && _lastName != null) {
        _animationController?.forward();
      }
    });
  }

  Future<void> _removeSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastUid');
    await prefs.remove('lastName');
    await prefs.remove('lastEmail');
    await prefs.remove('lastPassword');
    _animationController?.reverse().then((_) {
      setState(() {
        _lastUid = null;
        _lastName = null;
      });
    });
  }

  Future<void> _saveLastUser(String uid, String name, {String? email, String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastUid', uid);
    await prefs.setString('lastName', name);
    if (email != null && password != null) {
      await prefs.setString('lastEmail', email);
      await prefs.setString('lastPassword', password);
    }
    _animationController?.forward();
  }

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      // 1. Сначала аутентифицируемся
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 2. Затем проверяем данные в Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Данные пользователя не найдены',
        );
      }

      if (userDoc.data()?['isDeleted'] == true) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'account-disabled',
          message: 'Аккаунт деактивирован',
        );
      }

      await _saveLastUser(
        userCredential.user!.uid,
        userCredential.user!.displayName ?? userDoc.data()?['name'] ?? 'Пользователь',
        email: email,
        password: password,
      );
    } else {
        // Код регистрации остается без изменений
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email уже зарегистрирован',
          );
        }

        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await userCredential.user!.updateDisplayName(_nameController.text.trim());

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': email,
          'points': 0,
          'isGuest': false,
          'maxScore': 0,
          'activeDays': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'isAdmin': false,
          "isDeleted": false,
          "deletedAt": null,
          "deletedBy": null,
        });

        await _saveLastUser(
          userCredential.user!.uid,
          _nameController.text.trim(),
          email: email,
          password: password,
        );
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.code));
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();

      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': 'Гость',
          'isGuest': true,
          'createdAt': FieldValue.serverTimestamp(),
          'isAdmin': false,
        }, SetOptions(merge: true));
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка входа гостя');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _loginWithSavedCredentials() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('lastEmail');
    final password = prefs.getString('lastPassword');

    // 1. Проверяем сохраненные данные
    if (email == null || password == null) {
      await _removeSavedUser();
      throw FirebaseAuthException(
        code: 'no-saved-credentials',
        message: 'Сохраненные данные входа не найдены',
      );
    }

    // 2. Пытаемся войти
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 3. Проверяем данные пользователя в Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    // 4. Проверяем существование записи
    if (!userDoc.exists) {
      await FirebaseAuth.instance.signOut();
      await _removeSavedUser();
      throw FirebaseAuthException(
        code: 'user-data-not-found',
        message: 'Данные пользователя не найдены',
      );
    }

    // 5. Проверяем, не деактивирован ли аккаунт
    if (userDoc.data()?['isDeleted'] == true) {
      await FirebaseAuth.instance.signOut();
      await _removeSavedUser();
      throw FirebaseAuthException(
        code: 'account-disabled',
        message: 'Аккаунт деактивирован',
      );
    }

    // 6. Проверяем соответствие email
    final storedEmail = userDoc.data()?['email'];
    if (storedEmail != email) {
      await FirebaseAuth.instance.signOut();
      await _removeSavedUser();
      throw FirebaseAuthException(
        code: 'email-mismatch',
        message: 'Email не совпадает с сохраненным',
      );
    }

    // 7. Все проверки пройдены - перенаправляем
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  } on FirebaseAuthException catch (e) {
    // Специальная обработка ошибки "user-not-found"
    if (e.code == 'user-not-found') {
      await _removeSavedUser();
    }
    setState(() => _errorMessage = _getErrorMessage(e.code));
  } catch (e) {
    setState(() => _errorMessage = 'Ошибка быстрого входа');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _navigateToAdminAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminAuthScreen()),
    );
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email уже зарегистрирован';
      case 'invalid-email':
        return 'Неверный формат email';
      case 'weak-password':
        return 'Пароль должен быть ≥6 символов';
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'account-disabled':
        return 'Аккаунт деактивирован. Обратитесь к администратору.';
      default:
        return 'Ошибка авторизации';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Сменить тему',
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 64),

                Center(
                  child: Text(
                    'Neoflex Quiz',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(height: 24),

                SizeTransition(
                  sizeFactor: _fadeAnimation ?? kAlwaysCompleteAnimation,
                  axisAlignment: -1,
                  child: _lastUid != null && _lastName != null
                      ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: ListTile(
                            leading: const Icon(Icons.account_circle, size: 32),
                            title: Text('Быстрый вход: $_lastName'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: _isLoading ? null : _removeSavedUser,
                            ),
                            onTap: _isLoading ? null : _loginWithSavedCredentials,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                if (!_isLogin)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value!.isEmpty ? 'Введите имя' : null,
                  ),

                if (!_isLogin) const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) => value!.isEmpty || !value.contains('@')
                      ? 'Введите корректный email'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) => value!.isEmpty || value.length < 6
                      ? 'Пароль должен быть ≥6 символов'
                      : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                ),

                const SizedBox(height: 16),

                OutlinedButton(
                  onPressed: _isLoading ? null : _signInAnonymously,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Войти как гость'),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 16),

                // Кнопка входа для администратора
                TextButton(
                  onPressed: _isLoading ? null : _navigateToAdminAuth,
                  child: const Text(
                    'Вход для администратора',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminAuthScreen extends StatefulWidget {
  @override
  _AdminAuthScreenState createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminCodeController = TextEditingController();
  final _nameController = TextEditingController(); // Добавлено поле для имени

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final adminCode = _adminCodeController.text.trim();
      final name = _nameController.text.trim(); // Получаем имя

      // Проверка кода администратора
      if (adminCode != 'ADMIN123') {
        throw FirebaseAuthException(
          code: 'invalid-admin-code',
          message: 'Неверный код администратора',
        );
      }

      if (_isLogin) {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Проверка прав администратора
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists || !(userDoc.data()?['isAdmin'] ?? false)) {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'not-admin',
            message: 'У вас нет прав администратора',
          );
        }

        // Переход на страницу админа
        if (mounted) Navigator.pushReplacementNamed(context, '/admin');
      } else {
        // Регистрация нового администратора
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email уже зарегистрирован',
          );
        }

        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Обновляем displayName в Firebase Auth
        await userCredential.user!.updateDisplayName(name);

        // Сохранение информации об администраторе
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': name, // Используем введенное имя
          'email': email,
          'isAdmin': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Переход на страницу админа
        if (mounted) Navigator.pushReplacementNamed(context, '/admin');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.code));
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email уже зарегистрирован';
      case 'invalid-email':
        return 'Неверный формат email';
      case 'weak-password':
        return 'Пароль должен быть ≥6 символов';
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'invalid-admin-code':
        return 'Неверный код администратора';
      case 'not-admin':
        return 'У вас нет прав администратора';
      default:
        return 'Ошибка авторизации';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход администратора' : 'Регистрация администратора'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 64),

                Center(
                  child: Text(
                    'Административная панель',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(height: 24),

                // Добавлено поле для имени (только при регистрации)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя администратора',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value!.isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) => value!.isEmpty || !value.contains('@')
                      ? 'Введите корректный email'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) => value!.isEmpty || value.length < 6
                      ? 'Пароль должен быть ≥6 символов'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _adminCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Код администратора',
                    prefixIcon: Icon(Icons.security),
                  ),
                  obscureText: true,
                  validator: (value) => value!.isEmpty
                      ? 'Введите код администратора'
                      : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isLogin ? 'Войти' : 'Зарегистрировать'),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Регистрация нового администратора' : 'Уже есть аккаунт? Войти',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}