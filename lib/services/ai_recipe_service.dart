import 'dart:convert';

import '../models/recipe.dart';

class AiRecipeParseException implements Exception {
  final String message;
  const AiRecipeParseException(this.message);

  @override
  String toString() => message;
}

class AiRecipeService {
  static final RegExp _allowedUsernameChars = RegExp(r'[^a-zA-Z0-9_-]');
  static final RegExp _fencedBlockRegex = RegExp(r'```(?:json|JSON)?\s*([\s\S]*?)\s*```');

  /// Generates a self-contained prompt that forces an LLM to return raw JSON
  /// matching Cooking Monster's Recipe schema and metric/piece unit rules.
  static String buildPrompt(String dishRequest) {
    final cleanedRequest = dishRequest.trim();

    return '''
Create a detailed, authentic recipe for: "$cleanedRequest"

CRITICAL OUTPUT RULES — FOLLOW STRICTLY:
1. Return ONLY raw, valid JSON. Do NOT include markdown code fences (```json), conversational text, explanations, or notes outside the JSON object.
2. Use this exact JSON schema and field names:
{
  "title": "Recipe Name",
  "yield": 4,
  "author": "@ai_chef",
  "ingredients": [
    {
      "name": "Ingredient Name",
      "amount": 250,
      "unit": "g",
      "note": "optional preparation note or null"
    }
  ],
  "steps": [
    "Clear, actionable step 1.",
    "Clear, actionable step 2."
  ]
}
3. Field constraints:
   - "title": Non-empty string.
   - "yield": Integer >= 1 representing total portions yielded.
   - "author": Must start with "@" followed by 1 to 64 characters using ONLY letters (a-z, A-Z), numbers (0-9), underscores (_), or hyphens (-). Default to "@ai_chef".
   - "ingredients": Non-empty array. Each item MUST use ONLY "g" (metric grams) or "pc" (discrete piece count) for "unit".
   - Convert ALL volume, imperial, or spoon measurements (cups, tbsp, tsp, ml, L, oz, lb) into accurate metric grams ("g") or whole/fractional item counts ("pc"). Never output "ml", "tbsp", "cup", or "oz".
   - "amount": Positive number (integer or decimal).
   - "steps": Non-empty array of clear, chronological cooking instruction strings.
''';
  }

