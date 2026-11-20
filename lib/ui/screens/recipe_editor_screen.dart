import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';

class _IngredientFields {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController noteController;
  IngredientUnit unit;

  _IngredientFields({String name = '', String amount = '', this.unit = IngredientUnit.grams, String note = ''})
    : nameController = TextEditingController(text: name),
      amountController = TextEditingController(text: amount),
      noteController = TextEditingController(text: note);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    noteController.dispose();
  }
}

class RecipeEditorScreen extends StatefulWidget {
  final AppState appState;
  final Recipe? existingRecipe;

  const RecipeEditorScreen({super.key, required this.appState, this.existingRecipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  int _currentStep = 0;
  String? _validationError;
  bool _isSaving = false;

  late final TextEditingController _titleController;
  late int _portions;
  final List<_IngredientFields> _ingredientRows = [];
  final List<TextEditingController> _stepControllers = [];

  bool get _isEditing => widget.existingRecipe != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecipe;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _portions = existing?.portions ?? 1;

    if (existing != null && existing.ingredients.isNotEmpty) {
      for (final ing in existing.ingredients) {
        final formattedAmount = ing.amount % 1 == 0 ? ing.amount.toInt().toString() : ing.amount.toString();
        _ingredientRows.add(
          _IngredientFields(name: ing.name, amount: formattedAmount, unit: ing.unit, note: ing.note ?? ''),
        );
      }
    } else {
      _ingredientRows.add(_IngredientFields());
    }

    if (existing != null && existing.steps.isNotEmpty) {
      for (final step in existing.steps) {
        _stepControllers.add(TextEditingController(text: step));
      }
    } else {
      _stepControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final ctrl in _stepControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<Ingredient> _parseIngredients() {
    final parsed = <Ingredient>[];
    for (final row in _ingredientRows) {
      final name = row.nameController.text.trim();
      final rawAmount = row.amountController.text.trim().replaceAll(',', '.');
      final amount = double.tryParse(rawAmount);
      final note = row.noteController.text.trim();

      if (name.isNotEmpty && amount != null && amount > 0) {
        parsed.add(Ingredient(name: name, amount: amount, unit: row.unit, note: note.isEmpty ? null : note));
      }
    }
    return parsed;
  }

  void _goToStepTwo() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _validationError = 'Please enter a recipe name.');
      return;
    }
    final ingredients = _parseIngredients();
    if (ingredients.isEmpty) {
      setState(() => _validationError = 'Add at least one ingredient with a name and amount.');
      return;
    }

    setState(() {
      _validationError = null;
      _currentStep = 1;
    });
  }

