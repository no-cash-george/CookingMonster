import 'dart:convert';

import '../models/recipe.dart';
import '../state/app_state.dart';
import 'backup_export_stub.dart'
    if (dart.library.io) 'backup_export_io.dart'
    if (dart.library.js_interop) 'backup_export_web.dart';

class BackupExportResult {
  final String fileName;
  final String location;
  final String jsonContent;

  const BackupExportResult({required this.fileName, required this.location, required this.jsonContent});
}

class BackupExportService {
  /// Builds a complete, pretty-printed JSON payload representing all
  /// user profile settings, preferences, and local recipes.
  static String buildFullExportJson(AppState appState) {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'format': 'cmonu',
      'version': 1,
      'app': 'Cooking Monster',
      'exportedAt': now.toIso8601String(),
      'profile': <String, dynamic>{
        'isOnboarded': appState.isOnboarded,
        'name': appState.name,
        'username': appState.username,
        'gender': appState.gender.name,
      },
      'preferences': <String, dynamic>{'themeMode': appState.themeMode.name, 'accentColor': appState.accentColor.name},
      'recipes': appState.recipes.map(_serializeRecipe).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Map<String, dynamic> _serializeRecipe(Recipe recipe) {
    return <String, dynamic>{
      'id': recipe.id,
      'title': recipe.title,
      'createdBy': recipe.createdBy,
      'portions': recipe.portions,
      'timesMade': recipe.timesMade,
      'ingredients': recipe.ingredients
          .map(
            (ing) => <String, dynamic>{
              'name': ing.name,
              'amount': ing.amount % 1 == 0 ? ing.amount.toInt() : ing.amount,
              'unit': ing.unit == IngredientUnit.count ? 'pc' : 'g',
              if (ing.note != null && ing.note!.isNotEmpty) 'note': ing.note,
            },
          )
          .toList(),
      'steps': recipe.steps,
      'checkedIngredients': (recipe.checkedIngredients.toList()..sort()),
      'completedSteps': (recipe.completedSteps.toList()..sort()),
    };
  }

  static String _buildFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'cooking_monster_backup_$stamp.cmonu';
  }

  /// Exports all app data to a `.cmonu` JSON file and returns the saved location.
  static Future<BackupExportResult> exportAllData(AppState appState) async {
    final fileName = _buildFileName();
    final jsonContent = buildFullExportJson(appState);
    final location = await exportCmonuFileImpl(fileName: fileName, jsonContent: jsonContent);

    return BackupExportResult(fileName: fileName, location: location, jsonContent: jsonContent);
  }

  /// Reads a file from disk when `file_picker` returns a path instead of bytes.
  static Future<String> readFileFromPath(String filePath) {
    return readCmonuFileFromPathImpl(filePath);
  }
}
