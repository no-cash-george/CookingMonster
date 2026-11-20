import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import '../services/backup_import_service.dart';
import '../services/database_service.dart';

enum UserGender {
  male('Male', 'assets/icons/male.png'),
  female('Female', 'assets/icons/female.png'),
  other('Other', 'assets/icons/other.png');

  final String label;
  final String assetPath;
  const UserGender(this.label, this.assetPath);
}

/// All standard macOS System Settings -> Appearance accent colors excluding Multicolor.
enum MacosAccentColor {
  blue('Blue', Color(0xFF007AFF)),
  purple('Purple', Color(0xFFAF52DE)),
  pink('Pink', Color(0xFFFF2D55)),
  red('Red', Color(0xFFFF3B30)),
  orange('Orange', Color(0xFFFF9500)),
  yellow('Yellow', Color(0xFFFFCC00), useDarkForeground: true),
  green('Green', Color(0xFF34C759)),
  graphite('Graphite', Color(0xFF8E8E93));

  final String label;
  final Color color;
  final bool useDarkForeground;

  const MacosAccentColor(this.label, this.color, {this.useDarkForeground = false});

  static MacosAccentColor fromName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return MacosAccentColor.blue;
    }
    final normalized = rawName.trim().toLowerCase();
    for (final value in MacosAccentColor.values) {
      if (value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return MacosAccentColor.blue;
  }
}

class AppState extends ChangeNotifier {
  static final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  static String sanitizeUsername(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
  }

  final DatabaseService _dbService = DatabaseService();

  bool _isLoaded = false;
  bool _isOnboarded = false;
  String _name = '';
  String _username = '';
  UserGender _gender = UserGender.male;
  ThemeMode _themeMode = ThemeMode.system;
  MacosAccentColor _accentColor = MacosAccentColor.blue;
  TargetPlatform? _platformOverride;
  List<Recipe> _recipes = [];

  bool get isLoaded => _isLoaded;
  bool get isOnboarded => _isOnboarded;
  String get name => _name;
  String get username => _username;
  UserGender get gender => _gender;
  ThemeMode get themeMode => _themeMode;
  MacosAccentColor get accentColor => _accentColor;
  TargetPlatform? get platformOverride => kReleaseMode ? null : _platformOverride;
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  bool isAppleStyle(BuildContext context) {
    final effectiveOverride = kReleaseMode ? null : _platformOverride;
    final platform = effectiveOverride ?? Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = prefs.getBool('isOnboarded') ?? false;
    _name = prefs.getString('name') ?? '';
    _username = sanitizeUsername(prefs.getString('username') ?? '');

    final genderIndex = prefs.getInt('gender') ?? 0;
    _gender = UserGender.values[genderIndex.clamp(0, UserGender.values.length - 1)];

    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];

    _accentColor = MacosAccentColor.fromName(prefs.getString('accentColor'));

    final seedsCleaned = prefs.getBool('seedsCleaned') ?? false;
    if (!seedsCleaned) {
      await _dbService.deleteRecipe('seed_1');
      await _dbService.deleteRecipe('seed_2');
      await prefs.setBool('seedsCleaned', true);
    }

    _recipes = await _dbService.getAllRecipes();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveRecipe(Recipe recipe) async {
    await _dbService.upsertRecipe(recipe);
    _recipes = await _dbService.getAllRecipes();
    notifyListeners();
  }

  Future<void> deleteRecipe(String id) async {
    await _dbService.deleteRecipe(id);
    _recipes = await _dbService.getAllRecipes();
    notifyListeners();
  }

  /// Persists in-progress ingredient and execution step checkmarks locally.
  Future<void> updateRecipeProgress(
    String recipeId, {
    required Set<int> checkedIngredients,
    required Set<int> completedSteps,
  }) async {
    final index = _recipes.indexWhere((r) => r.id == recipeId);
    if (index == -1) return;

    final updated = _recipes[index].copyWith(
      checkedIngredients: Set<int>.unmodifiable(checkedIngredients),
      completedSteps: Set<int>.unmodifiable(completedSteps),
    );

    _recipes[index] = updated;
    notifyListeners();
    await _dbService.upsertRecipe(updated);
  }

