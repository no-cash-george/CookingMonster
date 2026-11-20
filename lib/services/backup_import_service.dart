import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';
import 'ai_recipe_service.dart';

class BackupImportException implements Exception {
  final String message;
  const BackupImportException(this.message);

  @override
  String toString() => message;
}

class BackupPackage {
  final String? exportedAt;
  final String? name;
  final String? username;
  final UserGender? gender;
  final ThemeMode? themeMode;
  final MacosAccentColor? accentColor;
  final List<Recipe> recipes;

  const BackupPackage({
    this.exportedAt,
    this.name,
    this.username,
    this.gender,
    this.themeMode,
    this.accentColor,
    required this.recipes,
  });

  bool get hasValidProfile =>
      name != null && name!.trim().isNotEmpty && username != null && AppState.usernameRegex.hasMatch(username!);
}

class BackupImportService {
  static BackupPackage parseBackup(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      throw const BackupImportException('Select a .cmonu file or paste its JSON contents first.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const BackupImportException('Invalid .cmonu file: content is not valid JSON.');
    } catch (_) {
      throw const BackupImportException('Could not read the .cmonu backup file.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupImportException('Invalid .cmonu structure: expected a top-level JSON object.');
    }

    final format = decoded['format'];
    if (format != null && format != 'cmonu') {
      throw const BackupImportException('Unrecognized backup format. Expected a Cooking Monster (.cmonu) file.');
    }

    final exportedAt = decoded['exportedAt'] is String ? (decoded['exportedAt'] as String).trim() : null;

    // Parse profile
    String? parsedName;
    String? parsedUsername;
    UserGender? parsedGender;

    final rawProfile = decoded['profile'];
    if (rawProfile is Map<String, dynamic>) {
      final rawName = rawProfile['name'];
      if (rawName is String && rawName.trim().isNotEmpty) {
        parsedName = rawName.trim();
      }

      final rawUser = rawProfile['username'];
      if (rawUser is String && rawUser.trim().isNotEmpty) {
        final sanitized = AppState.sanitizeUsername(rawUser);
        if (AppState.usernameRegex.hasMatch(sanitized)) {
          parsedUsername = sanitized;
        }
      }

      final rawGender = rawProfile['gender'];
      if (rawGender is String) {
        final normalized = rawGender.trim().toLowerCase();
        for (final g in UserGender.values) {
          if (g.name.toLowerCase() == normalized) {
            parsedGender = g;
            break;
          }
        }
      }
    }

    // Parse preferences
    ThemeMode? parsedThemeMode;
    MacosAccentColor? parsedAccentColor;

    final rawPreferences = decoded['preferences'];
    if (rawPreferences is Map<String, dynamic>) {
      final rawTheme = rawPreferences['themeMode'];
      if (rawTheme is String) {
        final normalized = rawTheme.trim().toLowerCase();
        for (final mode in ThemeMode.values) {
          if (mode.name.toLowerCase() == normalized) {
            parsedThemeMode = mode;
            break;
          }
        }
      }

      final rawAccent = rawPreferences['accentColor'];
      if (rawAccent is String && rawAccent.trim().isNotEmpty) {
        parsedAccentColor = MacosAccentColor.fromName(rawAccent);
      }
    }

    // Parse recipes
    final rawRecipes = decoded['recipes'];
    if (rawRecipes is! List) {
      throw const BackupImportException('Invalid .cmonu file: missing "recipes" list.');
    }

    final parsedRecipes = <Recipe>[];
    for (int i = 0; i < rawRecipes.length; i++) {
      final item = rawRecipes[i];
      if (item is! Map<String, dynamic>) {
        throw BackupImportException('Recipe #${i + 1} in the backup is malformed.');
      }
      parsedRecipes.add(_parseRecipeEntry(item, i));
    }

    return BackupPackage(
      exportedAt: exportedAt,
      name: parsedName,
      username: parsedUsername,
      gender: parsedGender,
      themeMode: parsedThemeMode,
      accentColor: parsedAccentColor,
      recipes: parsedRecipes,
    );
  }

  static Recipe _parseRecipeEntry(Map<String, dynamic> map, int index) {
    final rawTitle = map['title'] ?? map['t'];
    if (rawTitle is! String || rawTitle.trim().isEmpty) {
      throw BackupImportException('Recipe #${index + 1} is missing a valid title.');
    }

    final rawId = map['id'];
    final id = (rawId is String && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : '${DateTime.now().microsecondsSinceEpoch}_$index';

    final rawAuthor = map['createdBy'] ?? map['author'] ?? map['c'];
    final createdBy = (rawAuthor is String && rawAuthor.trim().isNotEmpty) ? AppState.sanitizeUsername(rawAuthor) : '';

    final rawPortions = map['portions'] ?? map['yield'] ?? map['p'];
    final portions = (rawPortions is num && rawPortions.toInt() >= 1) ? rawPortions.toInt() : 1;

    final rawTimesMade = map['timesMade'] ?? map['tm'];
    final timesMade = (rawTimesMade is num && rawTimesMade.toInt() >= 0) ? rawTimesMade.toInt() : 0;

    final rawIngredients = map['ingredients'] ?? map['i'];
    if (rawIngredients is! List || rawIngredients.isEmpty) {
      throw BackupImportException('Recipe "${rawTitle.trim()}" has no ingredients.');
    }

    final ingredients = <Ingredient>[];
    for (int j = 0; j < rawIngredients.length; j++) {
      final ingMap = rawIngredients[j];
      if (ingMap is! Map<String, dynamic>) {
        throw BackupImportException('Ingredient #${j + 1} in "${rawTitle.trim()}" is malformed.');
      }
      final ingName = (ingMap['name'] ?? ingMap['n'])?.toString().trim() ?? '';
      final rawAmount = ingMap['amount'] ?? ingMap['g'];
      final amount = rawAmount is num ? rawAmount.toDouble() : double.tryParse(rawAmount?.toString() ?? '');
      if (ingName.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
        throw BackupImportException('Ingredient #${j + 1} in "${rawTitle.trim()}" has an invalid name or amount.');
      }

      final unit = AiRecipeService.normalizeUnit(ingMap['unit'] ?? ingMap['u']);
      final rawNote = ingMap['note'] ?? ingMap['m'];
      final note = (rawNote is String && rawNote.trim().isNotEmpty) ? rawNote.trim() : null;

      ingredients.add(Ingredient(name: ingName, amount: amount, unit: unit, note: note));
    }

    final rawSteps = map['steps'] ?? map['s'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      throw BackupImportException('Recipe "${rawTitle.trim()}" has no execution steps.');
    }

    final steps = rawSteps.map((s) => s?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
    if (steps.isEmpty) {
      throw BackupImportException('Recipe "${rawTitle.trim()}" has no valid execution steps.');
    }

    final checkedIngredients = <int>{};
    final rawCheckedIng = map['checkedIngredients'] ?? map['ci'];
    if (rawCheckedIng is List) {
      for (final idx in rawCheckedIng) {
        if (idx is int && idx >= 0 && idx < ingredients.length) {
          checkedIngredients.add(idx);
        }
      }
    }

    final completedSteps = <int>{};
    final rawCompletedStp = map['completedSteps'] ?? map['cs'];
    if (rawCompletedStp is List) {
      for (final idx in rawCompletedStp) {
        if (idx is int && idx >= 0 && idx < steps.length) {
          completedSteps.add(idx);
        }
      }
    }

    return Recipe(
      id: id,
      title: rawTitle.trim(),
      createdBy: createdBy,
      portions: portions,
      ingredients: ingredients,
      steps: steps,
      timesMade: timesMade,
      checkedIngredients: checkedIngredients,
      completedSteps: completedSteps,
    );
  }
}
