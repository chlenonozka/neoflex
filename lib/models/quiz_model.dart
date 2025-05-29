// models/quiz_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String title;
  final String description;
  final List<Question> questions;
  final String type; // 'career' или 'neoflex'

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.type,
  });

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Quiz(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      questions: (data['questions'] as List).map((q) => Question.fromMap(q)).toList(),
      type: data['type'] ?? 'neoflex',
    );
  }
}

class Question {
  final String text;
  final List<String> answers;
  final int correctIndex;
  final int points;

  Question({
    required this.text,
    required this.answers,
    required this.correctIndex,
    this.points = 10,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['text'],
      answers: List<String>.from(map['answers']),
      correctIndex: map['correctIndex'],
      points: map['points'] ?? 10,
    );
  }
}