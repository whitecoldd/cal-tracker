import 'package:drift/drift.dart';

import '../domain/day.dart';
import '../domain/energy.dart';
import '../domain/portion.dart';

/// Stores a [Day] as its `yyyymmdd` integer. See [Day] for why days are not
/// `DateTime`.
class DayConverter extends TypeConverter<Day, int> {
  const DayConverter();

  @override
  Day fromSql(int fromDb) => Day(fromDb);

  @override
  int toSql(Day value) => value.value;
}

/// Where a food's numbers came from, worst to best.
///
/// Kept so a low-confidence AI guess can later be upgraded by a barcode scan
/// without silently overwriting something the user corrected by hand.
enum FoodSource {
  /// Estimated by the model. Cheapest to produce, least trustworthy.
  ai,

  /// Bundled seed table of common whole foods.
  seed,

  /// Open Food Facts, usually via barcode.
  openFoodFacts,

  /// Typed or corrected by the user. Always wins.
  manual,
}

/// Which meal an entry belongs to.
enum MealSlot { breakfast, lunch, dinner, snack }

/// How an activity day was measured.
enum ActivitySource { healthConnect, manual }

/// What an AI call was for. Every call is attributed so the daily budget is
/// explainable rather than just a number.
/// What an AI call was spent on.
///
/// Stored by name, so a value may be added but never renamed or reordered
/// without a migration — `ai_calls` holds the history the Settings budget is
/// counted from.
enum AiPurpose {
  parseText,
  estimatePortion,
  parsePhoto,
  weeklyNarrative,

  /// Reading the nutrition table printed on a package. See CLAUDE.md §4.
  readLabel,
}

/// The user. Single-row in practice, but a table keeps migrations uniform.
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Only used to pick a Mifflin-St Jeor constant. See [Sex].
  TextColumn get sex => textEnum<Sex>()();
  IntColumn get birthYear => integer()();
  RealColumn get heightCm => real()();

  /// Fallback for days with no step data; measured movement wins when present.
  TextColumn get activityLevel => textEnum<ActivityLevel>()();

  TextColumn get goal => textEnum<Goal>()();

  /// Target weight in kg. Null means "no target, just report".
  RealColumn get targetWeightKg => real().nullable()();

  /// ISO weekday the week closes on and the verdict is revealed.
  /// Monday is 1, Sunday is 7.
  IntColumn get weekEndsOn => integer().withDefault(const Constant(DateTime.sunday))();

  /// Used to turn steps into distance. Seeded from height, then editable.
  RealColumn get strideCm => real().withDefault(const Constant(72))();

  IntColumn get dailyStepGoal => integer().withDefault(const Constant(10000))();

  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

/// The canonical food library, and the reason the AI budget is survivable.
///
/// Anything ever resolved — from the seed table, Open Food Facts, the model, or
/// the user's own typing — is written here permanently, so a given food costs
/// at most one network call in its lifetime.
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().nullable()();

  /// Lowercased name + brand, for cheap local lookup before any network call.
  TextColumn get searchKey => text()();

  // --- per 100g (or 100ml for liquids) ---
  RealColumn get kcal => real()();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  RealColumn get sugarG => real().withDefault(const Constant(0))();

  /// Free sugars, which is what the WHO limit is about. Often unknown for
  /// whole foods, where it is legitimately zero.
  RealColumn get addedSugarG => real().nullable()();

  RealColumn get fatG => real().withDefault(const Constant(0))();
  RealColumn get satFatG => real().withDefault(const Constant(0))();
  RealColumn get transFatG => real().nullable()();
  RealColumn get fibreG => real().withDefault(const Constant(0))();
  RealColumn get sodiumMg => real().withDefault(const Constant(0))();
  RealColumn get alcoholG => real().withDefault(const Constant(0))();

  /// Glycemic index. Null where the food has too little carbohydrate for the
  /// measure to mean anything — which is not the same as a GI of zero.
  IntColumn get glycemicIndex => integer().nullable()();

  /// NOVA processing group, 1 (unprocessed) to 4 (ultra-processed).
  IntColumn get novaGroup => integer().nullable()();

  /// JSON array of additive tags, e.g. `["en:e150d","en:e338"]`.
  TextColumn get additivesJson => text().nullable()();

  /// Grams in one natural unit ("1 egg", "1 slice"), when there is one.
  RealColumn get gramsPerPiece => real().nullable()();
  TextColumn get pieceName => text().nullable()();

  TextColumn get source => textEnum<FoodSource>()();

  /// 0..1. How much to trust these numbers; drives whether a better source is
  /// allowed to overwrite them.
  RealColumn get confidence => real().withDefault(const Constant(1))();

  TextColumn get imagePath => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {barcode},
      ];
}

