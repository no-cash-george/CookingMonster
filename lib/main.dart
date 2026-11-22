import 'package:flutter/cupertino.dart';
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
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(seedColor: accent.color, brightness: brightness);

    final onAccent = accent.useDarkForeground ? Colors.black : Colors.white;
    final containerColor = accent.color.withValues(alpha: isDark ? 0.28 : 0.16);
    final onContainerColor = isDark
        ? Color.lerp(accent.color, Colors.white, 0.72)!
        : Color.lerp(accent.color, Colors.black, 0.58)!;

    final scheme = baseScheme.copyWith(
      primary: accent.color,
      onPrimary: onAccent,
      primaryContainer: containerColor,
      onPrimaryContainer: onContainerColor,
      secondary: accent.color,
      onSecondary: onAccent,
      secondaryContainer: containerColor,
      onSecondaryContainer: onContainerColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: appState.platformOverride,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: accent.color,
        primaryContrastingColor: onAccent,
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
