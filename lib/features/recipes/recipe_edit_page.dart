import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

class RecipeEditPage extends StatefulWidget {
  const RecipeEditPage({super.key, this.recipe});

  final Recipe? recipe;

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  static const _predefinedTags = ['高蛋白', '低碳', '快手', '清淡', '素食'];

  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _customTag;
  late String _mealType;
  late bool _autoCalories;
  late bool _favorite;
  late final List<_IngredientDraft> _ingredients;
  late final List<TextEditingController> _steps;
  late final Set<String> _tags;

  bool _dirty = false;
  bool _saving = false;

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _name = TextEditingController(text: recipe?.name ?? '');
    _calories = TextEditingController(
      text: recipe == null ? '' : '${recipe.calories}',
    );
    _customTag = TextEditingController();
    _mealType = recipe?.mealType ?? 'lunch';
    _autoCalories = false;
    _favorite = recipe?.isFavorite ?? false;
    _ingredients = (recipe?.ingredients ?? const <Ingredient>[])
        .map(_IngredientDraft.from)
        .toList();
    if (_ingredients.isEmpty) _ingredients.add(_IngredientDraft());
    _steps = (recipe?.steps ?? const <String>[])
        .map((step) => TextEditingController(text: step))
        .toList();
    if (_steps.isEmpty) _steps.add(TextEditingController());
    _tags = {...(recipe?.tags ?? const <String>[])};
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _customTag.dispose();
    for (final draft in _ingredients) {
      draft.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  int _sumIngredientKcal() {
    var total = 0;
    for (final draft in _ingredients) {
      total += int.tryParse(draft.kcal.text.trim()) ?? 0;
    }
    return total;
  }

  void _recalcAuto() {
    if (!_autoCalories) return;
    _calories.text = '${_sumIngredientKcal()}';
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '给食谱起个名字吧');
      return;
    }
    if (name.length > 30) {
      showAppSnackBar(context, '名称最多 30 个字');
      return;
    }
    final calories = _autoCalories
        ? _sumIngredientKcal()
        : int.tryParse(_calories.text.trim());
    if (calories == null || calories < 0 || calories > 3000) {
      showAppSnackBar(context, '热量请填写 0–3000 kcal');
      return;
    }

    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipe = Recipe(
      id: widget.recipe?.id ?? repository.newId(),
      name: name,
      mealType: _mealType,
      calories: calories,
      ingredients: _ingredients
          .where((draft) => draft.name.text.trim().isNotEmpty)
          .map(
            (draft) => Ingredient(
              name: draft.name.text.trim(),
              amount: double.tryParse(
                    draft.amount.text.trim().replaceAll(',', '.'),
                  ) ??
                  0,
              unit: draft.unit.text.trim().isEmpty
                  ? 'g'
                  : draft.unit.text.trim(),
              kcal: int.tryParse(draft.kcal.text.trim()),
            ),
          )
          .toList(),
      steps: _steps
          .map((controller) => controller.text.trim())
          .where((step) => step.isNotEmpty)
          .toList(),
      tags: _tags.toList(),
      isBuiltin: false,
      isFavorite: _favorite,
    );

