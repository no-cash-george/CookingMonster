import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.load();
  runApp(CookingMonsterApp(appState: appState));
}

class CookingMonsterApp extends StatelessWidget {
  final AppState appState;
  const CookingMonsterApp({super.key, required this.appState});

  ThemeData _buildTheme(Brightness brightness) {
    final accent = appState.accentColor;
    final baseScheme = ColorScheme.fromSeed(seedColor: accent.color, brightness: brightness);

    final effectivePlatform = appState.platformOverride ?? defaultTargetPlatform;
    final isApplePlatform = effectivePlatform == TargetPlatform.iOS || effectivePlatform == TargetPlatform.macOS;

    final scheme = isApplePlatform
        ? baseScheme.copyWith(primary: accent.color, onPrimary: accent.useDarkForeground ? Colors.black : Colors.white)
        : baseScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: appState.platformOverride,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: accent.color,
        primaryContrastingColor: accent.useDarkForeground ? Colors.black : Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cooking Monster',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: !appState.isLoaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : appState.isOnboarded
              ? MainShell(appState: appState)
              : OnboardingScreen(appState: appState),
        );
      },
    );
  }
}
