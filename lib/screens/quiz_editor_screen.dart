import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_edit_screen.dart';
import '../../models/quiz_model.dart';

class QuizEditorScreen extends StatefulWidget {
  const QuizEditorScreen({super.key});

  @override
  _QuizEditorScreenState createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<Quiz>> _quizzesFuture;
  String _selectedType = 'neoflex';

  @override
  void initState() {
    super.initState();
    _quizzesFuture = _fetchQuizzes();
  }

  Future<List<Quiz>> _fetchQuizzes() async {
    final snapshot = await _firestore.collection('quizzes').get();
    return snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
  }

  void _addNewQuiz() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizEditScreen(
          quiz: Quiz(
            id: '',
            title: 'Новый тест',
            description: '',
            questions: [],
            type: _selectedType,
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      final quizzes = _fetchQuizzes();
      setState(() {
        _quizzesFuture = quizzes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Управление тестами')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Все доступные тесты:'),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Quiz>>(
              future: _quizzesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final quizzes = snapshot.data!
                    .where((q) => q.type == _selectedType)
                    .toList();

                return ListView.builder(
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(quiz.title),
                        subtitle: Text('Вопросов: ${quiz.questions.length}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuizEditScreen(quiz: quiz),
                                  ),
                                );
                                if (result == true && mounted) {
                                  final quizzes = _fetchQuizzes();
                                  setState(() {
                                    _quizzesFuture = quizzes;
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteQuiz(quiz.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewQuiz,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteQuiz(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тест?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('quizzes').doc(id).delete();
      final quizzes = _fetchQuizzes();
      setState(() {
        _quizzesFuture = quizzes;
      });
    }
  }
}
