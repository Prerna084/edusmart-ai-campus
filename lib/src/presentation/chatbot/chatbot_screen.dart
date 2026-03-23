import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildMessageBubble(
                  context,
                  message: 'Hello Alex! I am your AI Tutor. What would you like to learn today?',
                  isBot: true,
                ),
                const SizedBox(height: 16),
                _buildMessageBubble(
                  context,
                  message: 'Can you explain Binary Search Trees from my Data Structures course?',
                  isBot: false,
                ),
                const SizedBox(height: 16),
                _buildMessageBubble(
                  context,
                  message: 'Certainly! A Binary Search Tree is a data structure where each node has at most two children, and the left child is always smaller than the parent, while the right child is greater. Would you like a code example?',
                  isBot: true,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryStart,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, {required String message, required bool isBot}) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        width: MediaQuery.of(context).size.width * 0.75,
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isBot ? AppColors.textPrimary : AppColors.primaryStart,
          ),
        ),
      ),
    );
  }
}