    setState(() => _saving = true);
    if (_isEditing) {
      await repository.updateRecipe(recipe);
    } else {
      await repository.addRecipe(recipe);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_isEditing ? '已保存' : '已添加食谱')),
        );
    });
  }

  Future<void> _confirmDiscard() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: '放弃修改？',
      message: '未保存的内容会丢失。',
      confirmLabel: '放弃',
      destructive: true,
    );
    if (!discard || !mounted) return;
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showConfirmDialog(
          context,
          title: '放弃修改？',
          message: '未保存的内容会丢失。',
          confirmLabel: '放弃',
          destructive: true,
        );
        if (!discard || !mounted) return;
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _confirmDiscard,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(_isEditing ? '编辑食谱' : '新增食谱'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            TextField(
              controller: _name,
              onChanged: (_) => _markDirty(),
              maxLength: 30,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '食谱名称',
                hintText: '例如：香煎鸡胸肉沙拉',
                prefixIcon: Icon(Icons.restaurant_menu_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(title: '餐次'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('any', '通用'),
                  ('breakfast', '早餐'),
                  ('lunch', '午餐'),
                  ('dinner', '晚餐'),
                  ('snack', '加餐'),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _mealType == entry.$1,
                    onSelected: (_) {
                      setState(() {
                        _mealType = entry.$1;
                        _dirty = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionLabel(title: '热量'),
            const SizedBox(height: 8),
            TextField(
              controller: _calories,
              readOnly: _autoCalories,
              onChanged: (_) => _markDirty(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: '每份热量',
                suffixText: 'kcal',
                prefixIcon: const Icon(Icons.local_fire_department_outlined),
                filled: true,
                fillColor: _autoCalories
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45)
                    : null,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('按食材自动计算'),
              subtitle: const Text('热量 = 各食材热量之和'),
              value: _autoCalories,
              onChanged: (value) {
                setState(() {
                  _autoCalories = value;
                  _dirty = true;
                });
                if (value) _recalcAuto();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: _SectionLabel(title: '食材')),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _ingredients.add(_IngredientDraft());
                      _dirty = true;
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加食材'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < _ingredients.length; index++)
              _IngredientCard(
                draft: _ingredients[index],
                onDelete: _ingredients.length == 1
                    ? null
                    : () {
                        final draft = _ingredients.removeAt(index);
                        draft.dispose();
                        setState(() => _dirty = true);
                        _recalcAuto();
                      },
                onChanged: () {
                  _markDirty();
                  _recalcAuto();
                },
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: _SectionLabel(title: '做法')),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _steps.add(TextEditingController());
                      _dirty = true;
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加一步'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < _steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _steps[index],
                        maxLines: 3,
                        minLines: 1,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: '描述这一步的做法',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _steps.length == 1
                          ? null
                          : () {
                              final controller = _steps.removeAt(index);
                              controller.dispose();
                              setState(() => _dirty = true);
                            },
                      tooltip: '删除这一步',
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            _SectionLabel(title: '标签'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _predefinedTags)
                  FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    onSelected: (selected) {
                      if (selected && _tags.length >= 5) {
                        showAppSnackBar(context, '最多选择 5 个标签');
                        return;
                      }
                      setState(() {
                        if (selected) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                        _dirty = true;
                      });
                    },
                  ),
                for (final tag in _tags
                    .where((tag) => !_predefinedTags.contains(tag)))
                  InputChip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                        _dirty = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTag,
                    onSubmitted: (_) => _addCustomTag(),
                    decoration: const InputDecoration(
                      hintText: '自定义标签',
                      isDense: true,
                      prefixIcon: Icon(Icons.tag, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _addCustomTag,
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('收藏这道食谱'),
              value: _favorite,
              onChanged: (value) => setState(() {
                _favorite = value;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? '保存' : '添加食谱'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomTag() {
    final tag = _customTag.text.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _customTag.clear();
      return;
    }
    if (_tags.length >= 5) {
      showAppSnackBar(context, '最多选择 5 个标签');
      return;
    }
    setState(() {
      _tags.add(tag);
      _customTag.clear();
      _dirty = true;
    });
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.draft,
    required this.onDelete,
    required this.onChanged,
  });

  final _IngredientDraft draft;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.name,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: '食材名称',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: '删除食材',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.amount,
                  onChanged: (_) => onChanged(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: '用量',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: TextField(
                  controller: draft.unit,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: '单位',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.kcal,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'kcal',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({
    String name = '',
    String amount = '',
    String unit = 'g',
    String kcal = '',
  })  : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount),
        unit = TextEditingController(text: unit),
        kcal = TextEditingController(text: kcal);

  factory _IngredientDraft.from(Ingredient ingredient) {
    return _IngredientDraft(
      name: ingredient.name,
      amount: ingredient.amount == 0
          ? ''
          : (ingredient.amount % 1 == 0
              ? ingredient.amount.toInt().toString()
              : ingredient.amount.toStringAsFixed(1)),
      unit: ingredient.unit,
      kcal: ingredient.kcal?.toString() ?? '',
    );
  }

  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController unit;
  final TextEditingController kcal;

  void dispose() {
    name.dispose();
    amount.dispose();
    unit.dispose();
    kcal.dispose();
  }
}
