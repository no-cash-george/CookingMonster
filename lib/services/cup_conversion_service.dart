import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:units_converter/units_converter.dart';

enum DensitySource {
  online('Online'),
  cached('Cached'),
  local('Local table'),
  waterEstimate('Water est.');

  final String label;
  const DensitySource(this.label);
}

class CupConversionResult {
  final double grams;
  final double usCups;
  final double usTablespoons;
  final double usTeaspoons;
  final double gramsPerCup;
  final String formattedVolume;
  final DensitySource source;

  const CupConversionResult({
    required this.grams,
    required this.usCups,
    required this.usTablespoons,
    required this.usTeaspoons,
    required this.gramsPerCup,
    required this.formattedVolume,
    required this.source,
  });
}

class CupConversionService {
  static const String _prefsCacheKey = 'cup_density_cache_v2';
  static const double _usCupInMl = 236.5882365;
  static const double _usFlOzInMl = 29.5735295625;

  /// Stores only validated densities verified from online lookups.
  static final Map<String, double> _onlineCache = {};
  static bool _prefsLoaded = false;

  /// Words that indicate a packaged snack/processed food rather than a raw ingredient.
  static const Set<String> _excludedProductTokens = {
    'cereal',
    'flakes',
    'puffs',
    'puffed',
    'popcorn',
    'chips',
    'crackers',
    'cookie',
    'cookies',
    'biscuit',
    'biscuits',
    'candy',
    'cotton',
    'marshmallow',
    'marshmallows',
    'wafer',
    'wafers',
    'soda',
    'drink',
    'beverage',
    'bar',
    'bars',
    'cake',
    'donut',
    'muffin',
    'pretzel',
    'pretzels',
  };

