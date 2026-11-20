enum IngredientUnit { grams, count }

class Ingredient {
  final String name;
  final double amount;
  final IngredientUnit unit;
  final String? note;

  const Ingredient({required this.name, required this.amount, this.unit = IngredientUnit.grams, this.note});

  String get formattedAmount {
    final numeric = amount % 1 == 0 ? amount.toInt().toString() : amount.toString();
    if (unit == IngredientUnit.count) {
      return amount == 1 ? '1 pc' : '$numeric pcs';
    }
    return '$numeric g';
  }

  Map<String, dynamic> toCompactJson() => {
    'n': name,
    'g': amount % 1 == 0 ? amount.toInt() : amount,
    if (unit == IngredientUnit.count) 'u': 'c',
    if (note != null && note!.isNotEmpty) 'm': note,
  };

  factory Ingredient.fromCompactJson(Map<String, dynamic> json) => Ingredient(
    name: json['n'] as String,
    amount: (json['g'] as num).toDouble(),
    unit: json['u'] == 'c' ? IngredientUnit.count : IngredientUnit.grams,
    note: json['m'] as String?,
  );
}

class Recipe {
  final String id;
  final String title;
  final String createdBy;
  final int portions;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final int timesMade;
  final Set<int> checkedIngredients;
  final Set<int> completedSteps;

  const Recipe({
    required this.id,
    required this.title,
    this.createdBy = '',
    this.portions = 1,
    required this.ingredients,
    required this.steps,
    this.timesMade = 0,
    this.checkedIngredients = const {},
    this.completedSteps = const {},
  });

  String get displayTitleWithAuthor => createdBy.isNotEmpty ? '$title created by @$createdBy' : title;

  String get timesMadeLabel => timesMade == 1 ? 'Made 1 time' : 'Made $timesMade times';

  bool get hasInProgressChecklist => checkedIngredients.isNotEmpty || completedSteps.isNotEmpty;

  int get totalChecklistItems => ingredients.length + steps.length;

  int get completedChecklistItems => checkedIngredients.length + completedSteps.length;

  Recipe copyWith({
    String? id,
    String? title,
    String? createdBy,
    int? portions,
    List<Ingredient>? ingredients,
    List<String>? steps,
    int? timesMade,
    Set<int>? checkedIngredients,
    Set<int>? completedSteps,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      portions: portions ?? this.portions,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      timesMade: timesMade ?? this.timesMade,
      checkedIngredients: checkedIngredients ?? this.checkedIngredients,
      completedSteps: completedSteps ?? this.completedSteps,
    );
  }

  Map<String, dynamic> toCompactJson({bool includeLocalState = true}) => {
    't': title,
    if (createdBy.isNotEmpty) 'c': createdBy,
    'p': portions,
    'i': ingredients.map((e) => e.toCompactJson()).toList(),
    's': steps,
    if (includeLocalState && timesMade > 0) 'tm': timesMade,
    if (includeLocalState && checkedIngredients.isNotEmpty) 'ci': (checkedIngredients.toList()..sort()),
    if (includeLocalState && completedSteps.isNotEmpty) 'cs': (completedSteps.toList()..sort()),
  };

  factory Recipe.fromCompactJson(String id, Map<String, dynamic> json) {
    final rawAuthor = (json['c'] as String? ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final sanitizedAuthor = rawAuthor.length > 64 ? rawAuthor.substring(0, 64) : rawAuthor;

    final parsedIngredients = (json['i'] as List)
        .map((e) => Ingredient.fromCompactJson(e as Map<String, dynamic>))
        .toList();
    final parsedSteps = List<String>.from(json['s'] as List);

    final rawTimesMade = (json['tm'] as num?)?.toInt() ?? 0;
    final sanitizedTimesMade = rawTimesMade < 0 ? 0 : rawTimesMade;

    final checkedIng = <int>{};
    final rawCheckedIng = json['ci'];
    if (rawCheckedIng is List) {
      for (final item in rawCheckedIng) {
        if (item is int && item >= 0 && item < parsedIngredients.length) {
          checkedIng.add(item);
        }
      }
    }

    final completedStp = <int>{};
    final rawCompletedStp = json['cs'];
    if (rawCompletedStp is List) {
      for (final item in rawCompletedStp) {
        if (item is int && item >= 0 && item < parsedSteps.length) {
          completedStp.add(item);
        }
      }
    }

    return Recipe(
      id: id,
      title: json['t'] as String,
      createdBy: sanitizedAuthor,
      portions: (json['p'] as num?)?.toInt() ?? 1,
      ingredients: parsedIngredients,
      steps: parsedSteps,
      timesMade: sanitizedTimesMade,
      checkedIngredients: checkedIng,
      completedSteps: completedStp,
    );
  }
}
