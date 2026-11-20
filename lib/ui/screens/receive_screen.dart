import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/recipe.dart';
import '../../services/share_codec.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';
import 'ai_import_screen.dart';

class ReceiveScreen extends StatefulWidget {
  final AppState appState;
  const ReceiveScreen({super.key, required this.appState});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _isProcessing = false;

  void _openImportFromAi() {
    final isApple = widget.appState.isAppleStyle(context);
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute(builder: (_) => AiImportScreen(appState: widget.appState))
          : MaterialPageRoute(builder: (_) => AiImportScreen(appState: widget.appState)),
    );
  }

  Future<void> _handleIncomingPayload(String rawPayload) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final recipe = ShareCodec.decode(rawPayload);
      if (!mounted) return;

      final confirmed = await _showImportConfirmation(recipe);
      if (confirmed == true && mounted) {
        await widget.appState.saveRecipe(recipe);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Imported "${recipe.displayTitleWithAuthor}"')));
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 900));
      _isProcessing = false;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
      return;
    }
    await _handleIncomingPayload(text);
  }

  Future<bool?> _showImportConfirmation(Recipe recipe) {
    final isApple = widget.appState.isAppleStyle(context);
    final portionLabel = recipe.portions == 1 ? '1 portion' : '${recipe.portions} portions';
    final summary = '$portionLabel · ${recipe.ingredients.length} ingredients · ${recipe.steps.length} steps';

    if (isApple) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Import Recipe?'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('"${recipe.displayTitleWithAuthor}"\n$summary'),
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Recipe'),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Recipe?'),
        content: Text('"${recipe.displayTitleWithAuthor}"\n$summary'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save Recipe')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receive Recipe',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan a QR code, paste a code, or import from AI.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isApple)
                  GestureDetector(
                    onTap: _openImportFromAi,
                    child: LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles, size: 16, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            'AI Import',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _openImportFromAi,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Import From AI'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final code = capture.barcodes.firstOrNull?.rawValue;
                        if (code != null) {
                          _handleIncomingPayload(code);
                        }
                      },
                    ),
                    Center(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isApple ? Colors.white.withValues(alpha: 0.85) : primary, width: 3),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: isApple
                          ? const LiquidGlassContainer(
                              padding: EdgeInsets.all(12),
                              child: Text('Align QR code inside the frame', textAlign: TextAlign.center),
                            )
                          : Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Align QR code inside the frame',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isApple)
              GestureDetector(
                onTap: _pasteFromClipboard,
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.doc_on_clipboard, size: 20, color: primary),
                      const SizedBox(width: 8),
                      Text(
                        'Paste Recipe Code from Clipboard',
                        style: TextStyle(fontWeight: FontWeight.w600, color: primary),
                      ),
                    ],
                  ),
                ),
              )
            else
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste_go),
                label: const Text('Paste Recipe Code from Clipboard'),
              ),
          ],
        ),
      ),
    );
  }
}
