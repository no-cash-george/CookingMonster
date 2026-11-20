import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';

import '../models/recipe.dart';
import 'db_factory_stub.dart' if (dart.library.io) 'db_factory_io.dart' if (dart.library.html) 'db_factory_web.dart';

class DatabaseService {
  static const String _dbName = 'cooking_monster.db';
  final StoreRef<String, Map<String, dynamic>> _recipeStore = stringMapStoreFactory.store('recipes');

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;

    final factory = getPlatformDatabaseFactory();
    final String dbPath;

    if (kIsWeb) {
      dbPath = _dbName;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, _dbName);
    }

    _db = await factory.openDatabase(dbPath);
    return _db!;
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await _database;
    final snapshots = await _recipeStore.find(db, finder: Finder(sortOrders: [SortOrder(Field.key, false)]));

    return snapshots.map((snap) => Recipe.fromCompactJson(snap.key, Map<String, dynamic>.from(snap.value))).toList();
  }

  Future<void> upsertRecipe(Recipe recipe) async {
    final db = await _database;
    await _recipeStore.record(recipe.id).put(db, recipe.toCompactJson());
  }

  Future<void> deleteRecipe(String id) async {
    final db = await _database;
    await _recipeStore.record(id).delete(db);
  }
}
