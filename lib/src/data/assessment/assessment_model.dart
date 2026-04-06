import '../../domain/assessment/assessment.dart';

class AssessmentModel extends Assessment {
  AssessmentModel({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required List<QuestionModel> super.questions,
    super.score = 0,
  });

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    return AssessmentModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      questions: (json['questions'] as List)
          .map((q) => QuestionModel.fromJson(q))
          .toList(),
      score: json['score'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'questions': (questions as List<QuestionModel>)
          .map((q) => q.toJson())
          .toList(),
      'score': score,
    };
  }
}

class QuestionModel extends Question {
  QuestionModel({
    required super.id,
    required super.text,
    required super.options,
    required super.correctOptionIndex,
    super.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctOptionIndex: json['correctOptionIndex'] ?? 0,
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
    };
  }
}
