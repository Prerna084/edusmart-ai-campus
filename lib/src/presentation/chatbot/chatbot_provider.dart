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
        data: {'message': trimmed},
      );
      
      final botOutput = response.data['response'] ?? "I'm sorry, I couldn't process that.";
      final botMessage = ChatMessage(text: botOutput, isBot: true);

      // 3. Update with bot message
      state = state.copyWith(
        messages: [...state.messages, botMessage],
        isTyping: false,
      );
    } catch (e) {
      // Offline fallback / error
      final errorMessage = ChatMessage(
        text: 'System: Unable to connect to backend right now. Ensure Uvicorn is running!',
        isBot: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isTyping: false,
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
