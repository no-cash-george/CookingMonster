import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ai_recipe_service.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';
import 'recipe_detail_screen.dart';

class AiImportScreen extends StatefulWidget {
  final AppState appState;
  const AiImportScreen({super.key, required this.appState});

  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> {
  final TextEditingController _dishController = TextEditingController();
  final TextEditingController _jsonController = TextEditingController();

  String? _promptValidationError;
  bool _promptCopiedBanner = false;
  String? _importError;
  bool _isImporting = false;

  @override
  void dispose() {
    _dishController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _generateAndCopyPrompt() async {
    final dish = _dishController.text.trim();
    if (dish.isEmpty) {
      setState(() {
        _promptValidationError = 'Please enter what you want to make first.';
        _promptCopiedBanner = false;
      });
      return;
    }

    final prompt = AiRecipeService.buildPrompt(dish);
    await Clipboard.setData(ClipboardData(text: prompt));

    if (!mounted) return;
    setState(() {
      _promptValidationError = null;
      _promptCopiedBanner = true;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Prompt copied! Paste it into Gemini or any AI assistant, then paste the JSON below.'),
        ),
      );
  }

  Future<void> _pasteJsonFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _importError = 'Your clipboard is currently empty.';
      });
      return;
    }

    setState(() {
      _jsonController.text = text;
      _importError = null;
    });
  }

  Future<void> _importRecipe() async {
    if (_isImporting) return;

    setState(() {
      _importError = null;
      _isImporting = true;
    });

    try {
      final recipe = AiRecipeService.parseAndValidate(_jsonController.text);
      await widget.appState.saveRecipe(recipe);

      if (!mounted) return;
      final isApple = widget.appState.isAppleStyle(context);

      Navigator.of(context).pushReplacement(
        isApple
            ? CupertinoPageRoute(
                builder: (_) => RecipeDetailScreen(appState: widget.appState, recipeId: recipe.id),
              )
            : MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(appState: widget.appState, recipeId: recipe.id),
              ),
      );
    } on AiRecipeParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _importError = e.message;
        _isImporting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importError = 'Unexpected error while importing recipe. Check the JSON structure and try again.';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Import from AI')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // PART A: PROMPT GENERATOR
            _wrapSection(
              isApple: isApple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(isApple ? CupertinoIcons.sparkles : Icons.auto_awesome, size: 20, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 1 · Generate AI Prompt',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Creates a schema-locked prompt for Gemini or any AI.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'What do you want to make?',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (isApple)
                    CupertinoTextField(
                      controller: _dishController,
                      placeholder: 'e.g., Traditional Greek beef stifado for 4 people',
                      padding: const EdgeInsets.all(14),
                      onChanged: (_) {
                        if (_promptValidationError != null) {
                          setState(() => _promptValidationError = null);
                        }
                      },
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )
                  else
                    TextField(
                      controller: _dishController,
                      onChanged: (_) {
                        if (_promptValidationError != null) {
                          setState(() => _promptValidationError = null);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'e.g., Traditional Greek beef stifado for 4 people',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                    ),
                  if (_promptValidationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _promptValidationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (isApple)
                    CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(16),
                      onPressed: _generateAndCopyPrompt,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _promptCopiedBanner ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_clipboard,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Get Prompt'),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _generateAndCopyPrompt,
                      icon: Icon(_promptCopiedBanner ? Icons.check : Icons.content_copy_rounded),
                      label: const Text('Get Prompt'),
                    ),
                  if (_promptCopiedBanner) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isApple ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle,
                            size: 20,
                            color: primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Prompt copied to clipboard. Paste it into Gemini or any AI assistant, then paste the JSON reply below.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'THEN',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: muted, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                    ),
                  ),
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
                ],
              ),
            ),

            // PART B: JSON IMPORTER & SANITIZER
            _wrapSection(
              isApple: isApple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isApple ? CupertinoIcons.doc_text_fill : Icons.data_object_rounded,
                          size: 20,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 2 · Paste AI JSON Response',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Automatically strips Markdown fences & validates units.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isApple
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _pasteJsonFromClipboard,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Paste from Clipboard',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                                ),
                              ],
                            ),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: _pasteJsonFromClipboard,
                            icon: const Icon(Icons.content_paste_go, size: 18),
                            label: const Text('Paste from Clipboard'),
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (isApple)
                    CupertinoTextField(
                      controller: _jsonController,
                      placeholder: '{\n  "title": "...",\n  "yield": 4,\n  ...\n}',
                      minLines: 7,
                      maxLines: 14,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      padding: const EdgeInsets.all(14),
                      onChanged: (_) {
                        if (_importError != null) {
                          setState(() => _importError = null);
                        }
                      },
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )
                  else
                    TextField(
                      controller: _jsonController,
                      minLines: 7,
                      maxLines: 14,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      onChanged: (_) {
                        if (_importError != null) {
                          setState(() => _importError = null);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: '{\n  "title": "...",\n  "yield": 4,\n  ...\n}',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                    ),
                  if (_importError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isApple ? CupertinoIcons.exclamationmark_triangle_fill : Icons.error_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _importError!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isApple)
                    CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(16),
                      onPressed: _isImporting ? null : _importRecipe,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.arrow_down_doc, size: 18),
                          const SizedBox(width: 8),
                          Text(_isImporting ? 'Importing...' : 'Import Recipe'),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isImporting ? null : _importRecipe,
                      icon: const Icon(Icons.download_done_rounded),
                      label: Text(_isImporting ? 'Importing...' : 'Import Recipe'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapSection({required bool isApple, required Widget child}) {
    if (isApple) {
      return LiquidGlassContainer(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(18),
        child: child,
      );
    }

    return Card.filled(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
