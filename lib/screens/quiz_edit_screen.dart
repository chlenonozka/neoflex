import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'question_edit_screen.dart';
import '../../models/quiz_model.dart';

class QuizEditScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizEditScreen({super.key, required this.quiz});

  @override
  _QuizEditScreenState createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends State<QuizEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<Question> _questions;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quiz.title);
    _descriptionController = TextEditingController(text: widget.quiz.description);
    _questions = List<Question>.from(widget.quiz.questions);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveQuiz() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Требуется авторизация');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || !(userDoc.data()?['isAdmin'] ?? false)) {
        throw Exception('Недостаточно прав');
      }

      final quizData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'questions': _questions.map((q) => _questionToMap(q)).toList(),
        'type': widget.quiz.type,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      if (widget.quiz.id.isEmpty) {
        await _firestore.collection('quizzes').add(quizData);
      } else {
        await _firestore.collection('quizzes').doc(widget.quiz.id).update(quizData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _questionToMap(Question question) {
    return {
      'text': question.text,
      'answers': question.answers,
      'correctIndex': question.correctIndex,
      'points': question.points,
    };
  }

  // Добавление вопроса с возвратом результата из QuestionEditScreen
  void _addQuestion() async {
    final newQuestion = await Navigator.push<Question>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditScreen(
          question: Question(
            text: '',
            answers: ['', '', '', ''],
            correctIndex: 0,
            points: 10,
          ),
        ),
      ),
    );

    if (newQuestion != null) {
      setState(() => _questions.add(newQuestion));
    }
  }

  // Редактирование вопроса с возвратом результата
  void _editQuestion(int index) async {
    final editedQuestion = await Navigator.push<Question>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditScreen(
          question: _questions[index],
        ),
      ),
    );

    if (editedQuestion != null) {
      setState(() => _questions[index] = editedQuestion);
    }
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.id.isEmpty ? 'Новый тест' : 'Редактирование'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveQuiz,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название теста',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Вопросы:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(question.text),
                      subtitle: Text(
                        'Правильный ответ: ${question.answers[question.correctIndex]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editQuestion(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _removeQuestion(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить вопрос'),
                  onPressed: _addQuestion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
