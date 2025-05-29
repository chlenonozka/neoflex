import 'package:flutter/material.dart';
import '../../models/quiz_model.dart';

class QuestionEditScreen extends StatefulWidget {
  final Question question;

  const QuestionEditScreen({
    super.key,
    required this.question,
  });

  @override
  _QuestionEditScreenState createState() => _QuestionEditScreenState();
}

class _QuestionEditScreenState extends State<QuestionEditScreen> {
  late TextEditingController _textController;
  late List<TextEditingController> _answerControllers;
  late int _correctIndex;
  late int _points;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question.text);

    // Обеспечиваем 4 варианта ответа
    final answers = List<String>.filled(4, '');
    for (int i = 0; i < widget.question.answers.length && i < 4; i++) {
      answers[i] = widget.question.answers[i];
    }

    _answerControllers =
        answers.map((answer) => TextEditingController(text: answer)).toList();
    _correctIndex = widget.question.correctIndex.clamp(0, 3);
    _points = widget.question.points;
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveQuestion() {
    if (!_formKey.currentState!.validate()) return;

    final question = Question(
      text: _textController.text.trim(),
      answers: _answerControllers.map((c) => c.text.trim()).toList(),
      correctIndex: _correctIndex,
      points: _points,
    );

    Navigator.of(context).pop(question); // Возвращаем результат
  }

  String? _validateNotEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Поле не может быть пустым';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование вопроса'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveQuestion,
            tooltip: 'Сохранить вопрос',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Текст вопроса',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: _validateNotEmpty,
              ),
              const SizedBox(height: 20),
              const Text(
                'Варианты ответов:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._answerControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: _correctIndex,
                        onChanged: (value) {
                          setState(() {
                            _correctIndex = value!;
                          });
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Ответ ${index + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: _validateNotEmpty,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: _points,
                items: [5, 10, 15, 20]
                    .map(
                      (points) => DropdownMenuItem(
                        value: points,
                        child: Text('$points очков'),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Баллы за вопрос',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _points = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saveQuestion,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить вопрос'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