  /// Increments [timesMade] and resets active checklist progress for the next cook.
  Future<Recipe?> markRecipeCompleted(String recipeId) async {
    final index = _recipes.indexWhere((r) => r.id == recipeId);
    if (index == -1) return null;

    final updated = _recipes[index].copyWith(
      timesMade: _recipes[index].timesMade + 1,
      checkedIngredients: const <int>{},
      completedSteps: const <int>{},
    );

    _recipes[index] = updated;
    notifyListeners();
    await _dbService.upsertRecipe(updated);
    return updated;
  }

  /// Manually adjusts [timesMade] by [delta] (clamped at 0).
  Future<void> adjustTimesMade(String recipeId, int delta) async {
    final index = _recipes.indexWhere((r) => r.id == recipeId);
    if (index == -1) return;

    final nextCount = (_recipes[index].timesMade + delta).clamp(0, 999999);
    if (nextCount == _recipes[index].timesMade) return;

    final updated = _recipes[index].copyWith(timesMade: nextCount);
    _recipes[index] = updated;
    notifyListeners();
    await _dbService.upsertRecipe(updated);
  }

  Future<void> saveUserProfile({required String name, required String username, required UserGender gender}) async {
    final sanitized = sanitizeUsername(username);
    if (name.trim().isEmpty || !usernameRegex.hasMatch(sanitized)) {
      return;
    }

    _name = name.trim();
    _username = sanitized;
    _gender = gender;
    _isOnboarded = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboarded', true);
    await prefs.setString('name', _name);
    await prefs.setString('username', _username);
    await prefs.setInt('gender', _gender.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setAccentColor(MacosAccentColor color) async {
    _accentColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accentColor', color.name);
  }

  /// Restores recipes, profile, and appearance preferences from a parsed `.cmonu` backup.
  Future<void> restoreFromBackup(
    BackupPackage backup, {
    required bool replaceExisting,
    required bool restoreProfileAndSettings,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (replaceExisting) {
      for (final existing in List<Recipe>.from(_recipes)) {
        await _dbService.deleteRecipe(existing.id);
      }
    }

    for (final recipe in backup.recipes) {
      await _dbService.upsertRecipe(recipe);
    }

    if (restoreProfileAndSettings) {
      if (backup.hasValidProfile) {
        _name = backup.name!;
        _username = backup.username!;
        _gender = backup.gender ?? UserGender.male;
        _isOnboarded = true;

        await prefs.setBool('isOnboarded', true);
        await prefs.setString('name', _name);
        await prefs.setString('username', _username);
        await prefs.setInt('gender', _gender.index);
      } else if (!_isOnboarded) {
        _name = _name.isNotEmpty ? _name : 'Chef';
        _username = _username.isNotEmpty ? _username : 'chef';
        _isOnboarded = true;

        await prefs.setBool('isOnboarded', true);
        await prefs.setString('name', _name);
        await prefs.setString('username', _username);
        await prefs.setInt('gender', _gender.index);
      }

      if (backup.themeMode != null) {
        _themeMode = backup.themeMode!;
        await prefs.setInt('themeMode', _themeMode.index);
      }

      if (backup.accentColor != null) {
        _accentColor = backup.accentColor!;
        await prefs.setString('accentColor', _accentColor.name);
      }
    } else if (!_isOnboarded) {
      _name = backup.hasValidProfile ? backup.name! : 'Chef';
      _username = backup.hasValidProfile ? backup.username! : 'chef';
      _gender = backup.gender ?? UserGender.male;
      _isOnboarded = true;

      await prefs.setBool('isOnboarded', true);
      await prefs.setString('name', _name);
      await prefs.setString('username', _username);
      await prefs.setInt('gender', _gender.index);
    }

    _recipes = await _dbService.getAllRecipes();
    notifyListeners();
  }

  void setPlatformOverride(TargetPlatform? platform) {
    if (kReleaseMode) return;
    _platformOverride = platform;
    notifyListeners();
  }
}
