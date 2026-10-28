import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/ai.dart';
import '../../services/ai_service.dart';
import '../settings/ai_settings_page.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final AiService _service = AiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _sending = false;

  @override
  void dispose() {
    _service.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()));
  }

  void _clearConversation() {
    setState(_messages.clear);
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    final repository = context.read<AppRepository>();
    final config = repository.aiConfig;
    if (!config.isConfigured) {
      await _openSettings();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final history = _messages.where((m) => !m.isError).toList();
    final recent = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    final messages = <AiMessage>[
      AiMessage(role: 'system', content: buildCoachSystemPrompt(repository)),
      for (final message in recent)
        AiMessage(role: message.role, content: message.text),
    ];

    try {
      final reply = await _service.chat(config: config, messages: messages);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: reply));
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(role: 'assistant', text: error.message, isError: true),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(role: 'assistant', text: '出了点问题：$error', isError: true),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final config = repository.aiConfig;
    final provider = aiProviderById(config.provider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'AI 助手',
            subtitle: config.isConfigured
                ? '${provider?.label ?? '自定义'} · ${config.model}'
                : '接入免费 AI，聊聊今天怎么吃',
            actions: [
              if (_messages.isNotEmpty)
                IconButton(
                  tooltip: '清空对话',
                  onPressed: _sending ? null : _clearConversation,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              IconButton(
                tooltip: 'AI 设置',
                onPressed: _openSettings,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!config.isConfigured)
            Expanded(child: _SetupPanel(onSetup: _openSettings))
          else ...[
            Expanded(
              child: _messages.isEmpty && !_sending
                  ? _EmptyChat(onSuggestion: _send)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const _TypingBubble();
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            const SizedBox(height: 10),
            _Composer(
              controller: _inputController,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final String role;
  final String text;
  final bool isError;
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SectionCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotAvatar(size: 64),
                const SizedBox(height: 14),
                Text(
                  '先接入一个免费 AI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '小一二可以结合你的体重、热量和喝水记录，回答「今天还能吃什么」这类问题。'
                  '支持智谱 GLM、硅基流动、阿里云百炼的免费额度，也可以填任意 OpenAI 兼容接口。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onSetup,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('配置 API Key'),
                ),
                const SizedBox(height: 10),
                Text(
                  '免费模型有每日额度；对话内容会发送给你配置的服务商。',
                  textAlign: TextAlign.center,
                  style: noteStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  static const List<String> _suggestions = [
    '今天晚饭还能吃多少？',
    '帮我看看今天的热量搭配',
    '明天早餐吃什么好？',
    '喝水总是喝不够，怎么办？',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const Center(child: MascotAvatar(size: 64)),
        const SizedBox(height: 12),
        Text(
          '我是小一二',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '我已经看过你今天的记录，可以直接问我。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                label: Text(suggestion),
                onPressed: () => onSuggestion(suggestion),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '对话会发送给你配置的 AI 服务；体重和饮食记录本身仍只保存在本机。',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == 'user';
    final background = message.isError
        ? scheme.errorContainer
        : isUser
        ? scheme.primaryContainer
        : scheme.surface;
    final foreground = message.isError
        ? scheme.onErrorContainer
        : isUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left: isUser ? 40 : 0,
          right: isUser ? 0 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: message.isError
                      ? scheme.error.withValues(alpha: 0.35)
                      : scheme.outlineVariant.withValues(alpha: 0.45),
                ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: foreground,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              '小一二正在想…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: sending ? null : onSend,
                decoration: const InputDecoration(
                  hintText: '问问小一二，比如：今天晚饭吃什么？',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送',
              onPressed: sending ? null : () => onSend(controller.text),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'AI 建议仅供参考，不能替代医生或营养师。',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
