import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'quiz_screen.dart';

class QuizSelectionScreen extends StatelessWidget {
  const QuizSelectionScreen({super.key, required List<QueryDocumentSnapshot<Map<String, dynamic>>> quizzes});

  @override
  Widget build(BuildContext context) {
    final quizRef = FirebaseFirestore.instance.collection('quizzes');

    return Scaffold(
      appBar: AppBar(title: const Text('Выбор теста')),
      body: FutureBuilder<QuerySnapshot>(
        future: quizRef.where('type', isEqualTo: 'neoflex').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Нет доступных тестов'));
          }

          final quizzes = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quiz = quizzes[index].data() as Map<String, dynamic>;
              final title = quiz['title'] ?? 'Без названия';
              final description = quiz['description'] ?? '';

              return ListTile(
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(quizData: quiz),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