/// One logged item of food.
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodId => integer().references(Foods, #id)();

  IntColumn get day => integer().map(const DayConverter())();
  TextColumn get mealSlot => textEnum<MealSlot>()();

  /// What the user said: "2", "a handful", "half a plate".
  RealColumn get quantity => real()();
  TextColumn get unit => textEnum<PortionUnit>()();

  /// The quantity resolved to grams. This is what every calculation uses.
  RealColumn get grams => real()();

  /// The original phrasing, kept so a bad parse can be re-resolved later and so
  /// the Journal reads like a journal rather than a spreadsheet.
  TextColumn get rawText => text().nullable()();

  TextColumn get photoPath => text().nullable()();

  /// 0..1 confidence in the portion resolution specifically.
  RealColumn get confidence => real().withDefault(const Constant(1))();

  TextColumn get createdAt => text()();
}

/// Steps and distance for one day.
class ActivityDays extends Table {
  IntColumn get day => integer().map(const DayConverter())();
  IntColumn get steps => integer().withDefault(const Constant(0))();
  RealColumn get distanceM => real().withDefault(const Constant(0))();

  /// Active energy, when the platform reports it.
  RealColumn get activeKcal => real().nullable()();

  TextColumn get source => textEnum<ActivitySource>()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {day};

  // Without this, SQLite treats a lone INTEGER PRIMARY KEY as an alias for
  // rowid, drift makes it optional in inserts, and a row written without a day
  // would silently be assigned one. These tables are keyed by day; the day is
  // never optional.
  @override
  bool get withoutRowId => true;
}

/// A weigh-in.
///
/// There is deliberately no trend column. Trend is derived at read time and
/// returned as a `SealedValue`, so there is nowhere for a leaked verdict to be
/// stored. See CLAUDE.md §1.
class Weights extends Table {
  IntColumn get day => integer().map(const DayConverter())();
  RealColumn get kg => real()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {day};

  // Without this, SQLite treats a lone INTEGER PRIMARY KEY as an alias for
  // rowid, drift makes it optional in inserts, and a row written without a day
  // would silently be assigned one. These tables are keyed by day; the day is
  // never optional.
  @override
  bool get withoutRowId => true;
}

/// Water intake, which feeds the Yrden sign.
class WaterLogs extends Table {
  IntColumn get day => integer().map(const DayConverter())();
  IntColumn get ml => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {day};

  // Without this, SQLite treats a lone INTEGER PRIMARY KEY as an alias for
  // rowid, drift makes it optional in inserts, and a row written without a day
  // would silently be assigned one. These tables are keyed by day; the day is
  // never optional.
  @override
  bool get withoutRowId => true;
}

/// A closed week.
///
/// Append-only history: once revealed, the summary is frozen, so past weeks stay
/// readable without recomputation and a later change to the scoring maths cannot
/// rewrite what already happened.
class Weeks extends Table {
  IntColumn get weekStart => integer().map(const DayConverter())();
  IntColumn get weekEnd => integer().map(const DayConverter())();

  BoolColumn get revealed => boolean().withDefault(const Constant(false))();

  /// Frozen snapshot of everything the reveal screen shows.
  TextColumn get summaryJson => text().nullable()();

  /// The single AI-written account of the week.
  TextColumn get narrative => text().nullable()();

  IntColumn get xpAwarded => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {weekStart};

  // Without this, SQLite treats a lone INTEGER PRIMARY KEY as an alias for
  // rowid, drift makes it optional in inserts, and a row written without a day
  // would silently be assigned one. These tables are keyed by day; the day is
  // never optional.
  @override
  bool get withoutRowId => true;
}

/// Audit trail and daily budget counter for OpenRouter.
///
/// The free tier allows 50 requests a day, so every call is recorded and the
/// count is shown in Settings rather than discovered by a sudden failure.
class AiCalls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get day => integer().map(const DayConverter())();

  /// Full timestamp, for the 20-requests-per-minute limit.
  TextColumn get at => text()();

  TextColumn get model => text()();
  TextColumn get purpose => textEnum<AiPurpose>()();
  BoolColumn get succeeded => boolean()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  TextColumn get error => text().nullable()();
}

/// An unlocked mutagen or perk.
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable identifier for the achievement definition.
  TextColumn get code => text()();

  /// The week that earned it, if it was a weekly award.
  IntColumn get weekStart => integer().map(const DayConverter()).nullable()();

  TextColumn get unlockedAt => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {code, weekStart},
      ];
}
