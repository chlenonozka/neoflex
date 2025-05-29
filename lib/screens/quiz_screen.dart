import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required Map<String, dynamic> quizData});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _quizCompleted = false;
  bool _isGuest = false;

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    await _checkGuestStatus();

    try {
      final snapshot = await _firestore
          .collection('quizzes')
          .where('type', isEqualTo: 'neoflex')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final quizData = snapshot.docs.first.data();
        final List<dynamic> questionsRaw = quizData['questions'] ?? [];
        _questions = questionsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _questions = [];
        _isLoading = false;
      });
      debugPrint('Ошибка при загрузке квиза: $e');
    }
  }

  Future<void> _checkGuestStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      _isGuest = doc.data()?['isGuest'] ?? false;
    }
  }

  void _answerQuestion(int selectedIndex) async {
    final isCorrect = selectedIndex == _questions[_currentQuestionIndex]['correctIndex'];

    if (!_isGuest && isCorrect) {
      _score += _questions[_currentQuestionIndex]['points'] as int;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      setState(() => _quizCompleted = true);
      if (!_isGuest) {
        await _updateUserStats(); // Добавьте await здесь
        if (mounted) {
          Navigator.pop(context, {'score': _score, 'shouldUpdate': true});
        }
      }
    }
  }

  Future<void> _updateUserStats() async {
    final user = _auth.currentUser;
    if (user == null || _isGuest) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.set({
      'points': FieldValue.increment(_score),
      'lastQuizDate': FieldValue.serverTimestamp(),
      'quizzesCompleted': FieldValue.increment(1),
    }, SetOptions(merge: true));

    final doc = await userRef.get();
    final currentMax = doc.data()?['maxScore'] ?? 0;
    if (_score > currentMax) {
      await userRef.update({'maxScore': _score});
    }
  }

  Widget _buildAnswerButton(int index) {
    final answer = (_questions[_currentQuestionIndex]['answers'] as List)[index] as String;
    return ElevatedButton(
      onPressed: () => _answerQuestion(index),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[50],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Квиз')),
        body: const Center(child: Text('Нет доступных квизов')),
      );
    }

    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Результат')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isGuest ? Icons.info : Icons.check_circle,
                  color: _isGuest ? Colors.blue : Colors.green, size: 80),
              const SizedBox(height: 20),
              Text(
                _isGuest ? 'Вы завершили квиз!' : 'Ваш результат: $_score очков',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _isGuest ? 0 : _score),
                child: const Text('Вернуться на главную'),
              ),
              if (_isGuest)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/auth');
                  },
                  child: const Text('Войти в аккаунт'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Neoflex Квиз')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[200],
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'Вопрос ${_currentQuestionIndex + 1}/${_questions.length}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              _questions[_currentQuestionIndex]['text'] as String,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: (_questions[_currentQuestionIndex]['answers'] as List).length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildAnswerButton(index),
              ),
            ),
            if (!_isGuest) ...[
              const SizedBox(height: 16),
              Text(
                'За этот вопрос: +${_questions[_currentQuestionIndex]['points']} очков',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
