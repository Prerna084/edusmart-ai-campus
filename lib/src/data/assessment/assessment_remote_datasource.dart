import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'assessment_model.dart';

class AssessmentRemoteDatasource {
  final GenerativeModel _model;

  AssessmentRemoteDatasource({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  Future<AssessmentModel> generateAssessment(String topic) async {
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
    final response = await _model.generateContent(content);
    
    if (response.text == null) {
      throw Exception('Failed to generate assessment');
    }

    final Map<String, dynamic> data = jsonDecode(response.text!);
    // Ensure createdAt is present
    data['createdAt'] = DateTime.now().toIso8601String();
    return AssessmentModel.fromJson(data);
  }
}
