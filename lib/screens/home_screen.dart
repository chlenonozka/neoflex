import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:neoflex/screens/quiz_selection_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  final int points;
  final bool dailyRewardClaimed;
  final VoidCallback onClaimReward;
  final Function(int) onPointsUpdated;

  const HomeScreen({
    super.key,
    required this.points,
    required this.dailyRewardClaimed,
    required this.onClaimReward,
    required this.onPointsUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _username = "Гость";
  String _email = "";
  int _userRank = 0;
  int _maxScore = 0;
  int _activeDays = 0;
  bool _isGuest = false;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLeaderboard();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _isGuest = data['isGuest'] ?? false;
          _username = data['name'] ?? user.displayName ?? "Гость";
          _email = user.email ?? "";
          if (!_isGuest) {
            _maxScore = data['maxScore'] ?? 0;
            _activeDays = data['activeDays'] ?? 1;
          }
        });
      }
    } catch (e) {
      print("Ошибка при загрузке данных пользователя: $e");
    }
  }

  Future<void> _loadLeaderboard() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isGuest', isEqualTo: false)
          .where('isDeleted', isNotEqualTo: true)
          .orderBy('points', descending: true)
          .limit(5)
          .get();

      final leaderboard = snapshot.docs.map((doc) {
        return {
          'name': doc.data()['name'] ?? 'Аноним',
          'points': doc.data()['points'] ?? 0,
          'maxScore': doc.data()['maxScore'] ?? 0,
          'activeDays': doc.data()['activeDays'] ?? 1,
          'isCurrentUser': doc.id == user.uid,
        };
      }).toList();

      if (!leaderboard.any((entry) => entry['isCurrentUser'] == true)) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && !(userDoc.data()?['isDeleted'] ?? false)) {
          leaderboard.add({
            'name': userDoc.data()?['name'] ?? 'Вы',
            'points': userDoc.data()?['points'] ?? 0,
            'maxScore': userDoc.data()?['maxScore'] ?? 0,
            'activeDays': userDoc.data()?['activeDays'] ?? 1,
            'isCurrentUser': true,
          });
        }
      }

      leaderboard.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
      final rank = leaderboard.indexWhere((entry) => entry['isCurrentUser'] == true) + 1;

      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _userRank = rank;
        });
      }
    } catch (e) {
      print("Ошибка при загрузке лидерборда: $e");
    }
  }

  Future<void> _updateUserStats(int score) async {
    if (_isGuest || !mounted) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);

    try {
      await ref.set({
        'points': FieldValue.increment(score),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final doc = await ref.get();
      final data = doc.data();
      final currentMax = data?['maxScore'] ?? 0;
      if (score > currentMax) {
        await ref.update({'maxScore': score});
      }

      final lastActive = (data?['lastActive'] as Timestamp?)?.toDate();
      if (lastActive == null || !_isSameDay(lastActive, DateTime.now())) {
        await ref.update({'activeDays': FieldValue.increment(1)});
      }

      await _loadUserData();
      await _loadLeaderboard();
    } catch (e) {
      print("Ошибка при обновлении статистики: $e");
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildStatItem(String title, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(value.toString(), style: const TextStyle(fontSize: 14, color: Colors.blue)),
        ],
      ),
    );
  }

  String pluralize(int number, String one, String few, String many) {
    if (number % 10 == 1 && number % 100 != 11) {
      return '$number $one';
    } else if ((number % 10 >= 2 && number % 10 <= 4) &&
        !(number % 100 >= 12 && number % 100 <= 14)) {
      return '$number $few';
    } else {
      return '$number $many';
    }
  }
  void handlePointsUpdated(int newPoints) {
    widget.onPointsUpdated(newPoints);
    // Уберите задержку и сразу обновите данные
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserData();
        _loadLeaderboard();
      });
    }
  }

  Widget _buildUserStats() {
    if (_isGuest) {
      return Column(
        children: [
          const Text('Статистика недоступна', style: TextStyle(fontSize: 16, color: Colors.grey)),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/auth'),
            child: const Text('Войдите для просмотра статистики', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildStatItem("Рейтинг", _userRank == 0 ? "-" : "#$_userRank"),
        _buildStatItem("Рекорд", pluralize(_maxScore, "очко", "очка", "очков")),
        _buildStatItem("Активность", pluralize(_activeDays, "день", "дня", "дней")),
      ],
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user) {
    final name = user['name'] ?? "Гость";
    final isCurrentUser = user['isCurrentUser'] ?? false;
    final points = user['points'] ?? 0;
    final maxScore = user['maxScore'] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
        child: Text(name[0], style: TextStyle(color: isCurrentUser ? Colors.blue : Colors.black)),
      ),
      title: Text(
        name,
        style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(pluralize(points, "очко", "очка", "очков")),
          Text("Рекорд: ${pluralize(maxScore, "очко", "очка", "очков")}"),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(child: Icon(Icons.person), radius: 40),
            const SizedBox(height: 16),
            Text(_username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),
            _buildUserStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Ваши очки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 30),
                const SizedBox(width: 8),
                Text('${widget.points}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRewardCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Ежедневная награда', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Заходите каждый день и получайте бонусные очки!'),
            const SizedBox(height: 16),
            ElevatedButton(
            onPressed: _isGuest
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Для получения наград необходимо войти в аккаунт')),
                    )
                : widget.dailyRewardClaimed
                    ? null
                    : () {
                        widget.onClaimReward();
                        handlePointsUpdated(widget.points + 50); // обновить очки и рейтинг
                      },
              child: Text(_isGuest
                  ? 'Только для зарегистрированных'
                  : widget.dailyRewardClaimed
                  
                      ? 'Уже получено'
                      : 'Получить +50 очков'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Квиз о Neoflex', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Проверьте свои знания о компании и заработайте очки!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('quizzes')
                      .where('type', isEqualTo: 'neoflex')
                      .get();

                  if (snapshot.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Квизы не найдены')),
                    );
                    return;
                  }

                  final selectedQuiz = await Navigator.push<QueryDocumentSnapshot>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizSelectionScreen(quizzes: snapshot.docs),
                    ),
                  );

                  if (selectedQuiz == null) return;

                  final data = selectedQuiz.data() as Map<String, dynamic>;

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(quizData: data),
                    ),
                  );

                  if (result != null && result is Map && result['shouldUpdate'] == true) {
                    final newScore = result['score'] as int;
                    widget.onPointsUpdated(widget.points + newScore);
                    
                    // Уберите задержку и добавьте принудительное обновление
                    await _updateUserStats(newScore);
                    await _loadUserData();
                    await _loadLeaderboard();
                    
                    // Обновите состояние виджета
                    if (mounted) setState(() {});
                  }
                } catch (e) {
                  print('Ошибка загрузки квиза: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось загрузить квиз')),
                  );
                }
              },
              child: const Text('Начать квиз'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUserCard(),
          const SizedBox(height: 24),
          _buildPointsCard(),
          const SizedBox(height: 16),
          _buildDailyRewardCard(),
          const SizedBox(height: 16),
          _buildQuizCard(),
          if (!_isGuest) ...[
            const SizedBox(height: 16),
            const Text("Топ игроков", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _leaderboard.map(_buildLeaderboardItem).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
