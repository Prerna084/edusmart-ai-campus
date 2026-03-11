class Assessment {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final List<Question> questions;
  final int score;

  Assessment({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.questions,
    this.score = 0,
  });
}

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });
}
