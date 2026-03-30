import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'chatbot_provider.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    // Send it
    ref.read(chatProvider.notifier).sendMessage(text);

    // Clear and focus
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen to chat state updates
    final chatState = ref.watch(chatProvider);
    
    // We scroll automatically when new messages arrive.
    // Instead of doing it in build randomly, using a listener or just auto-scrolling
    // when the list changes is good practice. We'll simply call it right after build.
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Tutor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Chat List ───────────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              itemCount: chatState.messages.length + (chatState.isTyping ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                // Determine if this index is the typing indicator
                if (index == chatState.messages.length) {
                  return _buildMessageBubble(
                    context,
                    message: "Thinking...",
                    isBot: true,
                    isTyping: true,
                  );
                }

                // Normal message
                final msg = chatState.messages[index];
                return _buildMessageBubble(
                  context,
                  message: msg.text,
                  isBot: msg.isBot,
                );
              },
            ),
          ),
          
          // ── Input Area ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      fillColor: AppColors.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: chatState.isTyping ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: chatState.isTyping ? AppColors.glassBorder : AppColors.primaryStart,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  Widget _buildMessageBubble(
    BuildContext context, {
    required String message,
    required bool isBot,
    bool isTyping = false,
  }) {
    // If it's a typing indicator, render a simple loader instead of text
    Widget content;
    if (isTyping) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: AppColors.primaryStart,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Thinking...',
            style: TextStyle(
              color: AppColors.primaryStart,
              fontStyle: FontStyle.italic,
            ),
          )
        ],
      );
    } else {
      content = Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isBot ? AppColors.textPrimary : Colors.white,
            ),
      );
    }

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isBot ? AppColors.surface : AppColors.primaryStart,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isBot ? 4 : 24),
            bottomRight: Radius.circular(isBot ? 24 : 4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A3E2A1E), // Soft shadow
              offset: Offset(4, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}
