import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';
import '../widgets/share_recipe_sheet.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

class RecipesScreen extends StatelessWidget {
  final AppState appState;
  const RecipesScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isApple = appState.isAppleStyle(context);
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pinned non-scrollable top header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                UserGenderAvatar(gender: appState.gender, size: 50, isApple: isApple),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cooking Monster',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${appState.name} (@${appState.username})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35)),
          Expanded(
            child: appState.recipes.isEmpty
                ? SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomSafeInset + 165),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _EmptyRecipesCard(userName: appState.name, isApple: isApple),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSafeInset + 170),
                    itemCount: appState.recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recipe = appState.recipes[index];
                      return _RecipeCard(
                        recipe: recipe,
                        isApple: isApple,
                        onTap: () {
                          Navigator.of(context).push(
                            isApple
                                ? CupertinoPageRoute(
                                    builder: (_) => RecipeDetailScreen(appState: appState, recipeId: recipe.id),
                                  )
                                : MaterialPageRoute(
                                    builder: (_) => RecipeDetailScreen(appState: appState, recipeId: recipe.id),
                                  ),
                          );
                        },
                        onEdit: () {
                          Navigator.of(context).push(
                            isApple
                                ? CupertinoPageRoute(
                                    builder: (_) => RecipeEditorScreen(appState: appState, existingRecipe: recipe),
                                  )
                                : MaterialPageRoute(
                                    builder: (_) => RecipeEditorScreen(appState: appState, existingRecipe: recipe),
                                  ),
                          );
                        },
                        onShare: () => showShareRecipeSheet(context, appState, recipe),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecipesCard extends StatelessWidget {
  final String userName;
  final bool isApple;

  const _EmptyRecipesCard({required this.userName, required this.isApple});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final displayName = userName.isNotEmpty ? userName : 'Chef';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.14)),
          child: Icon(isApple ? CupertinoIcons.book_fill : Icons.menu_book_rounded, size: 30, color: primary),
        ),
        const SizedBox(height: 18),
        Text(
          'Welcome to Cooking Monster, $displayName!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'Your personal recipe database is ready. Add a new dish, generate one with AI, or import via QR code using the buttons below.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
        ),
      ],
    );

    if (isApple) {
      return LiquidGlassContainer(
        borderRadius: BorderRadius.circular(26),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: content,
      );
    }

    return Card.filled(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28), child: content),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isApple;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const _RecipeCard({
    required this.recipe,
    required this.isApple,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final portionLabel = recipe.portions == 1 ? '1 portion' : '${recipe.portions} portions';

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.displayTitleWithAuthor,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$portionLabel · ${recipe.ingredients.length} ingredients · ${recipe.steps.length} steps',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isApple ? CupertinoIcons.flame_fill : Icons.local_fire_department_rounded,
                            size: 13,
                            color: primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.timesMadeLabel,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primary),
                          ),
                        ],
                      ),
                    ),
                    if (recipe.hasInProgressChecklist)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'In progress · ${recipe.completedChecklistItems}/${recipe.totalChecklistItems}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isApple) ...[
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: onEdit,
              child: const Icon(CupertinoIcons.pencil, size: 22),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: onShare,
              child: const Icon(CupertinoIcons.share, size: 22),
            ),
          ] else ...[
            IconButton.filledTonal(tooltip: 'Edit Recipe', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            const SizedBox(width: 6),
            IconButton.filledTonal(tooltip: 'Share Recipe', onPressed: onShare, icon: const Icon(Icons.share_outlined)),
          ],
        ],
      ),
    );

    if (isApple) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LiquidGlassContainer(borderRadius: BorderRadius.circular(22), child: rowContent),
      );
    }

    return Card.filled(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(onTap: onTap, child: rowContent),
    );
  }
}
