import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const IosDemoApp());
}

class IosDemoApp extends StatelessWidget {
  const IosDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _count = 0;
  final TextEditingController _nameController = TextEditingController();
  String _greeting = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'Web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone / iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
      _ => defaultTargetPlatform.name,
    };
  }

  void _sayHello() {
    final name = _nameController.text.trim();
    setState(() {
      _greeting = name.isEmpty ? '你好，iOS！' : '你好，$name！';
    });
  }

  void _showSnackBar() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('这是一个 SnackBar，说明交互正常。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('iOS Demo'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(platform: _platformLabel),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('运行环境', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _InfoRow(label: '平台', value: _platformLabel),
                  _InfoRow(
                    label: '屏幕',
                    value: '${size.width.toStringAsFixed(0)} × '
                        '${size.height.toStringAsFixed(0)}',
                  ),
                  _InfoRow(
                    label: '渲染',
                    value: kIsWeb ? 'Flutter Web' : 'Flutter 原生渲染',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('计数器', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$_count',
                    key: const Key('counter-value'),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => setState(() => _count++),
                        icon: const Icon(Icons.add),
                        label: const Text('加一'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => setState(() => _count = 0),
                        child: const Text('归零'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('交互测试', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '输入你的名字',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sayHello(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _sayHello,
                        child: const Text('打招呼'),
                      ),
                      OutlinedButton(
                        onPressed: _showSnackBar,
                        child: const Text('显示提示'),
                      ),
                    ],
                  ),
                  if (_greeting.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _greeting,
                      key: const Key('greeting'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '由 GitHub Actions 在 macOS 上构建 · 未签名 IPA · '
            'Sideloadly 侧载',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_iphone, color: scheme.onPrimary, size: 36),
          const SizedBox(height: 12),
          Text(
            'Flutter iOS Demo',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前运行平台：$platform',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
