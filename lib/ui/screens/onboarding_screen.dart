import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/import_backup_sheet.dart';
import '../widgets/platform_primitives.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  UserGender _selectedGender = UserGender.male;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter your name.');
      return;
    }
    if (!AppState.usernameRegex.hasMatch(username)) {
      setState(() => _errorText = 'Username must be 1–64 chars (letters, numbers, _ or -).');
      return;
    }

    setState(() => _errorText = null);
    await widget.appState.saveUserProfile(name: name, username: username, gender: _selectedGender);
  }

  Future<void> _openStartupImport() async {
    await showImportBackupSheet(context, widget.appState, isInitialStartup: true);
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: UserGenderAvatar(gender: _selectedGender, size: 76, isApple: isApple),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to Cooking Monster',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your local kitchen profile or restore an existing backup.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 22),
        Text('Your Name', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (isApple)
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g., George',
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
            ),
          )
        else
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g., George',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Username (@handle)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (isApple)
          CupertinoTextField(
            controller: _usernameController,
            placeholder: 'e.g., no-cash-george',
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
            ),
          )
        else
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'e.g., no-cash-george',
              prefixText: '@',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
        const SizedBox(height: 16),
        Text('Avatar Icon', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<UserGender>(
          segments: UserGender.values.map((g) => ButtonSegment<UserGender>(value: g, label: Text(g.label))).toList(),
          selected: <UserGender>{_selectedGender},
          onSelectionChanged: (selection) {
            setState(() => _selectedGender = selection.first);
          },
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 20),
        if (isApple)
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(16),
            onPressed: _submit,
            child: const Text('Start Cooking'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _submit,
            child: const Text('Start Cooking'),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: muted, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ],
          ),
        ),
        if (isApple)
          CupertinoButton(
            color: primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            onPressed: _openStartupImport,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_down_doc, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  'Import Data',
                  style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _openStartupImport,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import Data'),
          ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: isApple
                  ? LiquidGlassContainer(
                      blurSigma: 26,
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.all(24),
                      child: formContent,
                    )
                  : Card.filled(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Padding(padding: const EdgeInsets.all(24), child: formContent),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
