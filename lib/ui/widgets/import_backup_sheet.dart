import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/backup_export_service.dart';
import '../../services/backup_import_service.dart';
import '../../state/app_state.dart';
import 'platform_primitives.dart';

Future<bool?> showImportBackupSheet(BuildContext context, AppState appState, {required bool isInitialStartup}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ImportBackupSheet(appState: appState, isInitialStartup: isInitialStartup),
  );
}

class _ImportBackupSheet extends StatefulWidget {
  final AppState appState;
  final bool isInitialStartup;

  const _ImportBackupSheet({required this.appState, required this.isInitialStartup});

  @override
  State<_ImportBackupSheet> createState() => _ImportBackupSheetState();
}

class _ImportBackupSheetState extends State<_ImportBackupSheet> {
  final TextEditingController _jsonController = TextEditingController();
  bool _showPasteInput = false;
  bool _isBusy = false;
  String? _selectedFileName;
  String? _errorMessage;
  BackupPackage? _parsedPackage;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickCmonuFile() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _isBusy = false);
        return;
      }

      final file = result.files.single;
      String rawContent;
      if (file.bytes != null) {
        rawContent = utf8.decode(file.bytes!);
      } else if (file.path != null && file.path!.isNotEmpty) {
        rawContent = await BackupExportService.readFileFromPath(file.path!);
      } else {
        throw const BackupImportException('Could not read bytes from the selected file.');
      }

      final parsed = BackupImportService.parseBackup(rawContent);
      if (!mounted) return;
      setState(() {
        _selectedFileName = file.name;
        _parsedPackage = parsed;
        _errorMessage = null;
        _isBusy = false;
      });
    } on BackupImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _parsedPackage = null;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to open backup file: $e';
        _parsedPackage = null;
        _isBusy = false;
      });
    }
  }

  Future<void> _pasteAndValidate() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Your clipboard is empty.';
      });
      return;
    }

    _jsonController.text = text;
    _validatePastedText(text);
  }

  void _validatePastedText(String text) {
    try {
      final parsed = BackupImportService.parseBackup(text);
      setState(() {
        _selectedFileName = 'Pasted Backup JSON';
        _parsedPackage = parsed;
        _errorMessage = null;
      });
    } on BackupImportException catch (e) {
      setState(() {
        _parsedPackage = null;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _applyImport({required bool replaceExisting}) async {
    final pkg = _parsedPackage;
    if (pkg == null || _isBusy) return;

    setState(() => _isBusy = true);
    await widget.appState.restoreFromBackup(
      pkg,
      replaceExisting: replaceExisting,
      restoreProfileAndSettings: replaceExisting || widget.isInitialStartup,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isApple ? CupertinoIcons.arrow_down_doc_fill : Icons.upload_file_rounded,
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
                        'Import Data',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Restore recipes, cook counts, and settings from a backup.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(isApple ? CupertinoIcons.xmark : Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (isApple)
              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(16),
                onPressed: _isBusy ? null : _pickCmonuFile,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.folder_open, size: 19),
                    const SizedBox(width: 8),
                    Text(_isBusy ? 'Reading File...' : 'Choose a File'),
                  ],
                ),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isBusy ? null : _pickCmonuFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(_isBusy ? 'Reading File...' : 'Choose a File'),
              ),

            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPasteInput = !_showPasteInput;
                    _errorMessage = null;
                  });
                },
                icon: Icon(_showPasteInput ? Icons.keyboard_arrow_up : Icons.content_paste_rounded, size: 18),
                label: Text(_showPasteInput ? 'Hide JSON Paste Box' : 'Or Paste JSON Text'),
              ),
            ),

            if (_showPasteInput) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pasteAndValidate,
                  icon: const Icon(Icons.content_paste_go, size: 17),
                  label: const Text('Paste from Clipboard'),
                ),
              ),
              if (isApple)
                CupertinoTextField(
                  controller: _jsonController,
                  placeholder: '{\n  "format": "cmonu",\n  ...\n}',
                  minLines: 4,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  padding: const EdgeInsets.all(12),
                  onChanged: _validatePastedText,
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                )
              else
                TextField(
                  controller: _jsonController,
                  minLines: 4,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: _validatePastedText,
                  decoration: const InputDecoration(
                    hintText: '{\n  "format": "cmonu",\n  ...\n}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.78),
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

            if (_parsedPackage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isApple ? CupertinoIcons.checkmark_seal_fill : Icons.verified_rounded,
                          size: 18,
                          color: primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFileName ?? 'Valid Backup',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800, color: primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_parsedPackage!.hasValidProfile)
                      Text(
                        'Profile: ${_parsedPackage!.name} (@${_parsedPackage!.username})',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    Text(
                      _parsedPackage!.recipes.length == 1
                          ? 'Recipes: 1 recipe ready to restore'
                          : 'Recipes: ${_parsedPackage!.recipes.length} recipes ready to restore',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isInitialStartup)
                isApple
                    ? CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _isBusy ? null : () => _applyImport(replaceExisting: true),
                        child: const Text('Restore Backup & Enter App'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isBusy ? null : () => _applyImport(replaceExisting: true),
                        child: const Text('Restore Backup & Enter App'),
                      )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: isApple
                          ? CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              color: primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              onPressed: _isBusy ? null : () => _applyImport(replaceExisting: false),
                              child: Text(
                                'Merge Recipes',
                                style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                              ),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isBusy ? null : () => _applyImport(replaceExisting: false),
                              child: const Text('Merge Recipes'),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: isApple
                          ? CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              borderRadius: BorderRadius.circular(14),
                              onPressed: _isBusy ? null : () => _applyImport(replaceExisting: true),
                              child: const Text('Replace All Data'),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isBusy ? null : () => _applyImport(replaceExisting: true),
                              child: const Text('Replace All Data'),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );

    if (isApple) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: LiquidGlassContainer(blurSigma: 30, borderRadius: BorderRadius.circular(28), child: body),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: body,
    );
  }
}
