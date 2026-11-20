import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/backup_export_service.dart';
import '../../state/app_state.dart';
import '../widgets/import_backup_sheet.dart';
import '../widgets/platform_primitives.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;
  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late UserGender _selectedGender;
  String? _profileError;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.name);
    _usernameController = TextEditingController(text: widget.appState.username);
    _selectedGender = widget.appState.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final rawUsername = _usernameController.text.trim();

    if (name.isEmpty) {
      setState(() => _profileError = 'Display name cannot be empty.');
      return;
    }

    if (!AppState.usernameRegex.hasMatch(rawUsername)) {
      setState(() => _profileError = 'Username must be 1-64 chars (letters, numbers, _ or -).');
      return;
    }

    setState(() => _profileError = null);

    await widget.appState.saveUserProfile(name: name, username: rawUsername, gender: _selectedGender);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  Future<void> _exportAllData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final result = await BackupExportService.exportAllData(widget.appState);
      if (!mounted) return;
      setState(() => _isExporting = false);
      await _showExportSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _openImportBackup() async {
    final imported = await showImportBackupSheet(context, widget.appState, isInitialStartup: false);

    if (imported == true && mounted) {
      setState(() {
        _nameController.text = widget.appState.name;
        _usernameController.text = widget.appState.username;
        _selectedGender = widget.appState.gender;
        _profileError = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Backup data imported successfully.')));
    }
  }

  Future<void> _showExportSuccessDialog(BackupExportResult result) {
    final isApple = widget.appState.isAppleStyle(context);
    final recipeCount = widget.appState.recipes.length;
    final countLabel = recipeCount == 1 ? '1 recipe' : '$recipeCount recipes';

    if (isApple) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Backup Exported'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Exported profile, settings, and $countLabel to:\n\n${result.location}'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.jsonContent));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Backup JSON copied to clipboard.')));
              },
              child: const Text('Copy JSON'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup Exported'),
        content: Text('Exported profile, settings, and $countLabel to:\n\n${result.location}'),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.jsonContent));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Backup JSON copied to clipboard.')));
            },
            child: const Text('Copy JSON'),
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
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
    final selectedAccent = widget.appState.accentColor;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafeInset + 110),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // PROFILE SECTION
          _wrapSection(
            isApple: isApple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    UserGenderAvatar(gender: _selectedGender, size: 48, isApple: isApple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chef Profile',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Used for recipe attribution & greeting.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Display Name',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildInput(context: context, isApple: isApple, controller: _nameController, hint: 'Your name'),
                const SizedBox(height: 12),
                Text(
                  'Username (@handle)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildInput(context: context, isApple: isApple, controller: _usernameController, hint: 'username'),
                const SizedBox(height: 14),
                Text('Avatar', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedButton<UserGender>(
                  segments: UserGender.values
                      .map((g) => ButtonSegment<UserGender>(value: g, label: Text(g.label)))
                      .toList(),
                  selected: <UserGender>{_selectedGender},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedGender = selection.first);
                  },
                ),
                if (_profileError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _profileError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isApple)
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // APPEARANCE SECTION (Theme Mode + macOS Accent Color Picker)
          _wrapSection(
            isApple: isApple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how Dark Mode behaves across the app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Always Off')),
                    ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Always On')),
                  ],
                  selected: <ThemeMode>{widget.appState.themeMode},
                  onSelectionChanged: (selection) {
                    widget.appState.setThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Accent Color',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      selectedAccent.label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: muted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: MacosAccentColor.values.map((accent) {
                    final isSelected = selectedAccent == accent;
                    return Tooltip(
                      message: accent.label,
                      child: GestureDetector(
                        onTap: () => widget.appState.setAccentColor(accent),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 34,
                          height: 34,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? accent.color : Colors.transparent, width: 2.2),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.color,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.useDarkForeground ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // DATA & BACKUP SECTION
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
                        isApple ? CupertinoIcons.arrow_up_doc_fill : Icons.file_download_outlined,
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
                            'Data & Backup',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Export or restore all recipes, cook counts, and settings via .cmonu files.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isApple) ...[
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _isExporting ? null : _exportAllData,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.share_up, size: 18),
                        const SizedBox(width: 8),
                        Text(_isExporting ? 'Exporting...' : 'Export All Data'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CupertinoButton(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _openImportBackup,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.arrow_down_doc, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          'Import Data Backup',
                          style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isExporting ? null : _exportAllData,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: Text(_isExporting ? 'Exporting...' : 'Export All Data'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _openImportBackup,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Import Data Backup'),
                  ),
                ],
              ],
            ),
          ),

          // DEVELOPER MENU — automatically omitted in production release builds
          if (!kReleaseMode) ...[
            const SizedBox(height: 16),
            _wrapSection(
              isApple: isApple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isApple ? CupertinoIcons.hammer_fill : Icons.developer_mode_rounded,
                        size: 18,
                        color: primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Developer · UI Engine',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preview Apple Liquid Glass or Material You (hidden in release builds).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<TargetPlatform?>(
                    segments: const [
                      ButtonSegment<TargetPlatform?>(value: null, label: Text('Auto')),
                      ButtonSegment<TargetPlatform?>(value: TargetPlatform.iOS, label: Text('iOS Glass')),
                      ButtonSegment<TargetPlatform?>(value: TargetPlatform.android, label: Text('Material You')),
                    ],
                    selected: <TargetPlatform?>{widget.appState.platformOverride},
                    onSelectionChanged: (selection) {
                      widget.appState.setPlatformOverride(selection.first);
                    },
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildInput({
    required BuildContext context,
    required bool isApple,
    required TextEditingController controller,
    required String hint,
  }) {
    if (isApple) {
      return CupertinoTextField(
        controller: controller,
        placeholder: hint,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }
}
