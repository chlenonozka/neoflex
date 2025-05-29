import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'company_info_screen.dart';
import 'contacts_screen.dart';
import 'shop_screen.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MainScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _points = 0;
  bool _dailyRewardClaimed = false;
  DateTime? _lastRewardDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  Stream<QuerySnapshot> get leaderboardStream {
  return _firestore
      .collection('users')
      .where('isGuest', isEqualTo: false)
      .where('isDeleted', isNotEqualTo: true)
      .orderBy('points', descending: true)
      .limit(5)
      .snapshots();
}

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _points = doc.data()?['points'] ?? 0;
          final lastRewardTimestamp = doc.data()?['lastRewardDate'] as Timestamp?;
          _lastRewardDate = lastRewardTimestamp?.toDate();
          _dailyRewardClaimed = _lastRewardDate != null &&
              DateTime.now().difference(_lastRewardDate!).inHours < 24;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  Future<void> _updatePoints(int newPoints) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'points': newPoints,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _points = newPoints;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления очков: $e')),
        );
      }
    }
  }

  Future<void> _claimDailyReward() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    final now = DateTime.now();
    final newPoints = _points + 50;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'points': newPoints,
        'lastRewardDate': now,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _points = newPoints;
          _dailyRewardClaimed = true;
          _lastRewardDate = now;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ежедневная награда +50 очков!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка получения награды: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neoflex Quiz'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              try {
                await _auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/auth');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка выхода: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            points: _points,
            dailyRewardClaimed: _dailyRewardClaimed,
            onClaimReward: _claimDailyReward,
            onPointsUpdated: (newPoints) {
          setState(() {
            // Вот куда нужно вставить ваш код
            _points = newPoints;
          });
        },
          ),
          const CompanyInfoScreen(),
          ShopScreen(
            points: _points,
            onPointsUpdated: _updatePoints,
          ),
          const ContactsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (!mounted) return;
          setState(() => _currentIndex = index);

          // Всегда обновляем данные при переключении на главную
          if (index == 0) {
            await _loadUserData();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'О компании',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shop),
            label: 'Магазин',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Контакты',
          ),
        ],
      ),
    );
  }
}
