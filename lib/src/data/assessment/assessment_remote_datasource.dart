import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'assessment_model.dart';

class AssessmentRemoteDatasource {
  final String apiKey;
  final Random _random = Random();

  AssessmentRemoteDatasource({required this.apiKey});

  Future<AssessmentModel> generateAssessment(String topic) async {
    if (apiKey.isEmpty) {
      await Future.delayed(const Duration(seconds: 2));
      final Map<String, dynamic> mockData = _buildMockAssessment(topic);
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

  Map<String, dynamic> _buildMockAssessment(String topic) {
    final now = DateTime.now();
    final topicLabel = topic.trim().isEmpty ? 'General Concepts' : topic.trim();
    final questionBank = <Map<String, dynamic>>[
      {
        "text": "Which statement best describes $topicLabel in practice?",
        "options": [
          "It solves only one fixed problem",
          "It is used differently based on project needs",
          "It can never be combined with other tools",
          "It is only useful for beginners"
        ],
        "correctOptionIndex": 1,
        "explanation": "$topicLabel is usually applied contextually."
      },
      {
        "text": "What is the best first step when learning $topicLabel deeply?",
        "options": [
          "Memorize definitions only",
          "Avoid implementation exercises",
          "Study core concepts and apply small examples",
          "Skip fundamentals and jump to advanced topics"
        ],
        "correctOptionIndex": 2,
        "explanation": "Balanced theory + practice builds strong understanding."
      },
      {
        "text": "Which choice is most important when evaluating a $topicLabel solution?",
        "options": [
          "Readability and correctness",
          "Using the longest code possible",
          "Avoiding documentation",
          "Ignoring performance completely"
        ],
        "correctOptionIndex": 0,
        "explanation": "Correct, maintainable solutions are the foundation."
      },
      {
        "text": "In team projects, $topicLabel is most effective when:",
        "options": [
          "Only one person understands it",
          "Everyone follows shared conventions",
          "There are no tests or reviews",
          "Requirements are never discussed"
        ],
        "correctOptionIndex": 1,
        "explanation": "Shared conventions improve collaboration and quality."
      },
      {
        "text": "Which habit improves long-term mastery of $topicLabel?",
        "options": [
          "Practicing consistently with feedback",
          "Learning only once and stopping",
          "Copying code without understanding",
          "Avoiding debugging"
        ],
        "correctOptionIndex": 0,
        "explanation": "Regular deliberate practice strengthens retention."
      },
      {
        "text": "A common mistake while using $topicLabel is:",
        "options": [
          "Clarifying requirements first",
          "Testing assumptions early",
          "Ignoring edge cases and constraints",
          "Documenting decisions"
        ],
        "correctOptionIndex": 2,
        "explanation": "Edge cases and constraints are crucial for robust results."
      },
      {
        "text": "When optimizing work in $topicLabel, you should prioritize:",
        "options": [
          "Blind micro-optimizations",
          "Measuring bottlenecks before changes",
          "Removing all abstractions immediately",
          "Skipping validation"
        ],
        "correctOptionIndex": 1,
        "explanation": "Measurement-driven optimization avoids wasted effort."
      },
      {
        "text": "How should you validate your understanding of $topicLabel?",
        "options": [
          "Explain concepts and build a working example",
          "Only watch tutorials passively",
          "Avoid peer review",
          "Ignore incorrect outputs"
        ],
        "correctOptionIndex": 0,
        "explanation": "Teaching and implementation reveal true understanding."
      },
    ];

    final shuffled = [...questionBank]..shuffle(_random);
    final selected = shuffled.take(5).toList();
    final questions = selected.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final q = entry.value;
      return {
        "id": "q$idx-${now.microsecondsSinceEpoch}",
        "text": q["text"],
        "options": q["options"],
        "correctOptionIndex": q["correctOptionIndex"],
        "explanation": q["explanation"],
      };
    }).toList();

    return {
      "id": "mock_id_${now.microsecondsSinceEpoch}",
      "title": "Practice Quiz: $topicLabel",
      "description": "Generated locally because no API key was provided.",
      "createdAt": now.toIso8601String(),
      "questions": questions,
    };
  }
}