  /// Curated local fallback & physical reference table in grams per milliliter (g/mL).
  static const Map<String, double> _localDensityGPerMl = {
    // Liquids & Dairy
    'water': 1.00,
    'milk': 1.03,
    'whole milk': 1.03,
    'skim milk': 1.03,
    'almond milk': 1.01,
    'oat milk': 1.03,
    'coconut milk': 0.97,
    'buttermilk': 1.03,
    'heavy cream': 0.99,
    'whipping cream': 0.99,
    'sour cream': 0.97,
    'yogurt': 1.03,
    'greek yogurt': 1.06,
    'cream cheese': 0.98,
    'ricotta': 1.04,
    'cottage cheese': 0.96,
    'parmesan': 0.42,
    'grated parmesan': 0.42,
    'cheddar': 0.48,
    'shredded cheese': 0.48,
    'mozzarella': 0.48,
    'feta': 0.63,
    'broth': 1.00,
    'stock': 1.00,
    'wine': 0.99,
    'soy sauce': 1.18,
    'vinegar': 1.01,
    'lemon juice': 1.03,
    'orange juice': 1.05,
    'tomato paste': 1.11,
    'tomato sauce': 1.04,
    'passata': 1.04,

    // Fats & Oils
    'butter': 0.96,
    'unsalted butter': 0.96,
    'salted butter': 0.96,
    'margarine': 0.94,
    'olive oil': 0.91,
    'extra virgin olive oil': 0.91,
    'vegetable oil': 0.92,
    'sunflower oil': 0.92,
    'canola oil': 0.92,
    'coconut oil': 0.92,
    'sesame oil': 0.92,
    'lard': 0.92,
    'shortening': 0.87,
    'mayonnaise': 0.91,
    'peanut butter': 1.09,
    'tahini': 1.06,

    // Flours & Starches
    'all-purpose flour': 0.51,
    'all purpose flour': 0.51,
    'plain flour': 0.51,
    'white flour': 0.51,
    'flour': 0.51,
    'bread flour': 0.54,
    'cake flour': 0.48,
    'pastry flour': 0.48,
    'whole wheat flour': 0.51,
    'self-rising flour': 0.53,
    'almond flour': 0.41,
    'coconut flour': 0.54,
    'rye flour': 0.45,
    'semolina': 0.71,
    'cornmeal': 0.65,
    'polenta': 0.68,
    'cornstarch': 0.54,
    'corn starch': 0.54,
    'potato starch': 0.64,
    'tapioca starch': 0.51,
    'breadcrumbs': 0.46,
    'panko': 0.25,

    // Sugars & Sweeteners
    'granulated white sugar': 0.85,
    'granulated sugar': 0.85,
    'white sugar': 0.85,
    'caster sugar': 0.85,
    'sugar': 0.85,
    'brown sugar': 0.90,
    'dark brown sugar': 0.93,
    'light brown sugar': 0.89,
    'powdered sugar': 0.51,
    'confectioners sugar': 0.51,
    'icing sugar': 0.51,
    'honey': 1.42,
    'maple syrup': 1.33,
    'corn syrup': 1.38,
    'molasses': 1.42,
    'agave': 1.40,

    // Grains, Pasta & Legumes
    'rice': 0.78,
    'white rice': 0.78,
    'basmati rice': 0.76,
    'jasmine rice': 0.78,
    'brown rice': 0.80,
    'arborio rice': 0.85,
    'oats': 0.38,
    'rolled oats': 0.38,
    'quick oats': 0.36,
    'steel cut oats': 0.68,
    'quinoa': 0.72,
    'couscous': 0.73,
    'bulgur': 0.68,
    'lentils': 0.81,
    'chickpeas': 0.72,
    'black beans': 0.74,
    'kidney beans': 0.74,
    'pasta': 0.45,
    'macaroni': 0.48,
    'orzo': 0.76,

    // Baking, Spices & Powders
    'cocoa powder': 0.36,
    'cocoa': 0.36,
    'baking powder': 0.93,
    'baking soda': 0.93,
    'salt': 1.22,
    'table salt': 1.22,
    'kosher salt': 0.72,
    'sea salt': 1.05,
    'yeast': 0.64,
    'cinnamon': 0.53,
    'paprika': 0.48,
    'cumin': 0.45,
    'oregano': 0.20,
    'basil': 0.18,
    'parsley': 0.25,
    'cilantro': 0.17,
    'spinach': 0.13,

    // Nuts, Seeds & Mix-ins
    'almonds': 0.60,
    'sliced almonds': 0.39,
    'walnuts': 0.50,
    'pecans': 0.46,
    'cashews': 0.55,
    'peanuts': 0.61,
    'pistachios': 0.52,
    'hazelnuts': 0.57,
    'chia seeds': 0.68,
    'flaxseed': 0.63,
    'sesame seeds': 0.61,
    'sunflower seeds': 0.59,
    'pumpkin seeds': 0.55,
    'chocolate chips': 0.72,
    'raisins': 0.62,
    'shredded coconut': 0.36,
    'berries': 0.61,
    'blueberries': 0.63,
    'strawberries': 0.64,
    'onion': 0.68,
    'garlic': 0.58,
    'mushrooms': 0.30,
  };

  static String _normalizeKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<void> preloadCache() async {
    await _ensurePrefsLoaded();
  }

