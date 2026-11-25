import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../services/cup_conversion_service.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';
import '../widgets/share_recipe_sheet.dart';
import 'recipe_complete_screen.dart';
import 'recipe_editor_screen.dart';

enum _IngredientDisplayMode { grams, cupsAndSpoons }

class RecipeDetailScreen extends StatefulWidget {
  final AppState appState;
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.appState, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  _IngredientDisplayMode _displayMode = _IngredientDisplayMode.grams;
  final Map<String, CupConversionResult> _resolvedConversions = {};
  bool _isResolvingVolume = false;

  String _conversionCacheKey(Ingredient ing) => '${ing.name.trim().toLowerCase()}|${ing.amount}';

  Future<void> _setDisplayMode(_IngredientDisplayMode mode, Recipe recipe) async {
    setState(() => _displayMode = mode);
    if (mode == _IngredientDisplayMode.cupsAndSpoons) {
      await _resolveAllVolumeConversions(recipe);
    }
  }

  Future<void> _resolveAllVolumeConversions(Recipe recipe) async {
    if (_isResolvingVolume) return;
    setState(() => _isResolvingVolume = true);

    await CupConversionService.preloadCache();

    for (final ing in recipe.ingredients) {
      if (ing.unit != IngredientUnit.grams) continue;
      final key = _conversionCacheKey(ing);
      // Prioritizes Online -> Cached -> Local Table
      final result = await CupConversionService.convertAsync(ingredientName: ing.name, grams: ing.amount);
      if (!mounted) return;
      setState(() {
        _resolvedConversions[key] = result;
      });
    }

    if (mounted) {
      setState(() => _isResolvingVolume = false);
    }
  }

  Future<void> _toggleIngredient(Recipe recipe, int index) async {
    final nextIngredients = Set<int>.from(recipe.checkedIngredients);
    if (!nextIngredients.remove(index)) {
      nextIngredients.add(index);
    }

    final allIngredientsDone = recipe.ingredients.isNotEmpty && nextIngredients.length == recipe.ingredients.length;
    final allStepsDone = recipe.steps.isNotEmpty && recipe.completedSteps.length == recipe.steps.length;

    if (allIngredientsDone && allStepsDone) {
      await _completeRecipe(recipe);
    } else {
      await widget.appState.updateRecipeProgress(
        recipe.id,
        checkedIngredients: nextIngredients,
        completedSteps: recipe.completedSteps,
      );
    }
  }

  Future<void> _toggleStep(Recipe recipe, int index) async {
    final nextSteps = Set<int>.from(recipe.completedSteps);
    if (!nextSteps.remove(index)) {
      nextSteps.add(index);
    }

    final allIngredientsDone =
        recipe.ingredients.isNotEmpty && recipe.checkedIngredients.length == recipe.ingredients.length;
    final allStepsDone = recipe.steps.isNotEmpty && nextSteps.length == recipe.steps.length;

    if (allIngredientsDone && allStepsDone) {
      await _completeRecipe(recipe);
    } else {
      await widget.appState.updateRecipeProgress(
        recipe.id,
        checkedIngredients: recipe.checkedIngredients,
        completedSteps: nextSteps,
      );
    }
  }

