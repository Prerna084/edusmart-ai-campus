import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class ChatMessage {
  final String text;
  final bool isBot;

  const ChatMessage({
    required this.text,
    required this.isBot,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  String? _lastLearningTopic;

  ChatNotifier(this._ref) : super(const ChatState()) {
    // Initial greeting
    state = state.copyWith(
      messages: [
        const ChatMessage(
          text: 'Hello! I am your AI Tutor. What would you like to learn today?',
          isBot: true,
        ),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final enrichedPrompt = _buildContextualPrompt(trimmed);

    // 1. Add user message
    final userMessage = ChatMessage(text: trimmed, isBot: false);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    try {
      final dio = _ref.read(dioProvider);
      
      // 2. Call backend simulation endpoint
      final response = await dio.post(
        '/tutor/ask',
        data: {'message': enrichedPrompt},
      );

      final botOutput = _extractBotOutput(response.data) ?? _localTutorReply(enrichedPrompt);
      final botMessage = ChatMessage(text: botOutput, isBot: true);

      // 3. Update with bot message
      state = state.copyWith(
        messages: [...state.messages, botMessage],
        isTyping: false,
      );
    } catch (e) {
      // Offline fallback / error
      final errorMessage = ChatMessage(
        text: _localTutorReply(enrichedPrompt),
        isBot: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isTyping: false,
      );
    }
  }

  String _buildContextualPrompt(String currentInput) {
    final normalized = currentInput.toLowerCase();
    final shortFollowUpInputs = {
      'yes',
      'yeah',
      'ok',
      'okay',
      'sure',
      'beginners',
      'beginner',
      'start with basics',
      'arrays',
      'questions for practice',
      'practice questions',
    };

    final topicKeywords = [
      'dsa',
      'algorithm',
      'algorithms',
      'array',
      'arrays',
      'linked list',
      'stack',
      'queue',
      'tree',
      'graph',
      'flutter',
      'riverpod',
      'python',
      'fastapi',
    ];

    if (topicKeywords.any((keyword) => normalized.contains(keyword))) {
      _lastLearningTopic = currentInput;
      return currentInput;
    }

    if (shortFollowUpInputs.contains(normalized) && _lastLearningTopic != null) {
      return 'Context topic: $_lastLearningTopic. Student follow-up: $currentInput';
    }

    return currentInput;
  }

  String? _extractBotOutput(dynamic payload) {
    if (payload == null) return null;
    if (payload is Map<String, dynamic>) {
      final value = payload['response'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }
    return null;
  }

  String _localTutorReply(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('dsa') || msg.contains('algorithm')) {
      return 'Beginner DSA plan: 1) Arrays + Strings, 2) Hashing, 3) Two pointers, 4) Sliding window, 5) Linked List, 6) Stack/Queue, 7) Trees. Reply with "arrays practice" and I will give practice questions.';
    }
    if (msg.contains('arrays') || msg.contains('array')) {
      return 'Arrays basics: indexing, traversal, insertion/deletion idea, and time complexity (read O(1), search O(n)). Practice: find max, reverse array, remove duplicates, and two-sum.';
    }
    if (msg.contains('practice')) {
      return 'Practice set (arrays): 1) Find largest element, 2) Second largest, 3) Move zeros to end, 4) Left rotate by 1, 5) Two-sum. Want solutions in Python or Dart?';
    }
    if (msg.contains('flutter') || msg.contains('riverpod')) {
      return 'Flutter tip: keep UI in widgets and business logic in providers/notifiers. For Riverpod, use StateNotifier for mutable flows and FutureProvider for read-only API fetches.';
    }
    if (msg.contains('python') || msg.contains('fastapi')) {
      return 'FastAPI tip: define Pydantic request/response models, keep DB code in services, and validate inputs early. I can also help with a sample endpoint for your exact use case.';
    }
    if (msg.contains('assessment') || msg.contains('quiz')) {
      return 'For quiz prep, focus on one topic at a time: concept -> example -> 3 practice questions. Tell me your topic and I will generate a mini practice set.';
    }
    if (msg.contains('attendance') || msg.contains('camera') || msg.contains('face')) {
      return 'Attendance flow is: register face -> capture image -> `/attendance/mark` -> today records via `/attendance/today`. If any step fails, I can help debug that endpoint.';
    }
    if (msg.contains('hello') || msg.contains('hi')) {
      return 'Hello! Ask me any topic from your syllabus and I will explain it step-by-step.';
    }
    return 'I can help with Flutter, FastAPI, attendance APIs, and quiz topics. Ask a specific question (for example: "Explain Riverpod StateNotifier with example").';
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
