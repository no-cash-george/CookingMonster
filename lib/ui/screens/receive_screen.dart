import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/recipe.dart';
import '../../services/share_codec.dart';
import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';

class ReceiveScreen extends StatefulWidget {
  final AppState appState;
  final bool isActive;

  const ReceiveScreen({super.key, required this.appState, required this.isActive});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  final TextEditingController _codeController = TextEditingController();

  bool _isCameraActive = false;
  bool _isDialogOpen = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );

    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) {
          _startCamera();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReceiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startCamera();
      } else {
        _stopCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;

    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_isCameraActive || !mounted || !widget.isActive) return;
    _isCameraActive = true;
    try {
      await _scannerController.start();
    } catch (_) {
      _isCameraActive = false;
    }
  }

  Future<void> _stopCamera() async {
    if (!_isCameraActive) return;
    _isCameraActive = false;
    try {
      await _scannerController.stop();
    } catch (_) {
      // Ignore stop errors if the platform view was already torn down.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (!widget.isActive || _isDialogOpen) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().startsWith('cm1:')) {
        _handleIncomingPayload(raw.trim());
        break;
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Your clipboard is empty.');
      return;
    }

    _codeController.text = text;
    await _handleIncomingPayload(text);
  }

  Future<void> _handleIncomingPayload(String rawPayload) async {
    if (_isDialogOpen) return;

    final Recipe decodedRecipe;
    try {
      decodedRecipe = ShareCodec.decode(rawPayload);
      if (mounted && _errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      return;
    }

    _isDialogOpen = true;
    await _stopCamera();
    if (!mounted) {
      _isDialogOpen = false;
      return;
    }

    final shouldSave = await _showConfirmRecipeDialog(decodedRecipe);
    _isDialogOpen = false;

    if (!mounted) return;

    if (shouldSave == true) {
      await widget.appState.saveRecipe(decodedRecipe);
      _codeController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saved "${decodedRecipe.title}" to your recipes.')));
    }

    if (mounted && widget.isActive) {
      await _startCamera();
    }
  }

  Future<bool?> _showConfirmRecipeDialog(Recipe recipe) {
    final isApple = widget.appState.isAppleStyle(context);
    final portionLabel = recipe.portions == 1 ? '1 portion' : '${recipe.portions} portions';
    final summary =
        '${recipe.displayTitleWithAuthor}\n\n$portionLabel · ${recipe.ingredients.length} ingredients · ${recipe.steps.length} steps';

    if (isApple) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Import Shared Recipe?'),
          content: Padding(padding: const EdgeInsets.only(top: 8), child: Text(summary)),
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
        title: const Text('Import Shared Recipe?'),
        content: Text(summary),
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
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafeInset + 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receive Recipe',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Scan a Cooking Monster QR code or paste a cm1: code.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (widget.isActive)
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scannerController,
                  builder: (context, state, _) {
                    final torchOn = state.torchState == TorchState.on;
                    return IconButton.filledTonal(
                      tooltip: torchOn ? 'Turn Flash Off' : 'Turn Flash On',
                      onPressed: () => _scannerController.toggleTorch(),
                      icon: Icon(
                        torchOn
                            ? (isApple ? CupertinoIcons.bolt_fill : Icons.flash_on_rounded)
                            : (isApple ? CupertinoIcons.bolt : Icons.flash_off_rounded),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Camera Viewfinder (only mounted while Receive tab is active)
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: Colors.black,
                child: widget.isActive
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onBarcodeDetect,
                            errorBuilder: (context, error, child) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 36),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Camera unavailable (${error.errorCode.name}).\nGrant camera access in Settings or paste a recipe code below.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: primary.withValues(alpha: 0.9), width: 3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white38, size: 48)),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Manual cm1: Payload Import Card
          _wrapSection(
            isApple: isApple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paste Recipe Code',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_go, size: 18),
                      label: const Text('Paste'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (isApple)
                  CupertinoTextField(
                    controller: _codeController,
                    placeholder: 'cm1:eJxV...',
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                else
                  TextField(
                    controller: _codeController,
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'cm1:eJxV...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                const SizedBox(height: 12),
                if (isApple)
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () => _handleIncomingPayload(_codeController.text),
                    child: const Text('Import Code'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _handleIncomingPayload(_codeController.text),
                    child: const Text('Import Code'),
                  ),
              ],
            ),
          ),
        ],
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