  Future<void> _completeRecipe(Recipe recipe) async {
    final updatedRecipe = await widget.appState.markRecipeCompleted(recipe.id);
    if (!mounted || updatedRecipe == null) return;

    final isApple = widget.appState.isAppleStyle(context);
    final resetAndStay = await Navigator.of(context).push<bool>(
      isApple
          ? CupertinoPageRoute(
              builder: (_) => RecipeCompleteScreen(appState: widget.appState, recipe: updatedRecipe),
            )
          : MaterialPageRoute(
              builder: (_) => RecipeCompleteScreen(appState: widget.appState, recipe: updatedRecipe),
            ),
    );

    if (!mounted) return;
    if (resetAndStay == false && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _openEditor(BuildContext context, Recipe recipe, bool isApple) {
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute(
              builder: (_) => RecipeEditorScreen(appState: widget.appState, existingRecipe: recipe),
            )
          : MaterialPageRoute(
              builder: (_) => RecipeEditorScreen(appState: widget.appState, existingRecipe: recipe),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final recipe = widget.appState.recipes.where((r) => r.id == widget.recipeId).firstOrNull;

        if (recipe == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold();
        }

        final isApple = widget.appState.isAppleStyle(context);
        final primary = Theme.of(context).colorScheme.primary;
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        final portionLabel = recipe.portions == 1 ? '1 portion' : '${recipe.portions} portions';
        final hasGramIngredients = recipe.ingredients.any((i) => i.unit == IngredientUnit.grams);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Recipe'),
            actions: [
              IconButton(
                tooltip: 'Edit Recipe',
                icon: Icon(isApple ? CupertinoIcons.pencil : Icons.edit_outlined),
                onPressed: () => _openEditor(context, recipe, isApple),
              ),
              IconButton(
                tooltip: 'Share Recipe',
                icon: Icon(isApple ? CupertinoIcons.share : Icons.share_outlined),
                onPressed: () => showShareRecipeSheet(context, widget.appState, recipe),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  recipe.displayTitleWithAuthor,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '$portionLabel · ${recipe.ingredients.length} ingredients · ${recipe.steps.length} steps',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 14),
                _wrapSurface(
                  isApple: isApple,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        isApple ? CupertinoIcons.flame_fill : Icons.local_fire_department_rounded,
                        size: 20,
                        color: primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recipe.timesMadeLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Decrease times made',
                        onPressed: recipe.timesMade > 0 ? () => widget.appState.adjustTimesMade(recipe.id, -1) : null,
                        icon: Icon(isApple ? CupertinoIcons.minus_circle : Icons.remove_circle_outline, size: 20),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Increase times made',
                        onPressed: () => widget.appState.adjustTimesMade(recipe.id, 1),
                        icon: Icon(isApple ? CupertinoIcons.plus_circle : Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Ingredients',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_isResolvingVolume) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ],
                      ),
                    ),
                    if (recipe.checkedIngredients.isNotEmpty)
                      TextButton(
                        onPressed: () => widget.appState.updateRecipeProgress(
                          recipe.id,
                          checkedIngredients: const <int>{},
                          completedSteps: recipe.completedSteps,
                        ),
                        child: const Text('Reset'),
                      ),
                    if (hasGramIngredients) ...[
                      const SizedBox(width: 4),
                      _UnitDisplayToggle(
                        mode: _displayMode,
                        isApple: isApple,
                        onChanged: (mode) => _setDisplayMode(mode, recipe),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _wrapSurface(
                  isApple: isApple,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (int i = 0; i < recipe.ingredients.length; i++) ...[
                        _buildIngredientRow(
                          context: context,
                          ingredient: recipe.ingredients[i],
                          checked: recipe.checkedIngredients.contains(i),
                          isApple: isApple,
                          onTap: () => _toggleIngredient(recipe, i),
                        ),
                        if (i < recipe.ingredients.length - 1)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Execution Steps',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (recipe.completedSteps.isNotEmpty)
                      TextButton(
                        onPressed: () => widget.appState.updateRecipeProgress(
                          recipe.id,
                          checkedIngredients: recipe.checkedIngredients,
                          completedSteps: const <int>{},
                        ),
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < recipe.steps.length; i++) ...[
                  _buildStepCard(
                    context: context,
                    stepNumber: i + 1,
                    text: recipe.steps[i],
                    completed: recipe.completedSteps.contains(i),
                    isApple: isApple,
                    onTap: () => _toggleStep(recipe, i),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIngredientRow({
    required BuildContext context,
    required Ingredient ingredient,
    required bool checked,
    required bool isApple,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final showVolume = _displayMode == _IngredientDisplayMode.cupsAndSpoons && ingredient.unit == IngredientUnit.grams;
    final conversion = showVolume
        ? (_resolvedConversions[_conversionCacheKey(ingredient)] ??
              CupConversionService.convertSync(ingredientName: ingredient.name, grams: ingredient.amount))
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              checked
                  ? (isApple ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle)
                  : (isApple ? CupertinoIcons.circle : Icons.circle_outlined),
              size: 22,
              color: checked ? primary : muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      color: checked ? muted : null,
                    ),
                  ),
                  if (ingredient.note != null && ingredient.note!.isNotEmpty)
                    Text(ingredient.note!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                  if (conversion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${ingredient.formattedAmount} · ${conversion.source.label}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: checked ? 0.08 : 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversion != null ? conversion.formattedVolume : ingredient.formattedAmount,
                style: TextStyle(fontWeight: FontWeight.w700, color: checked ? muted : primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required BuildContext context,
    required int stepNumber,
    required String text,
    required bool completed,
    required bool isApple,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: _wrapSurface(
        isApple: isApple,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? primary : primary.withValues(alpha: 0.15),
              ),
              child: completed
                  ? Icon(
                      isApple ? CupertinoIcons.checkmark : Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : Text(
                      '$stepNumber',
                      style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  color: completed ? muted : null,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapSurface({required bool isApple, required Widget child, EdgeInsetsGeometry? padding}) {
    if (isApple) {
      return LiquidGlassContainer(borderRadius: BorderRadius.circular(22), padding: padding, child: child);
    }
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: padding != null ? Padding(padding: padding, child: child) : child,
    );
  }
}

class _UnitDisplayToggle extends StatelessWidget {
  final _IngredientDisplayMode mode;
  final bool isApple;
  final ValueChanged<_IngredientDisplayMode> onChanged;

  const _UnitDisplayToggle({required this.mode, required this.isApple, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final bg = isApple
        ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget buildChip(_IngredientDisplayMode target, String label) {
      final selected = mode == target;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: selected ? onPrimary : muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildChip(_IngredientDisplayMode.grams, 'g'),
          buildChip(_IngredientDisplayMode.cupsAndSpoons, 'Cups & Spoons'),
        ],
      ),
    );
  }
}
