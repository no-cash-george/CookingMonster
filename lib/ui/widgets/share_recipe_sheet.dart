import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/recipe.dart';
import '../../services/share_codec.dart';
import '../../state/app_state.dart';
import 'platform_primitives.dart';

Future<void> showShareRecipeSheet(BuildContext context, AppState appState, Recipe recipe) {
  final isApple = appState.isAppleStyle(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ShareRecipeSheet(recipe: recipe, isApple: isApple),
  );
}

class _ShareRecipeSheet extends StatefulWidget {
  final Recipe recipe;
  final bool isApple;

  const _ShareRecipeSheet({required this.recipe, required this.isApple});

  @override
  State<_ShareRecipeSheet> createState() => _ShareRecipeSheetState();
}

class _ShareRecipeSheetState extends State<_ShareRecipeSheet> {
  late final String _payload;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _payload = ShareCodec.encode(widget.recipe);
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _payload));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final body = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: muted.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            'Share Recipe',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.recipe.displayTitleWithAuthor,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: QrImageView(
                data: _payload,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scan with Cooking Monster · ${_payload.length} bytes compressed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 20),
          if (widget.isApple) ...[
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(16),
              onPressed: _copyToClipboard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_copied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_clipboard, size: 18),
                  const SizedBox(width: 8),
                  Text(_copied ? 'Copied to Clipboard' : 'Copy Recipe Code'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _copyToClipboard,
              icon: Icon(_copied ? Icons.check : Icons.copy_all_outlined),
              label: Text(_copied ? 'Copied to Clipboard' : 'Copy Recipe Code'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ],
      ),
    );

    if (widget.isApple) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: LiquidGlassContainer(
          blurSigma: 28,
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: body,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: body,
    );
  }
}