  /// Strips accidental Markdown code fences and leading/trailing prose.
  static String extractJsonText(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    final fenceMatch = _fencedBlockRegex.firstMatch(trimmed);
    if (fenceMatch != null && fenceMatch.group(1) != null) {
      return fenceMatch.group(1)!.trim();
    }

    final withoutEdges = trimmed
        .replaceFirst(RegExp(r'^```(?:json|JSON)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final firstBrace = withoutEdges.indexOf('{');
    final lastBrace = withoutEdges.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      return withoutEdges.substring(firstBrace, lastBrace + 1).trim();
    }

    return withoutEdges;
  }

  /// Sanitizes an author handle to match [a-zA-Z0-9_-] (1..64 chars, no leading '@'),
  /// defaulting to 'ai_chef' (rendered as '@ai_chef') when missing or invalid.
  static String sanitizeAuthor(dynamic rawAuthor) {
    if (rawAuthor is! String) return 'ai_chef';
    final withoutAt = rawAuthor.trim().replaceFirst(RegExp(r'^@+'), '');
    final cleaned = withoutAt.replaceAll(_allowedUsernameChars, '');
    if (cleaned.isEmpty) return 'ai_chef';
    return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
  }

  /// Normalizes AI unit strings into [IngredientUnit.grams] or [IngredientUnit.count].
  static IngredientUnit normalizeUnit(dynamic rawUnit) {
    if (rawUnit == null) return IngredientUnit.grams;

    final normalized = rawUnit.toString().trim().toLowerCase().replaceAll(RegExp(r'\.+$'), '');

    const countTokens = <String>{
      'pc',
      'pcs',
      'piece',
      'pieces',
      'count',
      'counts',
      'item',
      'items',
      'unit',
      'units',
      'whole',
      'clove',
      'cloves',
      'slice',
      'slices',
      'c',
    };

    if (countTokens.contains(normalized)) {
      return IngredientUnit.count;
    }

    return IngredientUnit.grams;
  }

  /// Parses, validates, and sanitizes raw AI JSON text into a [Recipe].
  /// Throws [AiRecipeParseException] with a user-friendly message on any error.
  static Recipe parseAndValidate(String rawInput) {
    final jsonText = extractJsonText(rawInput);
    if (jsonText.isEmpty) {
      throw const AiRecipeParseException('Paste the JSON response from your AI assistant before importing.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const AiRecipeParseException('Invalid JSON format. Make sure you copied the complete JSON response.');
    } catch (_) {
      throw const AiRecipeParseException('Could not parse JSON. Verify the response is valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiRecipeParseException('Expected a JSON object at the top level of the recipe.');
    }

    // 1. Validate title
    final rawTitle = decoded['title'] ?? decoded['t'];
    if (rawTitle is! String || rawTitle.trim().isEmpty) {
      throw const AiRecipeParseException('Missing or empty "title" field in the recipe JSON.');
    }
    final title = rawTitle.trim();

    // 2. Validate yield (portions >= 1)
    final rawYield = decoded['yield'] ?? decoded['portions'] ?? decoded['p'];
    int? portions;
    if (rawYield is int) {
      portions = rawYield;
    } else if (rawYield is num && rawYield % 1 == 0) {
      portions = rawYield.toInt();
    } else if (rawYield is String) {
      portions = int.tryParse(rawYield.trim());
    }

    if (portions == null || portions < 1) {
      throw const AiRecipeParseException('The "yield" field must be an integer of at least 1.');
    }

    // 3. Sanitize author (defaults to @ai_chef -> stored as 'ai_chef')
    final author = sanitizeAuthor(decoded['author'] ?? decoded['createdBy'] ?? decoded['c']);

    // 4. Validate and normalize ingredients
    final rawIngredients = decoded['ingredients'] ?? decoded['i'];
    if (rawIngredients is! List || rawIngredients.isEmpty) {
      throw const AiRecipeParseException('The "ingredients" list must contain at least one ingredient.');
    }

    final ingredients = <Ingredient>[];
    for (int idx = 0; idx < rawIngredients.length; idx++) {
      final entry = rawIngredients[idx];
      if (entry is! Map<String, dynamic>) {
        throw AiRecipeParseException('Ingredient #${idx + 1} must be a JSON object.');
      }

      final rawName = entry['name'] ?? entry['n'];
      if (rawName is! String || rawName.trim().isEmpty) {
        throw AiRecipeParseException('Ingredient #${idx + 1} is missing a valid "name".');
      }
      final ingName = rawName.trim();

      final rawAmount = entry['amount'] ?? entry['quantity'] ?? entry['g'];
      double? amount;
      if (rawAmount is num) {
        amount = rawAmount.toDouble();
      } else if (rawAmount is String) {
        amount = double.tryParse(rawAmount.trim().replaceAll(',', '.'));
      }

      if (amount == null || !amount.isFinite || amount <= 0) {
        throw AiRecipeParseException('Ingredient "$ingName" must have a positive numeric "amount".');
      }

      final unit = normalizeUnit(entry['unit'] ?? entry['u']);

      final rawNote = entry['note'] ?? entry['m'];
      final note = (rawNote is String && rawNote.trim().isNotEmpty) ? rawNote.trim() : null;

      ingredients.add(Ingredient(name: ingName, amount: amount, unit: unit, note: note));
    }

    // 5. Validate execution steps
    final rawSteps = decoded['steps'] ?? decoded['s'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      throw const AiRecipeParseException('The "steps" list must contain at least one instruction.');
    }

    final steps = <String>[];
    for (int idx = 0; idx < rawSteps.length; idx++) {
      final stepItem = rawSteps[idx];
      if (stepItem is! String || stepItem.trim().isEmpty) {
        throw AiRecipeParseException('Step #${idx + 1} must be a non-empty text instruction.');
      }
      steps.add(stepItem.trim());
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return Recipe(id: id, title: title, createdBy: author, portions: portions, ingredients: ingredients, steps: steps);
  }
}
