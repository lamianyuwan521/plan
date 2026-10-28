import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/ai.dart';
import '../../services/ai_service.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late String _provider;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;

  bool _obscureKey = true;
  bool _busy = false;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppRepository>().aiConfig;
    _provider = aiProviderById(config.provider)?.id ?? 'custom';
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _modelController = TextEditingController(text: config.model);
    _apiKeyController = TextEditingController(text: config.apiKey);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  AiProvider? get _currentProvider => aiProviderById(_provider);

  AiConfig get _draft => AiConfig(
    provider: _provider,
    baseUrl: _baseUrlController.text.trim(),
    model: _modelController.text.trim(),
    apiKey: _apiKeyController.text.trim(),
  );

  void _selectProvider(AiProvider provider) {
    setState(() {
      _provider = provider.id;
      if (provider.id != 'custom') {
        _baseUrlController.text = provider.baseUrl;
        _modelController.text = provider.model;
      }
    });
  }

  Future<void> _save({bool test = false}) async {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() => _apiKeyError = '请先填写 API Key');
      return;
    }
    setState(() => _apiKeyError = null);

    final config = _draft;
    final uri = Uri.tryParse(config.endpoint);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      showAppSnackBar(
        context,
        '接口地址需要是完整 URL，例如 https://open.bigmodel.cn/api/paas/v4',
      );
      return;
    }
    if (config.model.isEmpty) {
      showAppSnackBar(context, '请填写模型名');
      return;
    }

    await context.read<AppRepository>().updateAiConfig(config);
    if (!mounted) return;
    if (!test) {
      showAppSnackBar(context, 'AI 配置已保存');
      return;
    }

    setState(() => _busy = true);
    final service = AiService();
    try {
      final reply = await service.chat(
        config: config,
        messages: const [AiMessage(role: 'user', content: '请只回复「连接成功」四个字。')],
        maxTokens: 1200,
      );
      if (!mounted) return;
      await _showResult(true, reply, config);
    } on AiException catch (error) {
      if (!mounted) return;
      await _showResult(false, error.message, config);
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(bool ok, String text, AiConfig config) {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ok ? '连接成功' : '连接失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text),
            const SizedBox(height: 12),
            Text(
              '${config.model} · ${config.baseUrl}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用自己的免费 API Key',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '下面几家都提供免费额度，注册后创建 API Key 粘贴进来即可。'
                        'Key 只保存在本机，不会写进导出的备份。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle(context, '服务商'),
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final provider in aiProviders)
                        ChoiceChip(
                          label: Text(provider.label),
                          selected: _provider == provider.id,
                          onSelected: (_) => _selectProvider(provider),
                        ),
                    ],
                  ),
                  if (_currentProvider != null) ...[
                    const SizedBox(height: 12),
                    Text(_currentProvider!.hint, style: noteStyle),
                  ],
                ],
              ),
            ),
          ),
          _sectionTitle(context, '连接信息'),
          SectionCard(
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) {
                    if (_apiKeyError != null) {
                      setState(() => _apiKeyError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: '粘贴你申请到的 Key',
                    errorText: _apiKeyError,
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? '显示' : '隐藏',
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '接口地址（Base URL）',
                    hintText: 'https://.../v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '模型名',
                    hintText: '例如 glm-4.5-flash',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '接口需兼容 OpenAI 的 /chat/completions。浏览器预览可能被跨域（CORS）拦截，'
            '安装到 iPhone 后不受影响。免费额度和模型名以各家控制台为准。',
            style: noteStyle,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : () => _save(test: true),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_busy ? '正在测试…' : '保存并测试'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _save,
            child: const Text('仅保存'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
