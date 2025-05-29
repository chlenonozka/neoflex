import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:neoflex/screens/admin_company_info_screen.dart';
import 'package:neoflex/screens/admin_contacts_screen.dart';
import 'package:neoflex/screens/admin_screen.dart';
import 'package:neoflex/screens/admin_users_screen.dart';
import 'package:neoflex/screens/quiz_editor_screen.dart';
import 'package:neoflex/screens/quiz_selection_screen.dart';
import 'package:neoflex/screens/shop_admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const NeoflexQuizApp());
}

class NeoflexQuizApp extends StatefulWidget {
  const NeoflexQuizApp({super.key});

  @override
  State<NeoflexQuizApp> createState() => _NeoflexQuizAppState();
}

class _NeoflexQuizAppState extends State<NeoflexQuizApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neoflex Quiz',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(
        isDarkMode: _isDarkMode,
        toggleTheme: _toggleTheme,
      ),
      routes: {
        '/auth': (context) => AuthScreen(
              isDarkMode: _isDarkMode,
              toggleTheme: _toggleTheme,
            ),
        '/main': (context) => MainScreen(
              isDarkMode: _isDarkMode,
              toggleTheme: _toggleTheme,
            ),
        '/admin': (context) => AdminScreen(), // Основная админ-панель
        '/admin/users': (context) => AdminUsersScreen(),// // Управление пользователями
        '/admin/tests': (context) => QuizEditorScreen(), // Управление тестами
        '/quiz-selection': (context) => const QuizSelectionScreen(quizzes: [],),
        '/admin/shop': (context) => const ShopAdminScreen(),
        '/admin/company-info': (context) => const AdminCompanyInfoScreen(),
        '/admin/contacts': (context) => AdminContactsScreen(), // Контакты
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const AuthWrapper({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return MainScreen(
            isDarkMode: isDarkMode,
            toggleTheme: toggleTheme,
          );
        }

        return AuthScreen(
          isDarkMode: isDarkMode,
          toggleTheme: toggleTheme,
        );
      },
    );
  }
}
