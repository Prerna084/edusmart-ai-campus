import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import 'syllabus_provider.dart';

class TopicDetailScreen extends ConsumerWidget {
  final int topicId;
  final String topicTitle;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTopic = ref.watch(topicDetailProvider(topicId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(topicTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: asyncTopic.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryStart),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('Could not load topic content.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('$err', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        data: (topic) => _buildContent(context, topic),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TopicDetail topic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Theory ────────────────────────────────────────────────────
          if (topic.theory != null && topic.theory!.isNotEmpty) ...[
            _sectionHeader(context, Icons.menu_book, 'Theory', AppColors.primaryStart),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Text(
                topic.theory!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.8,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Video ─────────────────────────────────────────────────────
          if (topic.videoUrl != null && topic.videoUrl!.isNotEmpty) ...[
            _sectionHeader(context, Icons.play_circle_fill, 'Video Tutorial', Colors.red.shade400),
            const SizedBox(height: 12),
            _linkCard(
              context,
              icon: Icons.smart_display,
              iconColor: Colors.red.shade400,
              title: 'Watch on YouTube',
              subtitle: topic.videoUrl!,
              url: topic.videoUrl!,
            ),
            const SizedBox(height: 28),
          ],

          // ── Docs ──────────────────────────────────────────────────────
          if (topic.docUrl != null && topic.docUrl!.isNotEmpty) ...[
            _sectionHeader(context, Icons.article, 'Official Documentation', Colors.blue.shade400),
            const SizedBox(height: 12),
            _linkCard(
              context,
              icon: Icons.open_in_browser,
              iconColor: Colors.blue.shade400,
              title: 'Read Documentation',
              subtitle: topic.docUrl!,
              url: topic.docUrl!,
            ),
            const SizedBox(height: 28),
          ],

          // ── Code Example ─────────────────────────────────────────────
          if (topic.codeExample != null && topic.codeExample!.isNotEmpty) ...[
            _sectionHeader(context, Icons.code, 'Code Example', AppColors.accent),
            const SizedBox(height: 12),
            _codeBlock(context, topic.codeExample!),
            const SizedBox(height: 28),
          ],

          // ── Practice Task ─────────────────────────────────────────────
          if (topic.practiceTask != null && topic.practiceTask!.isNotEmpty) ...[
            _sectionHeader(context, Icons.construction, 'Practice Task', AppColors.warning),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.task_alt, color: AppColors.warning, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      topic.practiceTask!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.7,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _linkCard(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _codeBlock(BuildContext context, String code) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar with copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('code', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Code copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy, size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFCE9178),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