  static Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          if (value is num) {
            final density = value.toDouble();
            final localRef = _lookupLocalDensity(key);
            if (_isPlausibleDensity(density, localRef)) {
              _onlineCache[key] = density;
            }
          }
        });
      }
    } catch (_) {
      // Ignore corrupt cache entries and continue gracefully.
    }
  }

  static Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCacheKey, jsonEncode(_onlineCache));
    } catch (_) {
      // Non-critical cache persistence.
    }
  }

  /// Validates that an online density is physically reasonable and, if the
  /// ingredient is a known culinary staple, within ±35% of its physical density.
  static bool _isPlausibleDensity(double density, double? localReference) {
    if (density < 0.12 || density > 2.2) return false;
    if (localReference != null) {
      final ratio = density / localReference;
      if (ratio < 0.65 || ratio > 1.35) return false;
    }
    return true;
  }

  /// Immediate synchronous preview while the prioritized online lookup runs:
  /// checks cached online data first, then the local density table.
  static CupConversionResult convertSync({required String ingredientName, required double grams}) {
    final key = _normalizeKey(ingredientName);
    final localDensity = _lookupLocalDensity(key);
    final cachedDensity = _onlineCache[key];

    if (cachedDensity != null && _isPlausibleDensity(cachedDensity, localDensity)) {
      return _buildResult(grams: grams, gramsPerMl: cachedDensity, source: DensitySource.cached);
    }

    if (localDensity != null) {
      return _buildResult(grams: grams, gramsPerMl: localDensity, source: DensitySource.local);
    }

    return _buildResult(grams: grams, gramsPerMl: 1.0, source: DensitySource.waterEstimate);
  }

  /// Resolves ingredient density in strict priority order:
  /// 1. Online lookup (Open Food Facts median consensus + plausibility check)
  /// 2. Persisted cached online data
  /// 3. Local culinary lookup table
  /// 4. Water density estimate (1.0 g/mL)
  static Future<CupConversionResult> convertAsync({required String ingredientName, required double grams}) async {
    await _ensurePrefsLoaded();
    final key = _normalizeKey(ingredientName);
    final localDensity = _lookupLocalDensity(key);

    // Priority 1: Online conversion lookup
    if (key.isNotEmpty) {
      final onlineDensity = await _fetchOnlineDensityGPerMl(query: key, localReference: localDensity);
      if (onlineDensity != null) {
        _onlineCache[key] = onlineDensity;
        await _persistCache();
        return _buildResult(grams: grams, gramsPerMl: onlineDensity, source: DensitySource.online);
      }
    }

    // Priority 2: Cached online data
    final cachedDensity = _onlineCache[key];
    if (cachedDensity != null && _isPlausibleDensity(cachedDensity, localDensity)) {
      return _buildResult(grams: grams, gramsPerMl: cachedDensity, source: DensitySource.cached);
    }

    // Priority 3: Local culinary density table
    if (localDensity != null) {
      return _buildResult(grams: grams, gramsPerMl: localDensity, source: DensitySource.local);
    }

    // Priority 4: Water estimate fallback
    return _buildResult(grams: grams, gramsPerMl: 1.0, source: DensitySource.waterEstimate);
  }

  static double? _lookupLocalDensity(String normalizedKey) {
    if (normalizedKey.isEmpty) return null;

    final exact = _localDensityGPerMl[normalizedKey];
    if (exact != null) return exact;

    String? bestMatch;
    for (final candidate in _localDensityGPerMl.keys) {
      final pattern = RegExp(r'\b' + RegExp.escape(candidate) + r's?\b');
      if (pattern.hasMatch(normalizedKey)) {
        if (bestMatch == null || candidate.length > bestMatch.length) {
          bestMatch = candidate;
        }
      }
    }

    return bestMatch != null ? _localDensityGPerMl[bestMatch] : null;
  }

  /// Queries Open Food Facts, filters out unrelated packaged snacks/cereals,
  /// validates against culinary bounds, and returns the median density.
  static Future<double?> _fetchOnlineDensityGPerMl({required String query, required double? localReference}) async {
    try {
      final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', <String, String>{
        'search_terms': query,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'fields': 'product_name,generic_name,serving_size',
      });

      final response = await http
          .get(uri, headers: const {'User-Agent': 'CookingMonster/1.2 (Flutter)'})
          .timeout(const Duration(milliseconds: 2800));

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final products = body['products'];
      if (products is! List) return null;

      final queryTokens = query.split(' ').where((t) => t.length >= 3).toSet();

      final candidates = <double>[];

      for (final item in products) {
        if (item is! Map<String, dynamic>) continue;

        final productName = '${item['product_name'] ?? ''} ${item['generic_name'] ?? ''}'.toLowerCase();
        if (productName.trim().isEmpty) continue;

        final productTokens = productName
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toSet();

        // Skip processed snack/bakery items that distort raw ingredient density
        if (productTokens.intersection(_excludedProductTokens).isNotEmpty) {
          continue;
        }

        // Require at least one meaningful query token in the product title
        if (queryTokens.isNotEmpty && productTokens.intersection(queryTokens).isEmpty) {
          continue;
        }

        final servingSize = item['serving_size']?.toString() ?? '';
        final parsed = _extractDensityFromServingString(servingSize);
        if (parsed != null && _isPlausibleDensity(parsed, localReference)) {
          candidates.add(parsed);
        }
      }

      if (candidates.isEmpty) return null;

      candidates.sort();
      final mid = candidates.length ~/ 2;
      if (candidates.length.isOdd) {
        return candidates[mid];
      }
      return (candidates[mid - 1] + candidates[mid]) / 2.0;
    } catch (_) {
      // Offline, timeout, or DNS failure -> proceed to cached / local fallback.
    }
    return null;
  }

  static double? _parseNumberOrFraction(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length == 2) {
        final numPart = double.tryParse(parts[0].trim());
        final denPart = double.tryParse(parts[1].trim());
        if (numPart != null && denPart != null && denPart > 0) {
          return numPart / denPart;
        }
      }
      return null;
    }
    return double.tryParse(cleaned);
  }

  /// Parses Open Food Facts `serving_size` strings such as:
  /// "200 g (1 cup)", "1/4 cup (50g)", "1 tbsp (15 g)", "1 tsp (5g)",
  /// or "240 ml (248 g)".
  static double? _extractDensityFromServingString(String raw) {
    if (raw.trim().isEmpty) return null;
    final lower = raw.toLowerCase();

    final gramMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b').firstMatch(lower);
    if (gramMatch == null) return null;
    final grams = double.tryParse(gramMatch.group(1)!.replaceAll(',', '.'));
    if (grams == null || grams <= 0) return null;

    const numToken = r'(\d+\s*/\s*\d+|\d+(?:[.,]\d+)?)';

    // Cups
    final cupMatch = RegExp('$numToken\\s*cups?\\b').firstMatch(lower);
    if (cupMatch != null) {
      final cups = _parseNumberOrFraction(cupMatch.group(1)!);
      if (cups != null && cups > 0) {
        final density = grams / (cups * _usCupInMl);
        if (density >= 0.12 && density <= 2.2) return density;
      }
    }

    // Tablespoons
    final tbspMatch = RegExp('$numToken\\s*(?:tbsp|tbs|tablespoons?)\\b').firstMatch(lower);
    if (tbspMatch != null) {
      final tbsp = _parseNumberOrFraction(tbspMatch.group(1)!);
      if (tbsp != null && tbsp > 0) {
        final ml = (tbsp / 16.0) * _usCupInMl;
        final density = grams / ml;
        if (density >= 0.12 && density <= 2.2) return density;
      }
    }

    // Teaspoons
    final tspMatch = RegExp('$numToken\\s*(?:tsp|teaspoons?)\\b').firstMatch(lower);
    if (tspMatch != null) {
      final tsp = _parseNumberOrFraction(tspMatch.group(1)!);
      if (tsp != null && tsp > 0) {
        final ml = (tsp / 48.0) * _usCupInMl;
        final density = grams / ml;
        if (density >= 0.12 && density <= 2.2) return density;
      }
    }

    // Milliliters
    final mlMatch = RegExp('$numToken\\s*ml\\b').firstMatch(lower);
    if (mlMatch != null) {
      final ml = _parseNumberOrFraction(mlMatch.group(1)!);
      if (ml != null && ml > 0) {
        final density = grams / ml;
        if (density >= 0.12 && density <= 2.2) return density;
      }
    }

    // Fluid ounces
    final flOzMatch = RegExp('$numToken\\s*(?:fl\\.?\\s*oz)\\b').firstMatch(lower);
    if (flOzMatch != null) {
      final flOz = _parseNumberOrFraction(flOzMatch.group(1)!);
      if (flOz != null && flOz > 0) {
        final density = grams / (flOz * _usFlOzInMl);
        if (density >= 0.12 && density <= 2.2) return density;
      }
    }

    return null;
  }

  static CupConversionResult _buildResult({
    required double grams,
    required double gramsPerMl,
    required DensitySource source,
  }) {
    final milliliters = grams / gramsPerMl;

    // Convert milliliters to US cups via `units_converter`
    final usCups = milliliters.convertFromTo(VOLUME.milliliters, VOLUME.usCups) ?? (milliliters / _usCupInMl);
    final usTablespoons = usCups * 16.0;
    final usTeaspoons = usCups * 48.0;
    final gramsPerCup = gramsPerMl * _usCupInMl;

    return CupConversionResult(
      grams: grams,
      usCups: usCups,
      usTablespoons: usTablespoons,
      usTeaspoons: usTeaspoons,
      gramsPerCup: gramsPerCup,
      formattedVolume: formatCulinaryVolume(usCups: usCups, usTablespoons: usTablespoons, usTeaspoons: usTeaspoons),
      source: source,
    );
  }

  /// Formats volume into:
  /// - **Teaspoons (`tsp`)** for tiny amounts (< ~1 tbsp)
  /// - **Tablespoons (`tbsp`)** for small amounts (1 tbsp up to < 1/4 cup)
  /// - **Cups (`cup` / `cups`)** at 1/4 cup and above
  static String formatCulinaryVolume({
    required double usCups,
    required double usTablespoons,
    required double usTeaspoons,
  }) {
    if (usCups <= 0) return '0 tsp';

    // 1. Smallest measurements -> Teaspoons (under ~1 tbsp)
    if (usTablespoons < 0.9) {
      if (usTeaspoons < 0.09) {
        return '< ⅛ tsp';
      }
      final formattedTsp = _formatWithFractions(
        value: usTeaspoons,
        fractions: const [
          MapEntry(0.0, ''),
          MapEntry(0.125, '⅛'),
          MapEntry(0.25, '¼'),
          MapEntry(0.3333, '⅓'),
          MapEntry(0.5, '½'),
          MapEntry(0.6667, '⅔'),
          MapEntry(0.75, '¾'),
          MapEntry(1.0, '1'),
        ],
        tolerance: 0.055,
      );
      return '$formattedTsp tsp';
    }

    // 2. Small measurements -> Tablespoons (1 tbsp up to just below 1/4 cup)
    if (usCups < 0.235) {
      final formattedTbsp = _formatWithFractions(
        value: usTablespoons,
        fractions: const [
          MapEntry(0.0, ''),
          MapEntry(0.25, '¼'),
          MapEntry(0.3333, '⅓'),
          MapEntry(0.5, '½'),
          MapEntry(0.6667, '⅔'),
          MapEntry(0.75, '¾'),
          MapEntry(1.0, '1'),
        ],
        tolerance: 0.055,
      );
      return '$formattedTbsp tbsp';
    }

    // 3. Standard & large measurements -> Cups (1/4 cup and above)
    final formattedCups = _formatWithFractions(
      value: usCups,
      fractions: const [
        MapEntry(0.0, ''),
        MapEntry(0.25, '¼'),
        MapEntry(0.3333, '⅓'),
        MapEntry(0.5, '½'),
        MapEntry(0.6667, '⅔'),
        MapEntry(0.75, '¾'),
        MapEntry(1.0, '1'),
      ],
      tolerance: 0.035,
    );

    final isSingular = formattedCups == '1' || const {'¼', '⅓', '½', '⅔', '¾'}.contains(formattedCups);
    return isSingular ? '$formattedCups cup' : '$formattedCups cups';
  }

  static String _formatWithFractions({
    required double value,
    required List<MapEntry<double, String>> fractions,
    required double tolerance,
  }) {
    final whole = value.floor();
    final remainder = value - whole;

    MapEntry<double, String>? closest;
    double bestDiff = double.infinity;
    for (final entry in fractions) {
      final diff = (remainder - entry.key).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = entry;
      }
    }

    if (closest != null && bestDiff <= tolerance) {
      int displayWhole = whole;
      String fracGlyph = closest.value;
      if (fracGlyph == '1') {
        displayWhole += 1;
        fracGlyph = '';
      }

      if (displayWhole > 0) {
        return fracGlyph.isNotEmpty ? '$displayWhole $fracGlyph' : '$displayWhole';
      }
      if (fracGlyph.isNotEmpty) {
        return fracGlyph;
      }
    }

    return value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
