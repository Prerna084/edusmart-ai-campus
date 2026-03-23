import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'assessment_model.dart';

class AssessmentRemoteDatasource {
  final String apiKey;

  AssessmentRemoteDatasource({required this.apiKey});

  Future<AssessmentModel> generateAssessment(String topic) async {
    if (apiKey.isEmpty) {
      await Future.delayed(const Duration(seconds: 2));
      final Map<String, dynamic> mockData = {
        "id": "mock_id_${DateTime.now().millisecondsSinceEpoch}",
        "title": "Mock Quiz: $topic",
        "description": "This is a mock quiz because no API key was provided.",
        "createdAt": DateTime.now().toIso8601String(),
        "questions": [
          {
            "id": "q1",
            "text": "What is the primary feature of $topic?",
            "options": ["Speed", "Flexibility", "Security", "All of the above"],
            "correctOptionIndex": 3,
            "explanation": "It features all of these."
          },
          {
            "id": "q2",
            "text": "When was $topic typically introduced/created?",
            "options": ["2010", "2015", "2020", "Unknown"],
            "correctOptionIndex": 1,
            "explanation": "Around 2015."
          },
          {
            "id": "q3",
            "text": "Which entity primarily maintains or supports $topic?",
            "options": ["Google", "Meta", "Microsoft", "Open Source Community"],
            "correctOptionIndex": 0,
            "explanation": "Supported heavily by major tech."
          }
        ]
      };
      return AssessmentModel.fromJson(mockData);
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final prompt = '''
    Generate a 5-question multiple choice assessment on the topic: $topic.
    Return a JSON object with the following structure:
    {
      "id": "unique_id",
      "title": "Assessment Title",
      "description": "Short description",
      "createdAt": "ISO8601 string",
      "questions": [
        {
          "id": "q1",
          "text": "Question text",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "correctOptionIndex": 0,
          "explanation": "Why this is correct"
        }
      ]
    }
    ''';

    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    
    if (response.text == null) {
      throw Exception('Failed to generate assessment');
    }

    final Map<String, dynamic> data = jsonDecode(response.text!);
    // Ensure createdAt is present
    data['createdAt'] = DateTime.now().toIso8601String();
    return AssessmentModel.fromJson(data);
  }
}