  Future<void> _saveRecipe() async {
    final steps = _stepControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

    if (steps.isEmpty) {
      setState(() => _validationError = 'Add at least one execution step.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final existing = widget.existingRecipe;
    final parsedIngredients = _parseIngredients();
    final author = (existing != null && existing.createdBy.isNotEmpty) ? existing.createdBy : widget.appState.username;

    final retainedCheckedIngredients = (existing?.checkedIngredients ?? const {})
        .where((idx) => idx >= 0 && idx < parsedIngredients.length)
        .toSet();
    final retainedCompletedSteps = (existing?.completedSteps ?? const {})
        .where((idx) => idx >= 0 && idx < steps.length)
        .toSet();

    final recipe = Recipe(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      createdBy: author,
      portions: _portions,
      ingredients: parsedIngredients,
      steps: steps,
      timesMade: existing?.timesMade ?? 0,
      checkedIngredients: retainedCheckedIngredients,
      completedSteps: retainedCompletedSteps,
    );

    await widget.appState.saveRecipe(recipe);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteRecipe() async {
    final existing = widget.existingRecipe;
    if (existing == null) return;
    await widget.appState.deleteRecipe(existing.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete Recipe',
              icon: Icon(
                isApple ? CupertinoIcons.trash : Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _deleteRecipe,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(context, isApple),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500),
                ),
              ),
            Expanded(child: _currentStep == 0 ? _buildStepOne(context, isApple) : _buildStepTwo(context, isApple)),
            _buildBottomBar(context, isApple),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, bool isApple) {
    final primary = Theme.of(context).colorScheme.primary;
    final surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentStep == 1 ? primary : surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep == 0 ? 'Step 1 of 2 · Name, Portions & Ingredients' : 'Step 2 of 2 · Execution Steps',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStepOne(BuildContext context, bool isApple) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _wrapCard(
          isApple: isApple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recipe Name', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _buildInput(
                context: context,
                isApple: isApple,
                controller: _titleController,
                hint: 'e.g., Crispy Pork Belly',
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Portions Yielded',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease portions',
                        onPressed: _portions > 1 ? () => setState(() => _portions--) : null,
                        icon: Icon(isApple ? CupertinoIcons.minus_circle : Icons.remove_circle_outline),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_portions',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primary),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase portions',
                        onPressed: () => setState(() => _portions++),
                        icon: Icon(isApple ? CupertinoIcons.plus_circle : Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: () {
                setState(() => _ingredientRows.add(_IngredientFields()));
              },
              icon: Icon(isApple ? CupertinoIcons.add : Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _ingredientRows.length; i++) ...[
          _wrapCard(
            isApple: isApple,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        context: context,
                        isApple: isApple,
                        controller: _ingredientRows[i].nameController,
                        hint: 'Ingredient name (e.g., Onion, Flour)',
                      ),
                    ),
                    if (_ingredientRows.length > 1)
                      IconButton(
                        tooltip: 'Remove ingredient',
                        icon: Icon(
                          isApple ? CupertinoIcons.minus_circle : Icons.remove_circle_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          setState(() {
                            final removed = _ingredientRows.removeAt(i);
                            removed.dispose();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        context: context,
                        isApple: isApple,
                        controller: _ingredientRows[i].amountController,
                        hint: _ingredientRows[i].unit == IngredientUnit.grams
                            ? 'Weight in grams (g)'
                            : 'Count (e.g., 2)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UnitToggle(
                      value: _ingredientRows[i].unit,
                      isApple: isApple,
                      onChanged: (newUnit) {
                        setState(() => _ingredientRows[i].unit = newUnit);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInput(
                  context: context,
                  isApple: isApple,
                  controller: _ingredientRows[i].noteController,
                  hint: 'Optional note (e.g., diced, cold)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStepTwo(BuildContext context, bool isApple) {
    final ingredientCount = _parseIngredients().length;
    final portionLabel = _portions == 1 ? '1 portion' : '$_portions portions';
    final existing = widget.existingRecipe;
    final author = (existing != null && existing.createdBy.isNotEmpty) ? existing.createdBy : widget.appState.username;
    final titleDisplay = author.isNotEmpty
        ? '${_titleController.text.trim()} created by @$author'
        : _titleController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _wrapCard(
          isApple: isApple,
          child: Row(
            children: [
              Icon(
                isApple ? CupertinoIcons.flame_fill : Icons.restaurant,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleDisplay,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$portionLabel · $ingredientCount ingredients locked in',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Execution Steps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => _stepControllers.add(TextEditingController()));
              },
              icon: Icon(isApple ? CupertinoIcons.add : Icons.add),
              label: const Text('Add Step'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _stepControllers.length; i++) ...[
          _wrapCard(
            isApple: isApple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${i + 1}',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                    ),
                    if (_stepControllers.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final removed = _stepControllers.removeAt(i);
                            removed.dispose();
                          });
                        },
                        child: Icon(
                          isApple ? CupertinoIcons.minus_circle : Icons.remove_circle_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInput(
                  context: context,
                  isApple: isApple,
                  controller: _stepControllers[i],
                  hint: 'Describe what to do in this step...',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isApple) {
    final content = Row(
      children: [
        if (_currentStep == 1) ...[
          Expanded(
            child: isApple
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () => setState(() {
                      _validationError = null;
                      _currentStep = 0;
                    }),
                    child: const Text('Back'),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => setState(() {
                      _validationError = null;
                      _currentStep = 0;
                    }),
                    child: const Text('Back'),
                  ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: isApple
              ? CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _isSaving ? null : (_currentStep == 0 ? _goToStepTwo : _saveRecipe),
                  child: Text(_currentStep == 0 ? 'Next: Execution Steps' : (_isSaving ? 'Saving...' : 'Save Recipe')),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : (_currentStep == 0 ? _goToStepTwo : _saveRecipe),
                  child: Text(_currentStep == 0 ? 'Next: Execution Steps' : (_isSaving ? 'Saving...' : 'Save Recipe')),
                ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: isApple
          ? LiquidGlassContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(24),
              child: content,
            )
          : content,
    );
  }

  Widget _wrapCard({required bool isApple, required Widget child}) {
    if (isApple) {
      return LiquidGlassContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(20),
        child: child,
      );
    }
    return Card.filled(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _buildInput({
    required BuildContext context,
    required bool isApple,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    if (isApple) {
      return CupertinoTextField(
        controller: controller,
        placeholder: hint,
        keyboardType: keyboardType,
        maxLines: maxLines,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final IngredientUnit value;
  final bool isApple;
  final ValueChanged<IngredientUnit> onChanged;

  const _UnitToggle({required this.value, required this.isApple, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final bg = isApple
        ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget option(IngredientUnit unit, String label) {
      final selected = value == unit;
      return GestureDetector(
        onTap: () => onChanged(unit),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? onPrimary : muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option(IngredientUnit.grams, 'g'), option(IngredientUnit.count, 'pcs')],
      ),
    );
  }
}
