import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';

class RecipeCompleteScreen extends StatelessWidget {
  final AppState appState;
  final Recipe recipe;

  const RecipeCompleteScreen({super.key, required this.appState, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final isApple = appState.isAppleStyle(context);
    final primary = Theme.of(context).colorScheme.primary;
    final chefName = appState.name.isNotEmpty ? appState.name : 'Chef';

    final cardContent = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserGenderAvatar(gender: appState.gender, size: 88, isApple: isApple),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
                    ),
                    child: Icon(
                      isApple ? CupertinoIcons.checkmark_seal_fill : Icons.emoji_events,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Congratulations, $chefName!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'You completed "${recipe.displayTitleWithAuthor}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isApple ? CupertinoIcons.flame_fill : Icons.local_fire_department_rounded,
                    size: 16,
                    color: primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${recipe.timesMadeLabel} total',
                    style: TextStyle(fontWeight: FontWeight.w800, color: primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All ${recipe.ingredients.length} ingredients weighed and ${recipe.steps.length} execution steps finished.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 28),
          if (isApple) ...[
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(16),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back to Recipes'),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cook Again (Fresh Checklist)'),
            ),
          ] else ...[
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back to Recipes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cook Again (Fresh Checklist)'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: Icon(isApple ? CupertinoIcons.xmark : Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: isApple
                  ? LiquidGlassContainer(blurSigma: 28, padding: const EdgeInsets.all(28), child: cardContent)
                  : Card.filled(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Padding(padding: const EdgeInsets.all(28), child: cardContent),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
