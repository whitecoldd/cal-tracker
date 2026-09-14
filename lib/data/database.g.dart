// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Sex, String> sex =
      GeneratedColumn<String>(
        'sex',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Sex>($ProfilesTable.$convertersex);
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ActivityLevel, String>
  activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ActivityLevel>($ProfilesTable.$converteractivityLevel);
  @override
  late final GeneratedColumnWithTypeConverter<Goal, String> goal =
      GeneratedColumn<String>(
        'goal',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Goal>($ProfilesTable.$convertergoal);
  static const VerificationMeta _targetWeightKgMeta = const VerificationMeta(
    'targetWeightKg',
  );
  @override
  late final GeneratedColumn<double> targetWeightKg = GeneratedColumn<double>(
    'target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekEndsOnMeta = const VerificationMeta(
    'weekEndsOn',
  );
  @override
  late final GeneratedColumn<int> weekEndsOn = GeneratedColumn<int>(
    'week_ends_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(DateTime.sunday),
  );
  static const VerificationMeta _strideCmMeta = const VerificationMeta(
    'strideCm',
  );
  @override
  late final GeneratedColumn<double> strideCm = GeneratedColumn<double>(
    'stride_cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(72),
  );
  static const VerificationMeta _dailyStepGoalMeta = const VerificationMeta(
    'dailyStepGoal',
  );
  @override
  late final GeneratedColumn<int> dailyStepGoal = GeneratedColumn<int>(
    'daily_step_goal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10000),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sex,
    birthYear,
    heightCm,
    activityLevel,
    goal,
    targetWeightKg,
    weekEndsOn,
    strideCm,
    dailyStepGoal,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    } else if (isInserting) {
      context.missing(_birthYearMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    } else if (isInserting) {
      context.missing(_heightCmMeta);
    }
    if (data.containsKey('target_weight_kg')) {
      context.handle(
        _targetWeightKgMeta,
        targetWeightKg.isAcceptableOrUnknown(
          data['target_weight_kg']!,
          _targetWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('week_ends_on')) {
      context.handle(
        _weekEndsOnMeta,
        weekEndsOn.isAcceptableOrUnknown(
          data['week_ends_on']!,
          _weekEndsOnMeta,
        ),
      );
    }
    if (data.containsKey('stride_cm')) {
      context.handle(
        _strideCmMeta,
        strideCm.isAcceptableOrUnknown(data['stride_cm']!, _strideCmMeta),
      );
    }
    if (data.containsKey('daily_step_goal')) {
      context.handle(
        _dailyStepGoalMeta,
        dailyStepGoal.isAcceptableOrUnknown(
          data['daily_step_goal']!,
          _dailyStepGoalMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sex: $ProfilesTable.$convertersex.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sex'],
        )!,
      ),
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      )!,
      activityLevel: $ProfilesTable.$converteractivityLevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}activity_level'],
        )!,
      ),
      goal: $ProfilesTable.$convertergoal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}goal'],
        )!,
      ),
      targetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight_kg'],
      ),
      weekEndsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_ends_on'],
      )!,
      strideCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stride_cm'],
      )!,
      dailyStepGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_step_goal'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Sex, String, String> $convertersex =
      const EnumNameConverter<Sex>(Sex.values);
  static JsonTypeConverter2<ActivityLevel, String, String>
  $converteractivityLevel = const EnumNameConverter<ActivityLevel>(
    ActivityLevel.values,
  );
  static JsonTypeConverter2<Goal, String, String> $convertergoal =
      const EnumNameConverter<Goal>(Goal.values);
}

class Profile extends DataClass implements Insertable<Profile> {
  final int id;

  /// Only used to pick a Mifflin-St Jeor constant. See [Sex].
  final Sex sex;
  final int birthYear;
  final double heightCm;

  /// Fallback for days with no step data; measured movement wins when present.
  final ActivityLevel activityLevel;
  final Goal goal;

  /// Target weight in kg. Null means "no target, just report".
  final double? targetWeightKg;

  /// ISO weekday the week closes on and the verdict is revealed.
  /// Monday is 1, Sunday is 7.
  final int weekEndsOn;

  /// Used to turn steps into distance. Seeded from height, then editable.
  final double strideCm;
  final int dailyStepGoal;
  final String createdAt;
  final String updatedAt;
  const Profile({
    required this.id,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.activityLevel,
    required this.goal,
    this.targetWeightKg,
    required this.weekEndsOn,
    required this.strideCm,
    required this.dailyStepGoal,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['sex'] = Variable<String>($ProfilesTable.$convertersex.toSql(sex));
    }
    map['birth_year'] = Variable<int>(birthYear);
    map['height_cm'] = Variable<double>(heightCm);
    {
      map['activity_level'] = Variable<String>(
        $ProfilesTable.$converteractivityLevel.toSql(activityLevel),
      );
    }
    {
      map['goal'] = Variable<String>($ProfilesTable.$convertergoal.toSql(goal));
    }
    if (!nullToAbsent || targetWeightKg != null) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg);
    }
    map['week_ends_on'] = Variable<int>(weekEndsOn);
    map['stride_cm'] = Variable<double>(strideCm);
    map['daily_step_goal'] = Variable<int>(dailyStepGoal);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      sex: Value(sex),
      birthYear: Value(birthYear),
      heightCm: Value(heightCm),
      activityLevel: Value(activityLevel),
      goal: Value(goal),
      targetWeightKg: targetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetWeightKg),
      weekEndsOn: Value(weekEndsOn),
      strideCm: Value(strideCm),
      dailyStepGoal: Value(dailyStepGoal),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<int>(json['id']),
      sex: $ProfilesTable.$convertersex.fromJson(
        serializer.fromJson<String>(json['sex']),
      ),
      birthYear: serializer.fromJson<int>(json['birthYear']),
      heightCm: serializer.fromJson<double>(json['heightCm']),
      activityLevel: $ProfilesTable.$converteractivityLevel.fromJson(
        serializer.fromJson<String>(json['activityLevel']),
      ),
      goal: $ProfilesTable.$convertergoal.fromJson(
        serializer.fromJson<String>(json['goal']),
      ),
      targetWeightKg: serializer.fromJson<double?>(json['targetWeightKg']),
      weekEndsOn: serializer.fromJson<int>(json['weekEndsOn']),
      strideCm: serializer.fromJson<double>(json['strideCm']),
      dailyStepGoal: serializer.fromJson<int>(json['dailyStepGoal']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sex': serializer.toJson<String>(
        $ProfilesTable.$convertersex.toJson(sex),
      ),
      'birthYear': serializer.toJson<int>(birthYear),
      'heightCm': serializer.toJson<double>(heightCm),
      'activityLevel': serializer.toJson<String>(
        $ProfilesTable.$converteractivityLevel.toJson(activityLevel),
      ),
      'goal': serializer.toJson<String>(
        $ProfilesTable.$convertergoal.toJson(goal),
      ),
      'targetWeightKg': serializer.toJson<double?>(targetWeightKg),
      'weekEndsOn': serializer.toJson<int>(weekEndsOn),
      'strideCm': serializer.toJson<double>(strideCm),
      'dailyStepGoal': serializer.toJson<int>(dailyStepGoal),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Profile copyWith({
    int? id,
    Sex? sex,
    int? birthYear,
    double? heightCm,
    ActivityLevel? activityLevel,
    Goal? goal,
    Value<double?> targetWeightKg = const Value.absent(),
    int? weekEndsOn,
    double? strideCm,
    int? dailyStepGoal,
    String? createdAt,
    String? updatedAt,
  }) => Profile(
    id: id ?? this.id,
    sex: sex ?? this.sex,
    birthYear: birthYear ?? this.birthYear,
    heightCm: heightCm ?? this.heightCm,
    activityLevel: activityLevel ?? this.activityLevel,
    goal: goal ?? this.goal,
    targetWeightKg: targetWeightKg.present
        ? targetWeightKg.value
        : this.targetWeightKg,
    weekEndsOn: weekEndsOn ?? this.weekEndsOn,
    strideCm: strideCm ?? this.strideCm,
    dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      goal: data.goal.present ? data.goal.value : this.goal,
      targetWeightKg: data.targetWeightKg.present
          ? data.targetWeightKg.value
          : this.targetWeightKg,
      weekEndsOn: data.weekEndsOn.present
          ? data.weekEndsOn.value
          : this.weekEndsOn,
      strideCm: data.strideCm.present ? data.strideCm.value : this.strideCm,
      dailyStepGoal: data.dailyStepGoal.present
          ? data.dailyStepGoal.value
          : this.dailyStepGoal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthYear: $birthYear, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goal: $goal, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('weekEndsOn: $weekEndsOn, ')
          ..write('strideCm: $strideCm, ')
          ..write('dailyStepGoal: $dailyStepGoal, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sex,
    birthYear,
    heightCm,
    activityLevel,
    goal,
    targetWeightKg,
    weekEndsOn,
    strideCm,
    dailyStepGoal,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.sex == this.sex &&
          other.birthYear == this.birthYear &&
          other.heightCm == this.heightCm &&
          other.activityLevel == this.activityLevel &&
          other.goal == this.goal &&
          other.targetWeightKg == this.targetWeightKg &&
          other.weekEndsOn == this.weekEndsOn &&
          other.strideCm == this.strideCm &&
          other.dailyStepGoal == this.dailyStepGoal &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<int> id;
  final Value<Sex> sex;
  final Value<int> birthYear;
  final Value<double> heightCm;
  final Value<ActivityLevel> activityLevel;
  final Value<Goal> goal;
  final Value<double?> targetWeightKg;
  final Value<int> weekEndsOn;
  final Value<double> strideCm;
  final Value<int> dailyStepGoal;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goal = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.weekEndsOn = const Value.absent(),
    this.strideCm = const Value.absent(),
    this.dailyStepGoal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required Sex sex,
    required int birthYear,
    required double heightCm,
    required ActivityLevel activityLevel,
    required Goal goal,
    this.targetWeightKg = const Value.absent(),
    this.weekEndsOn = const Value.absent(),
    this.strideCm = const Value.absent(),
    this.dailyStepGoal = const Value.absent(),
    required String createdAt,
    required String updatedAt,
  }) : sex = Value(sex),
       birthYear = Value(birthYear),
       heightCm = Value(heightCm),
       activityLevel = Value(activityLevel),
       goal = Value(goal),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Profile> custom({
    Expression<int>? id,
    Expression<String>? sex,
    Expression<int>? birthYear,
    Expression<double>? heightCm,
    Expression<String>? activityLevel,
    Expression<String>? goal,
    Expression<double>? targetWeightKg,
    Expression<int>? weekEndsOn,
    Expression<double>? strideCm,
    Expression<int>? dailyStepGoal,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sex != null) 'sex': sex,
      if (birthYear != null) 'birth_year': birthYear,
      if (heightCm != null) 'height_cm': heightCm,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (goal != null) 'goal': goal,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (weekEndsOn != null) 'week_ends_on': weekEndsOn,
      if (strideCm != null) 'stride_cm': strideCm,
      if (dailyStepGoal != null) 'daily_step_goal': dailyStepGoal,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<Sex>? sex,
    Value<int>? birthYear,
    Value<double>? heightCm,
    Value<ActivityLevel>? activityLevel,
    Value<Goal>? goal,
    Value<double?>? targetWeightKg,
    Value<int>? weekEndsOn,
    Value<double>? strideCm,
    Value<int>? dailyStepGoal,
    Value<String>? createdAt,
    Value<String>? updatedAt,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      weekEndsOn: weekEndsOn ?? this.weekEndsOn,
      strideCm: strideCm ?? this.strideCm,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(
        $ProfilesTable.$convertersex.toSql(sex.value),
      );
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(
        $ProfilesTable.$converteractivityLevel.toSql(activityLevel.value),
      );
    }
    if (goal.present) {
      map['goal'] = Variable<String>(
        $ProfilesTable.$convertergoal.toSql(goal.value),
      );
    }
    if (targetWeightKg.present) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg.value);
    }
    if (weekEndsOn.present) {
      map['week_ends_on'] = Variable<int>(weekEndsOn.value);
    }
    if (strideCm.present) {
      map['stride_cm'] = Variable<double>(strideCm.value);
    }
    if (dailyStepGoal.present) {
      map['daily_step_goal'] = Variable<int>(dailyStepGoal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthYear: $birthYear, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goal: $goal, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('weekEndsOn: $weekEndsOn, ')
          ..write('strideCm: $strideCm, ')
          ..write('dailyStepGoal: $dailyStepGoal, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FoodsTable extends Foods with TableInfo<$FoodsTable, Food> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchKeyMeta = const VerificationMeta(
    'searchKey',
  );
  @override
  late final GeneratedColumn<String> searchKey = GeneratedColumn<String>(
    'search_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
    'carbs_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sugarGMeta = const VerificationMeta('sugarG');
  @override
  late final GeneratedColumn<double> sugarG = GeneratedColumn<double>(
    'sugar_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedSugarGMeta = const VerificationMeta(
    'addedSugarG',
  );
  @override
  late final GeneratedColumn<double> addedSugarG = GeneratedColumn<double>(
    'added_sugar_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _satFatGMeta = const VerificationMeta(
    'satFatG',
  );
  @override
  late final GeneratedColumn<double> satFatG = GeneratedColumn<double>(
    'sat_fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _transFatGMeta = const VerificationMeta(
    'transFatG',
  );
  @override
  late final GeneratedColumn<double> transFatG = GeneratedColumn<double>(
    'trans_fat_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fibreGMeta = const VerificationMeta('fibreG');
  @override
  late final GeneratedColumn<double> fibreG = GeneratedColumn<double>(
    'fibre_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<double> sodiumMg = GeneratedColumn<double>(
    'sodium_mg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _alcoholGMeta = const VerificationMeta(
    'alcoholG',
  );
  @override
  late final GeneratedColumn<double> alcoholG = GeneratedColumn<double>(
    'alcohol_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _glycemicIndexMeta = const VerificationMeta(
    'glycemicIndex',
  );
  @override
  late final GeneratedColumn<int> glycemicIndex = GeneratedColumn<int>(
    'glycemic_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _novaGroupMeta = const VerificationMeta(
    'novaGroup',
  );
  @override
  late final GeneratedColumn<int> novaGroup = GeneratedColumn<int>(
    'nova_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _additivesJsonMeta = const VerificationMeta(
    'additivesJson',
  );
  @override
  late final GeneratedColumn<String> additivesJson = GeneratedColumn<String>(
    'additives_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gramsPerPieceMeta = const VerificationMeta(
    'gramsPerPiece',
  );
  @override
  late final GeneratedColumn<double> gramsPerPiece = GeneratedColumn<double>(
    'grams_per_piece',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pieceNameMeta = const VerificationMeta(
    'pieceName',
  );
  @override
  late final GeneratedColumn<String> pieceName = GeneratedColumn<String>(
    'piece_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FoodSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FoodSource>($FoodsTable.$convertersource);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    brand,
    barcode,
    searchKey,
    kcal,
    proteinG,
    carbsG,
    sugarG,
    addedSugarG,
    fatG,
    satFatG,
    transFatG,
    fibreG,
    sodiumMg,
    alcoholG,
    glycemicIndex,
    novaGroup,
    additivesJson,
    gramsPerPiece,
    pieceName,
    source,
    confidence,
    imagePath,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<Food> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('search_key')) {
      context.handle(
        _searchKeyMeta,
        searchKey.isAcceptableOrUnknown(data['search_key']!, _searchKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_searchKeyMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    }
    if (data.containsKey('carbs_g')) {
      context.handle(
        _carbsGMeta,
        carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta),
      );
    }
    if (data.containsKey('sugar_g')) {
      context.handle(
        _sugarGMeta,
        sugarG.isAcceptableOrUnknown(data['sugar_g']!, _sugarGMeta),
      );
    }
    if (data.containsKey('added_sugar_g')) {
      context.handle(
        _addedSugarGMeta,
        addedSugarG.isAcceptableOrUnknown(
          data['added_sugar_g']!,
          _addedSugarGMeta,
        ),
      );
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    }
    if (data.containsKey('sat_fat_g')) {
      context.handle(
        _satFatGMeta,
        satFatG.isAcceptableOrUnknown(data['sat_fat_g']!, _satFatGMeta),
      );
    }
    if (data.containsKey('trans_fat_g')) {
      context.handle(
        _transFatGMeta,
        transFatG.isAcceptableOrUnknown(data['trans_fat_g']!, _transFatGMeta),
      );
    }
    if (data.containsKey('fibre_g')) {
      context.handle(
        _fibreGMeta,
        fibreG.isAcceptableOrUnknown(data['fibre_g']!, _fibreGMeta),
      );
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    }
    if (data.containsKey('alcohol_g')) {
      context.handle(
        _alcoholGMeta,
        alcoholG.isAcceptableOrUnknown(data['alcohol_g']!, _alcoholGMeta),
      );
    }
    if (data.containsKey('glycemic_index')) {
      context.handle(
        _glycemicIndexMeta,
        glycemicIndex.isAcceptableOrUnknown(
          data['glycemic_index']!,
          _glycemicIndexMeta,
        ),
      );
    }
    if (data.containsKey('nova_group')) {
      context.handle(
        _novaGroupMeta,
        novaGroup.isAcceptableOrUnknown(data['nova_group']!, _novaGroupMeta),
      );
    }
    if (data.containsKey('additives_json')) {
      context.handle(
        _additivesJsonMeta,
        additivesJson.isAcceptableOrUnknown(
          data['additives_json']!,
          _additivesJsonMeta,
        ),
      );
    }
    if (data.containsKey('grams_per_piece')) {
      context.handle(
        _gramsPerPieceMeta,
        gramsPerPiece.isAcceptableOrUnknown(
          data['grams_per_piece']!,
          _gramsPerPieceMeta,
        ),
      );
    }
    if (data.containsKey('piece_name')) {
      context.handle(
        _pieceNameMeta,
        pieceName.isAcceptableOrUnknown(data['piece_name']!, _pieceNameMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {barcode},
  ];
  @override
  Food map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Food(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      searchKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_key'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      )!,
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      )!,
      carbsG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_g'],
      )!,
      sugarG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sugar_g'],
      )!,
      addedSugarG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}added_sugar_g'],
      ),
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      )!,
      satFatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sat_fat_g'],
      )!,
      transFatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}trans_fat_g'],
      ),
      fibreG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fibre_g'],
      )!,
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sodium_mg'],
      )!,
      alcoholG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}alcohol_g'],
      )!,
      glycemicIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}glycemic_index'],
      ),
      novaGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nova_group'],
      ),
      additivesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}additives_json'],
      ),
      gramsPerPiece: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams_per_piece'],
      ),
      pieceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_name'],
      ),
      source: $FoodsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FoodSource, String, String> $convertersource =
      const EnumNameConverter<FoodSource>(FoodSource.values);
}

class Food extends DataClass implements Insertable<Food> {
  final int id;
  final String name;
  final String? brand;
  final String? barcode;

  /// Lowercased name + brand, for cheap local lookup before any network call.
  final String searchKey;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double sugarG;

  /// Free sugars, which is what the WHO limit is about. Often unknown for
  /// whole foods, where it is legitimately zero.
  final double? addedSugarG;
  final double fatG;
  final double satFatG;
  final double? transFatG;
  final double fibreG;
  final double sodiumMg;
  final double alcoholG;

  /// Glycemic index. Null where the food has too little carbohydrate for the
  /// measure to mean anything — which is not the same as a GI of zero.
  final int? glycemicIndex;

  /// NOVA processing group, 1 (unprocessed) to 4 (ultra-processed).
  final int? novaGroup;

  /// JSON array of additive tags, e.g. `["en:e150d","en:e338"]`.
  final String? additivesJson;

  /// Grams in one natural unit ("1 egg", "1 slice"), when there is one.
  final double? gramsPerPiece;
  final String? pieceName;
  final FoodSource source;

  /// 0..1. How much to trust these numbers; drives whether a better source is
  /// allowed to overwrite them.
  final double confidence;
  final String? imagePath;
  final String createdAt;
  final String updatedAt;
  const Food({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.searchKey,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.sugarG,
    this.addedSugarG,
    required this.fatG,
    required this.satFatG,
    this.transFatG,
    required this.fibreG,
    required this.sodiumMg,
    required this.alcoholG,
    this.glycemicIndex,
    this.novaGroup,
    this.additivesJson,
    this.gramsPerPiece,
    this.pieceName,
    required this.source,
    required this.confidence,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['search_key'] = Variable<String>(searchKey);
    map['kcal'] = Variable<double>(kcal);
    map['protein_g'] = Variable<double>(proteinG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['sugar_g'] = Variable<double>(sugarG);
    if (!nullToAbsent || addedSugarG != null) {
      map['added_sugar_g'] = Variable<double>(addedSugarG);
    }
    map['fat_g'] = Variable<double>(fatG);
    map['sat_fat_g'] = Variable<double>(satFatG);
    if (!nullToAbsent || transFatG != null) {
      map['trans_fat_g'] = Variable<double>(transFatG);
    }
    map['fibre_g'] = Variable<double>(fibreG);
    map['sodium_mg'] = Variable<double>(sodiumMg);
    map['alcohol_g'] = Variable<double>(alcoholG);
    if (!nullToAbsent || glycemicIndex != null) {
      map['glycemic_index'] = Variable<int>(glycemicIndex);
    }
    if (!nullToAbsent || novaGroup != null) {
      map['nova_group'] = Variable<int>(novaGroup);
    }
    if (!nullToAbsent || additivesJson != null) {
      map['additives_json'] = Variable<String>(additivesJson);
    }
    if (!nullToAbsent || gramsPerPiece != null) {
      map['grams_per_piece'] = Variable<double>(gramsPerPiece);
    }
    if (!nullToAbsent || pieceName != null) {
      map['piece_name'] = Variable<String>(pieceName);
    }
    {
      map['source'] = Variable<String>(
        $FoodsTable.$convertersource.toSql(source),
      );
    }
    map['confidence'] = Variable<double>(confidence);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      searchKey: Value(searchKey),
      kcal: Value(kcal),
      proteinG: Value(proteinG),
      carbsG: Value(carbsG),
      sugarG: Value(sugarG),
      addedSugarG: addedSugarG == null && nullToAbsent
          ? const Value.absent()
          : Value(addedSugarG),
      fatG: Value(fatG),
      satFatG: Value(satFatG),
      transFatG: transFatG == null && nullToAbsent
          ? const Value.absent()
          : Value(transFatG),
      fibreG: Value(fibreG),
      sodiumMg: Value(sodiumMg),
      alcoholG: Value(alcoholG),
      glycemicIndex: glycemicIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(glycemicIndex),
      novaGroup: novaGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(novaGroup),
      additivesJson: additivesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(additivesJson),
      gramsPerPiece: gramsPerPiece == null && nullToAbsent
          ? const Value.absent()
          : Value(gramsPerPiece),
      pieceName: pieceName == null && nullToAbsent
          ? const Value.absent()
          : Value(pieceName),
      source: Value(source),
      confidence: Value(confidence),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Food.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Food(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      searchKey: serializer.fromJson<String>(json['searchKey']),
      kcal: serializer.fromJson<double>(json['kcal']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      sugarG: serializer.fromJson<double>(json['sugarG']),
      addedSugarG: serializer.fromJson<double?>(json['addedSugarG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      satFatG: serializer.fromJson<double>(json['satFatG']),
      transFatG: serializer.fromJson<double?>(json['transFatG']),
      fibreG: serializer.fromJson<double>(json['fibreG']),
      sodiumMg: serializer.fromJson<double>(json['sodiumMg']),
      alcoholG: serializer.fromJson<double>(json['alcoholG']),
      glycemicIndex: serializer.fromJson<int?>(json['glycemicIndex']),
      novaGroup: serializer.fromJson<int?>(json['novaGroup']),
      additivesJson: serializer.fromJson<String?>(json['additivesJson']),
      gramsPerPiece: serializer.fromJson<double?>(json['gramsPerPiece']),
      pieceName: serializer.fromJson<String?>(json['pieceName']),
      source: $FoodsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      confidence: serializer.fromJson<double>(json['confidence']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'barcode': serializer.toJson<String?>(barcode),
      'searchKey': serializer.toJson<String>(searchKey),
      'kcal': serializer.toJson<double>(kcal),
      'proteinG': serializer.toJson<double>(proteinG),
      'carbsG': serializer.toJson<double>(carbsG),
      'sugarG': serializer.toJson<double>(sugarG),
      'addedSugarG': serializer.toJson<double?>(addedSugarG),
      'fatG': serializer.toJson<double>(fatG),
      'satFatG': serializer.toJson<double>(satFatG),
      'transFatG': serializer.toJson<double?>(transFatG),
      'fibreG': serializer.toJson<double>(fibreG),
      'sodiumMg': serializer.toJson<double>(sodiumMg),
      'alcoholG': serializer.toJson<double>(alcoholG),
      'glycemicIndex': serializer.toJson<int?>(glycemicIndex),
      'novaGroup': serializer.toJson<int?>(novaGroup),
      'additivesJson': serializer.toJson<String?>(additivesJson),
      'gramsPerPiece': serializer.toJson<double?>(gramsPerPiece),
      'pieceName': serializer.toJson<String?>(pieceName),
      'source': serializer.toJson<String>(
        $FoodsTable.$convertersource.toJson(source),
      ),
      'confidence': serializer.toJson<double>(confidence),
      'imagePath': serializer.toJson<String?>(imagePath),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Food copyWith({
    int? id,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? searchKey,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? sugarG,
    Value<double?> addedSugarG = const Value.absent(),
    double? fatG,
    double? satFatG,
    Value<double?> transFatG = const Value.absent(),
    double? fibreG,
    double? sodiumMg,
    double? alcoholG,
    Value<int?> glycemicIndex = const Value.absent(),
    Value<int?> novaGroup = const Value.absent(),
    Value<String?> additivesJson = const Value.absent(),
    Value<double?> gramsPerPiece = const Value.absent(),
    Value<String?> pieceName = const Value.absent(),
    FoodSource? source,
    double? confidence,
    Value<String?> imagePath = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Food(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    barcode: barcode.present ? barcode.value : this.barcode,
    searchKey: searchKey ?? this.searchKey,
    kcal: kcal ?? this.kcal,
    proteinG: proteinG ?? this.proteinG,
    carbsG: carbsG ?? this.carbsG,
    sugarG: sugarG ?? this.sugarG,
    addedSugarG: addedSugarG.present ? addedSugarG.value : this.addedSugarG,
    fatG: fatG ?? this.fatG,
    satFatG: satFatG ?? this.satFatG,
    transFatG: transFatG.present ? transFatG.value : this.transFatG,
    fibreG: fibreG ?? this.fibreG,
    sodiumMg: sodiumMg ?? this.sodiumMg,
    alcoholG: alcoholG ?? this.alcoholG,
    glycemicIndex: glycemicIndex.present
        ? glycemicIndex.value
        : this.glycemicIndex,
    novaGroup: novaGroup.present ? novaGroup.value : this.novaGroup,
    additivesJson: additivesJson.present
        ? additivesJson.value
        : this.additivesJson,
    gramsPerPiece: gramsPerPiece.present
        ? gramsPerPiece.value
        : this.gramsPerPiece,
    pieceName: pieceName.present ? pieceName.value : this.pieceName,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Food copyWithCompanion(FoodsCompanion data) {
    return Food(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      searchKey: data.searchKey.present ? data.searchKey.value : this.searchKey,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      sugarG: data.sugarG.present ? data.sugarG.value : this.sugarG,
      addedSugarG: data.addedSugarG.present
          ? data.addedSugarG.value
          : this.addedSugarG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      satFatG: data.satFatG.present ? data.satFatG.value : this.satFatG,
      transFatG: data.transFatG.present ? data.transFatG.value : this.transFatG,
      fibreG: data.fibreG.present ? data.fibreG.value : this.fibreG,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      alcoholG: data.alcoholG.present ? data.alcoholG.value : this.alcoholG,
      glycemicIndex: data.glycemicIndex.present
          ? data.glycemicIndex.value
          : this.glycemicIndex,
      novaGroup: data.novaGroup.present ? data.novaGroup.value : this.novaGroup,
      additivesJson: data.additivesJson.present
          ? data.additivesJson.value
          : this.additivesJson,
      gramsPerPiece: data.gramsPerPiece.present
          ? data.gramsPerPiece.value
          : this.gramsPerPiece,
      pieceName: data.pieceName.present ? data.pieceName.value : this.pieceName,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Food(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('searchKey: $searchKey, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('sugarG: $sugarG, ')
          ..write('addedSugarG: $addedSugarG, ')
          ..write('fatG: $fatG, ')
          ..write('satFatG: $satFatG, ')
          ..write('transFatG: $transFatG, ')
          ..write('fibreG: $fibreG, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('alcoholG: $alcoholG, ')
          ..write('glycemicIndex: $glycemicIndex, ')
          ..write('novaGroup: $novaGroup, ')
          ..write('additivesJson: $additivesJson, ')
          ..write('gramsPerPiece: $gramsPerPiece, ')
          ..write('pieceName: $pieceName, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    brand,
    barcode,
    searchKey,
    kcal,
    proteinG,
    carbsG,
    sugarG,
    addedSugarG,
    fatG,
    satFatG,
    transFatG,
    fibreG,
    sodiumMg,
    alcoholG,
    glycemicIndex,
    novaGroup,
    additivesJson,
    gramsPerPiece,
    pieceName,
    source,
    confidence,
    imagePath,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Food &&
          other.id == this.id &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.barcode == this.barcode &&
          other.searchKey == this.searchKey &&
          other.kcal == this.kcal &&
          other.proteinG == this.proteinG &&
          other.carbsG == this.carbsG &&
          other.sugarG == this.sugarG &&
          other.addedSugarG == this.addedSugarG &&
          other.fatG == this.fatG &&
          other.satFatG == this.satFatG &&
          other.transFatG == this.transFatG &&
          other.fibreG == this.fibreG &&
          other.sodiumMg == this.sodiumMg &&
          other.alcoholG == this.alcoholG &&
          other.glycemicIndex == this.glycemicIndex &&
          other.novaGroup == this.novaGroup &&
          other.additivesJson == this.additivesJson &&
          other.gramsPerPiece == this.gramsPerPiece &&
          other.pieceName == this.pieceName &&
          other.source == this.source &&
          other.confidence == this.confidence &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FoodsCompanion extends UpdateCompanion<Food> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> barcode;
  final Value<String> searchKey;
  final Value<double> kcal;
  final Value<double> proteinG;
  final Value<double> carbsG;
  final Value<double> sugarG;
  final Value<double?> addedSugarG;
  final Value<double> fatG;
  final Value<double> satFatG;
  final Value<double?> transFatG;
  final Value<double> fibreG;
  final Value<double> sodiumMg;
  final Value<double> alcoholG;
  final Value<int?> glycemicIndex;
  final Value<int?> novaGroup;
  final Value<String?> additivesJson;
  final Value<double?> gramsPerPiece;
  final Value<String?> pieceName;
  final Value<FoodSource> source;
  final Value<double> confidence;
  final Value<String?> imagePath;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    this.searchKey = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.sugarG = const Value.absent(),
    this.addedSugarG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.satFatG = const Value.absent(),
    this.transFatG = const Value.absent(),
    this.fibreG = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.alcoholG = const Value.absent(),
    this.glycemicIndex = const Value.absent(),
    this.novaGroup = const Value.absent(),
    this.additivesJson = const Value.absent(),
    this.gramsPerPiece = const Value.absent(),
    this.pieceName = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FoodsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    required String searchKey,
    required double kcal,
    this.proteinG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.sugarG = const Value.absent(),
    this.addedSugarG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.satFatG = const Value.absent(),
    this.transFatG = const Value.absent(),
    this.fibreG = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.alcoholG = const Value.absent(),
    this.glycemicIndex = const Value.absent(),
    this.novaGroup = const Value.absent(),
    this.additivesJson = const Value.absent(),
    this.gramsPerPiece = const Value.absent(),
    this.pieceName = const Value.absent(),
    required FoodSource source,
    this.confidence = const Value.absent(),
    this.imagePath = const Value.absent(),
    required String createdAt,
    required String updatedAt,
  }) : name = Value(name),
       searchKey = Value(searchKey),
       kcal = Value(kcal),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Food> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? barcode,
    Expression<String>? searchKey,
    Expression<double>? kcal,
    Expression<double>? proteinG,
    Expression<double>? carbsG,
    Expression<double>? sugarG,
    Expression<double>? addedSugarG,
    Expression<double>? fatG,
    Expression<double>? satFatG,
    Expression<double>? transFatG,
    Expression<double>? fibreG,
    Expression<double>? sodiumMg,
    Expression<double>? alcoholG,
    Expression<int>? glycemicIndex,
    Expression<int>? novaGroup,
    Expression<String>? additivesJson,
    Expression<double>? gramsPerPiece,
    Expression<String>? pieceName,
    Expression<String>? source,
    Expression<double>? confidence,
    Expression<String>? imagePath,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (barcode != null) 'barcode': barcode,
      if (searchKey != null) 'search_key': searchKey,
      if (kcal != null) 'kcal': kcal,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (sugarG != null) 'sugar_g': sugarG,
      if (addedSugarG != null) 'added_sugar_g': addedSugarG,
      if (fatG != null) 'fat_g': fatG,
      if (satFatG != null) 'sat_fat_g': satFatG,
      if (transFatG != null) 'trans_fat_g': transFatG,
      if (fibreG != null) 'fibre_g': fibreG,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (alcoholG != null) 'alcohol_g': alcoholG,
      if (glycemicIndex != null) 'glycemic_index': glycemicIndex,
      if (novaGroup != null) 'nova_group': novaGroup,
      if (additivesJson != null) 'additives_json': additivesJson,
      if (gramsPerPiece != null) 'grams_per_piece': gramsPerPiece,
      if (pieceName != null) 'piece_name': pieceName,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FoodsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? barcode,
    Value<String>? searchKey,
    Value<double>? kcal,
    Value<double>? proteinG,
    Value<double>? carbsG,
    Value<double>? sugarG,
    Value<double?>? addedSugarG,
    Value<double>? fatG,
    Value<double>? satFatG,
    Value<double?>? transFatG,
    Value<double>? fibreG,
    Value<double>? sodiumMg,
    Value<double>? alcoholG,
    Value<int?>? glycemicIndex,
    Value<int?>? novaGroup,
    Value<String?>? additivesJson,
    Value<double?>? gramsPerPiece,
    Value<String?>? pieceName,
    Value<FoodSource>? source,
    Value<double>? confidence,
    Value<String?>? imagePath,
    Value<String>? createdAt,
    Value<String>? updatedAt,
  }) {
    return FoodsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      searchKey: searchKey ?? this.searchKey,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      sugarG: sugarG ?? this.sugarG,
      addedSugarG: addedSugarG ?? this.addedSugarG,
      fatG: fatG ?? this.fatG,
      satFatG: satFatG ?? this.satFatG,
      transFatG: transFatG ?? this.transFatG,
      fibreG: fibreG ?? this.fibreG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      alcoholG: alcoholG ?? this.alcoholG,
      glycemicIndex: glycemicIndex ?? this.glycemicIndex,
      novaGroup: novaGroup ?? this.novaGroup,
      additivesJson: additivesJson ?? this.additivesJson,
      gramsPerPiece: gramsPerPiece ?? this.gramsPerPiece,
      pieceName: pieceName ?? this.pieceName,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (searchKey.present) {
      map['search_key'] = Variable<String>(searchKey.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (sugarG.present) {
      map['sugar_g'] = Variable<double>(sugarG.value);
    }
    if (addedSugarG.present) {
      map['added_sugar_g'] = Variable<double>(addedSugarG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (satFatG.present) {
      map['sat_fat_g'] = Variable<double>(satFatG.value);
    }
    if (transFatG.present) {
      map['trans_fat_g'] = Variable<double>(transFatG.value);
    }
    if (fibreG.present) {
      map['fibre_g'] = Variable<double>(fibreG.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<double>(sodiumMg.value);
    }
    if (alcoholG.present) {
      map['alcohol_g'] = Variable<double>(alcoholG.value);
    }
    if (glycemicIndex.present) {
      map['glycemic_index'] = Variable<int>(glycemicIndex.value);
    }
    if (novaGroup.present) {
      map['nova_group'] = Variable<int>(novaGroup.value);
    }
    if (additivesJson.present) {
      map['additives_json'] = Variable<String>(additivesJson.value);
    }
    if (gramsPerPiece.present) {
      map['grams_per_piece'] = Variable<double>(gramsPerPiece.value);
    }
    if (pieceName.present) {
      map['piece_name'] = Variable<String>(pieceName.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $FoodsTable.$convertersource.toSql(source.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('searchKey: $searchKey, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('sugarG: $sugarG, ')
          ..write('addedSugarG: $addedSugarG, ')
          ..write('fatG: $fatG, ')
          ..write('satFatG: $satFatG, ')
          ..write('transFatG: $transFatG, ')
          ..write('fibreG: $fibreG, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('alcoholG: $alcoholG, ')
          ..write('glycemicIndex: $glycemicIndex, ')
          ..write('novaGroup: $novaGroup, ')
          ..write('additivesJson: $additivesJson, ')
          ..write('gramsPerPiece: $gramsPerPiece, ')
          ..write('pieceName: $pieceName, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> day =
      GeneratedColumn<int>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($EntriesTable.$converterday);
  @override
  late final GeneratedColumnWithTypeConverter<MealSlot, String> mealSlot =
      GeneratedColumn<String>(
        'meal_slot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MealSlot>($EntriesTable.$convertermealSlot);
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    foodId,
    day,
    mealSlot,
    quantity,
    unit,
    grams,
    rawText,
    photoPath,
    confidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      day: $EntriesTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}day'],
        )!,
      ),
      mealSlot: $EntriesTable.$convertermealSlot.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}meal_slot'],
        )!,
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      )!,
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterday = const DayConverter();
  static JsonTypeConverter2<MealSlot, String, String> $convertermealSlot =
      const EnumNameConverter<MealSlot>(MealSlot.values);
}

class Entry extends DataClass implements Insertable<Entry> {
  final int id;
  final int foodId;
  final Day day;
  final MealSlot mealSlot;

  /// What the user said: "2", "a handful", "half a plate".
  final double quantity;
  final String unit;

  /// The quantity resolved to grams. This is what every calculation uses.
  final double grams;

  /// The original phrasing, kept so a bad parse can be re-resolved later and so
  /// the Journal reads like a journal rather than a spreadsheet.
  final String? rawText;
  final String? photoPath;

  /// 0..1 confidence in the portion resolution specifically.
  final double confidence;
  final String createdAt;
  const Entry({
    required this.id,
    required this.foodId,
    required this.day,
    required this.mealSlot,
    required this.quantity,
    required this.unit,
    required this.grams,
    this.rawText,
    this.photoPath,
    required this.confidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['food_id'] = Variable<int>(foodId);
    {
      map['day'] = Variable<int>($EntriesTable.$converterday.toSql(day));
    }
    {
      map['meal_slot'] = Variable<String>(
        $EntriesTable.$convertermealSlot.toSql(mealSlot),
      );
    }
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    map['grams'] = Variable<double>(grams);
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['confidence'] = Variable<double>(confidence);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      foodId: Value(foodId),
      day: Value(day),
      mealSlot: Value(mealSlot),
      quantity: Value(quantity),
      unit: Value(unit),
      grams: Value(grams),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      confidence: Value(confidence),
      createdAt: Value(createdAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<int>(json['id']),
      foodId: serializer.fromJson<int>(json['foodId']),
      day: serializer.fromJson<Day>(json['day']),
      mealSlot: $EntriesTable.$convertermealSlot.fromJson(
        serializer.fromJson<String>(json['mealSlot']),
      ),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      grams: serializer.fromJson<double>(json['grams']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      confidence: serializer.fromJson<double>(json['confidence']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodId': serializer.toJson<int>(foodId),
      'day': serializer.toJson<Day>(day),
      'mealSlot': serializer.toJson<String>(
        $EntriesTable.$convertermealSlot.toJson(mealSlot),
      ),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'grams': serializer.toJson<double>(grams),
      'rawText': serializer.toJson<String?>(rawText),
      'photoPath': serializer.toJson<String?>(photoPath),
      'confidence': serializer.toJson<double>(confidence),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Entry copyWith({
    int? id,
    int? foodId,
    Day? day,
    MealSlot? mealSlot,
    double? quantity,
    String? unit,
    double? grams,
    Value<String?> rawText = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
    double? confidence,
    String? createdAt,
  }) => Entry(
    id: id ?? this.id,
    foodId: foodId ?? this.foodId,
    day: day ?? this.day,
    mealSlot: mealSlot ?? this.mealSlot,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    grams: grams ?? this.grams,
    rawText: rawText.present ? rawText.value : this.rawText,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    confidence: confidence ?? this.confidence,
    createdAt: createdAt ?? this.createdAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      day: data.day.present ? data.day.value : this.day,
      mealSlot: data.mealSlot.present ? data.mealSlot.value : this.mealSlot,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      grams: data.grams.present ? data.grams.value : this.grams,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('day: $day, ')
          ..write('mealSlot: $mealSlot, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('grams: $grams, ')
          ..write('rawText: $rawText, ')
          ..write('photoPath: $photoPath, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodId,
    day,
    mealSlot,
    quantity,
    unit,
    grams,
    rawText,
    photoPath,
    confidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.foodId == this.foodId &&
          other.day == this.day &&
          other.mealSlot == this.mealSlot &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.grams == this.grams &&
          other.rawText == this.rawText &&
          other.photoPath == this.photoPath &&
          other.confidence == this.confidence &&
          other.createdAt == this.createdAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<int> id;
  final Value<int> foodId;
  final Value<Day> day;
  final Value<MealSlot> mealSlot;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<double> grams;
  final Value<String?> rawText;
  final Value<String?> photoPath;
  final Value<double> confidence;
  final Value<String> createdAt;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.foodId = const Value.absent(),
    this.day = const Value.absent(),
    this.mealSlot = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.grams = const Value.absent(),
    this.rawText = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int foodId,
    required Day day,
    required MealSlot mealSlot,
    required double quantity,
    required String unit,
    required double grams,
    this.rawText = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.confidence = const Value.absent(),
    required String createdAt,
  }) : foodId = Value(foodId),
       day = Value(day),
       mealSlot = Value(mealSlot),
       quantity = Value(quantity),
       unit = Value(unit),
       grams = Value(grams),
       createdAt = Value(createdAt);
  static Insertable<Entry> custom({
    Expression<int>? id,
    Expression<int>? foodId,
    Expression<int>? day,
    Expression<String>? mealSlot,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<double>? grams,
    Expression<String>? rawText,
    Expression<String>? photoPath,
    Expression<double>? confidence,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodId != null) 'food_id': foodId,
      if (day != null) 'day': day,
      if (mealSlot != null) 'meal_slot': mealSlot,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (grams != null) 'grams': grams,
      if (rawText != null) 'raw_text': rawText,
      if (photoPath != null) 'photo_path': photoPath,
      if (confidence != null) 'confidence': confidence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? foodId,
    Value<Day>? day,
    Value<MealSlot>? mealSlot,
    Value<double>? quantity,
    Value<String>? unit,
    Value<double>? grams,
    Value<String?>? rawText,
    Value<String?>? photoPath,
    Value<double>? confidence,
    Value<String>? createdAt,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      day: day ?? this.day,
      mealSlot: mealSlot ?? this.mealSlot,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      grams: grams ?? this.grams,
      rawText: rawText ?? this.rawText,
      photoPath: photoPath ?? this.photoPath,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>($EntriesTable.$converterday.toSql(day.value));
    }
    if (mealSlot.present) {
      map['meal_slot'] = Variable<String>(
        $EntriesTable.$convertermealSlot.toSql(mealSlot.value),
      );
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('day: $day, ')
          ..write('mealSlot: $mealSlot, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('grams: $grams, ')
          ..write('rawText: $rawText, ')
          ..write('photoPath: $photoPath, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ActivityDaysTable extends ActivityDays
    with TableInfo<$ActivityDaysTable, ActivityDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityDaysTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> day =
      GeneratedColumn<int>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($ActivityDaysTable.$converterday);
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeKcalMeta = const VerificationMeta(
    'activeKcal',
  );
  @override
  late final GeneratedColumn<double> activeKcal = GeneratedColumn<double>(
    'active_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ActivitySource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ActivitySource>($ActivityDaysTable.$convertersource);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    steps,
    distanceM,
    activeKcal,
    source,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('active_kcal')) {
      context.handle(
        _activeKcalMeta,
        activeKcal.isAcceptableOrUnknown(data['active_kcal']!, _activeKcalMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  ActivityDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityDay(
      day: $ActivityDaysTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}day'],
        )!,
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      activeKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}active_kcal'],
      ),
      source: $ActivityDaysTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActivityDaysTable createAlias(String alias) {
    return $ActivityDaysTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterday = const DayConverter();
  static JsonTypeConverter2<ActivitySource, String, String> $convertersource =
      const EnumNameConverter<ActivitySource>(ActivitySource.values);
  @override
  bool get withoutRowId => true;
}

class ActivityDay extends DataClass implements Insertable<ActivityDay> {
  final Day day;
  final int steps;
  final double distanceM;

  /// Active energy, when the platform reports it.
  final double? activeKcal;
  final ActivitySource source;
  final String updatedAt;
  const ActivityDay({
    required this.day,
    required this.steps,
    required this.distanceM,
    this.activeKcal,
    required this.source,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['day'] = Variable<int>($ActivityDaysTable.$converterday.toSql(day));
    }
    map['steps'] = Variable<int>(steps);
    map['distance_m'] = Variable<double>(distanceM);
    if (!nullToAbsent || activeKcal != null) {
      map['active_kcal'] = Variable<double>(activeKcal);
    }
    {
      map['source'] = Variable<String>(
        $ActivityDaysTable.$convertersource.toSql(source),
      );
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ActivityDaysCompanion toCompanion(bool nullToAbsent) {
    return ActivityDaysCompanion(
      day: Value(day),
      steps: Value(steps),
      distanceM: Value(distanceM),
      activeKcal: activeKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(activeKcal),
      source: Value(source),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActivityDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityDay(
      day: serializer.fromJson<Day>(json['day']),
      steps: serializer.fromJson<int>(json['steps']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      activeKcal: serializer.fromJson<double?>(json['activeKcal']),
      source: $ActivityDaysTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<Day>(day),
      'steps': serializer.toJson<int>(steps),
      'distanceM': serializer.toJson<double>(distanceM),
      'activeKcal': serializer.toJson<double?>(activeKcal),
      'source': serializer.toJson<String>(
        $ActivityDaysTable.$convertersource.toJson(source),
      ),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ActivityDay copyWith({
    Day? day,
    int? steps,
    double? distanceM,
    Value<double?> activeKcal = const Value.absent(),
    ActivitySource? source,
    String? updatedAt,
  }) => ActivityDay(
    day: day ?? this.day,
    steps: steps ?? this.steps,
    distanceM: distanceM ?? this.distanceM,
    activeKcal: activeKcal.present ? activeKcal.value : this.activeKcal,
    source: source ?? this.source,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActivityDay copyWithCompanion(ActivityDaysCompanion data) {
    return ActivityDay(
      day: data.day.present ? data.day.value : this.day,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      activeKcal: data.activeKcal.present
          ? data.activeKcal.value
          : this.activeKcal,
      source: data.source.present ? data.source.value : this.source,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityDay(')
          ..write('day: $day, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('activeKcal: $activeKcal, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(day, steps, distanceM, activeKcal, source, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityDay &&
          other.day == this.day &&
          other.steps == this.steps &&
          other.distanceM == this.distanceM &&
          other.activeKcal == this.activeKcal &&
          other.source == this.source &&
          other.updatedAt == this.updatedAt);
}

class ActivityDaysCompanion extends UpdateCompanion<ActivityDay> {
  final Value<Day> day;
  final Value<int> steps;
  final Value<double> distanceM;
  final Value<double?> activeKcal;
  final Value<ActivitySource> source;
  final Value<String> updatedAt;
  const ActivityDaysCompanion({
    this.day = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.activeKcal = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ActivityDaysCompanion.insert({
    required Day day,
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.activeKcal = const Value.absent(),
    required ActivitySource source,
    required String updatedAt,
  }) : day = Value(day),
       source = Value(source),
       updatedAt = Value(updatedAt);
  static Insertable<ActivityDay> custom({
    Expression<int>? day,
    Expression<int>? steps,
    Expression<double>? distanceM,
    Expression<double>? activeKcal,
    Expression<String>? source,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (activeKcal != null) 'active_kcal': activeKcal,
      if (source != null) 'source': source,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ActivityDaysCompanion copyWith({
    Value<Day>? day,
    Value<int>? steps,
    Value<double>? distanceM,
    Value<double?>? activeKcal,
    Value<ActivitySource>? source,
    Value<String>? updatedAt,
  }) {
    return ActivityDaysCompanion(
      day: day ?? this.day,
      steps: steps ?? this.steps,
      distanceM: distanceM ?? this.distanceM,
      activeKcal: activeKcal ?? this.activeKcal,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>(
        $ActivityDaysTable.$converterday.toSql(day.value),
      );
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (activeKcal.present) {
      map['active_kcal'] = Variable<double>(activeKcal.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ActivityDaysTable.$convertersource.toSql(source.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityDaysCompanion(')
          ..write('day: $day, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('activeKcal: $activeKcal, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WeightsTable extends Weights with TableInfo<$WeightsTable, Weight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> day =
      GeneratedColumn<int>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($WeightsTable.$converterday);
  static const VerificationMeta _kgMeta = const VerificationMeta('kg');
  @override
  late final GeneratedColumn<double> kg = GeneratedColumn<double>(
    'kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, kg, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weights';
  @override
  VerificationContext validateIntegrity(
    Insertable<Weight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kg')) {
      context.handle(_kgMeta, kg.isAcceptableOrUnknown(data['kg']!, _kgMeta));
    } else if (isInserting) {
      context.missing(_kgMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  Weight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Weight(
      day: $WeightsTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}day'],
        )!,
      ),
      kg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WeightsTable createAlias(String alias) {
    return $WeightsTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterday = const DayConverter();
  @override
  bool get withoutRowId => true;
}

class Weight extends DataClass implements Insertable<Weight> {
  final Day day;
  final double kg;
  final String createdAt;
  const Weight({required this.day, required this.kg, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['day'] = Variable<int>($WeightsTable.$converterday.toSql(day));
    }
    map['kg'] = Variable<double>(kg);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  WeightsCompanion toCompanion(bool nullToAbsent) {
    return WeightsCompanion(
      day: Value(day),
      kg: Value(kg),
      createdAt: Value(createdAt),
    );
  }

  factory Weight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Weight(
      day: serializer.fromJson<Day>(json['day']),
      kg: serializer.fromJson<double>(json['kg']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<Day>(day),
      'kg': serializer.toJson<double>(kg),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Weight copyWith({Day? day, double? kg, String? createdAt}) => Weight(
    day: day ?? this.day,
    kg: kg ?? this.kg,
    createdAt: createdAt ?? this.createdAt,
  );
  Weight copyWithCompanion(WeightsCompanion data) {
    return Weight(
      day: data.day.present ? data.day.value : this.day,
      kg: data.kg.present ? data.kg.value : this.kg,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Weight(')
          ..write('day: $day, ')
          ..write('kg: $kg, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, kg, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Weight &&
          other.day == this.day &&
          other.kg == this.kg &&
          other.createdAt == this.createdAt);
}

class WeightsCompanion extends UpdateCompanion<Weight> {
  final Value<Day> day;
  final Value<double> kg;
  final Value<String> createdAt;
  const WeightsCompanion({
    this.day = const Value.absent(),
    this.kg = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WeightsCompanion.insert({
    required Day day,
    required double kg,
    required String createdAt,
  }) : day = Value(day),
       kg = Value(kg),
       createdAt = Value(createdAt);
  static Insertable<Weight> custom({
    Expression<int>? day,
    Expression<double>? kg,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (kg != null) 'kg': kg,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WeightsCompanion copyWith({
    Value<Day>? day,
    Value<double>? kg,
    Value<String>? createdAt,
  }) {
    return WeightsCompanion(
      day: day ?? this.day,
      kg: kg ?? this.kg,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>($WeightsTable.$converterday.toSql(day.value));
    }
    if (kg.present) {
      map['kg'] = Variable<double>(kg.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightsCompanion(')
          ..write('day: $day, ')
          ..write('kg: $kg, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WaterLogsTable extends WaterLogs
    with TableInfo<$WaterLogsTable, WaterLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterLogsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> day =
      GeneratedColumn<int>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($WaterLogsTable.$converterday);
  static const VerificationMeta _mlMeta = const VerificationMeta('ml');
  @override
  late final GeneratedColumn<int> ml = GeneratedColumn<int>(
    'ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, ml, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ml')) {
      context.handle(_mlMeta, ml.isAcceptableOrUnknown(data['ml']!, _mlMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  WaterLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterLog(
      day: $WaterLogsTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}day'],
        )!,
      ),
      ml: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ml'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WaterLogsTable createAlias(String alias) {
    return $WaterLogsTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterday = const DayConverter();
  @override
  bool get withoutRowId => true;
}

class WaterLog extends DataClass implements Insertable<WaterLog> {
  final Day day;
  final int ml;
  final String updatedAt;
  const WaterLog({
    required this.day,
    required this.ml,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['day'] = Variable<int>($WaterLogsTable.$converterday.toSql(day));
    }
    map['ml'] = Variable<int>(ml);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WaterLogsCompanion toCompanion(bool nullToAbsent) {
    return WaterLogsCompanion(
      day: Value(day),
      ml: Value(ml),
      updatedAt: Value(updatedAt),
    );
  }

  factory WaterLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterLog(
      day: serializer.fromJson<Day>(json['day']),
      ml: serializer.fromJson<int>(json['ml']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<Day>(day),
      'ml': serializer.toJson<int>(ml),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WaterLog copyWith({Day? day, int? ml, String? updatedAt}) => WaterLog(
    day: day ?? this.day,
    ml: ml ?? this.ml,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WaterLog copyWithCompanion(WaterLogsCompanion data) {
    return WaterLog(
      day: data.day.present ? data.day.value : this.day,
      ml: data.ml.present ? data.ml.value : this.ml,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterLog(')
          ..write('day: $day, ')
          ..write('ml: $ml, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, ml, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterLog &&
          other.day == this.day &&
          other.ml == this.ml &&
          other.updatedAt == this.updatedAt);
}

class WaterLogsCompanion extends UpdateCompanion<WaterLog> {
  final Value<Day> day;
  final Value<int> ml;
  final Value<String> updatedAt;
  const WaterLogsCompanion({
    this.day = const Value.absent(),
    this.ml = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WaterLogsCompanion.insert({
    required Day day,
    this.ml = const Value.absent(),
    required String updatedAt,
  }) : day = Value(day),
       updatedAt = Value(updatedAt);
  static Insertable<WaterLog> custom({
    Expression<int>? day,
    Expression<int>? ml,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (ml != null) 'ml': ml,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WaterLogsCompanion copyWith({
    Value<Day>? day,
    Value<int>? ml,
    Value<String>? updatedAt,
  }) {
    return WaterLogsCompanion(
      day: day ?? this.day,
      ml: ml ?? this.ml,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>(
        $WaterLogsTable.$converterday.toSql(day.value),
      );
    }
    if (ml.present) {
      map['ml'] = Variable<int>(ml.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterLogsCompanion(')
          ..write('day: $day, ')
          ..write('ml: $ml, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WeeksTable extends Weeks with TableInfo<$WeeksTable, Week> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeksTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> weekStart =
      GeneratedColumn<int>(
        'week_start',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($WeeksTable.$converterweekStart);
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> weekEnd =
      GeneratedColumn<int>(
        'week_end',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($WeeksTable.$converterweekEnd);
  static const VerificationMeta _revealedMeta = const VerificationMeta(
    'revealed',
  );
  @override
  late final GeneratedColumn<bool> revealed = GeneratedColumn<bool>(
    'revealed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revealed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _narrativeMeta = const VerificationMeta(
    'narrative',
  );
  @override
  late final GeneratedColumn<String> narrative = GeneratedColumn<String>(
    'narrative',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xpAwardedMeta = const VerificationMeta(
    'xpAwarded',
  );
  @override
  late final GeneratedColumn<int> xpAwarded = GeneratedColumn<int>(
    'xp_awarded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    weekStart,
    weekEnd,
    revealed,
    summaryJson,
    narrative,
    xpAwarded,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weeks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Week> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revealed')) {
      context.handle(
        _revealedMeta,
        revealed.isAcceptableOrUnknown(data['revealed']!, _revealedMeta),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('narrative')) {
      context.handle(
        _narrativeMeta,
        narrative.isAcceptableOrUnknown(data['narrative']!, _narrativeMeta),
      );
    }
    if (data.containsKey('xp_awarded')) {
      context.handle(
        _xpAwardedMeta,
        xpAwarded.isAcceptableOrUnknown(data['xp_awarded']!, _xpAwardedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {weekStart};
  @override
  Week map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Week(
      weekStart: $WeeksTable.$converterweekStart.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}week_start'],
        )!,
      ),
      weekEnd: $WeeksTable.$converterweekEnd.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}week_end'],
        )!,
      ),
      revealed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revealed'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      narrative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrative'],
      ),
      xpAwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp_awarded'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WeeksTable createAlias(String alias) {
    return $WeeksTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterweekStart = const DayConverter();
  static TypeConverter<Day, int> $converterweekEnd = const DayConverter();
  @override
  bool get withoutRowId => true;
}

class Week extends DataClass implements Insertable<Week> {
  final Day weekStart;
  final Day weekEnd;
  final bool revealed;

  /// Frozen snapshot of everything the reveal screen shows.
  final String? summaryJson;

  /// The single AI-written account of the week.
  final String? narrative;
  final int xpAwarded;
  final String createdAt;
  const Week({
    required this.weekStart,
    required this.weekEnd,
    required this.revealed,
    this.summaryJson,
    this.narrative,
    required this.xpAwarded,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['week_start'] = Variable<int>(
        $WeeksTable.$converterweekStart.toSql(weekStart),
      );
    }
    {
      map['week_end'] = Variable<int>(
        $WeeksTable.$converterweekEnd.toSql(weekEnd),
      );
    }
    map['revealed'] = Variable<bool>(revealed);
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    if (!nullToAbsent || narrative != null) {
      map['narrative'] = Variable<String>(narrative);
    }
    map['xp_awarded'] = Variable<int>(xpAwarded);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  WeeksCompanion toCompanion(bool nullToAbsent) {
    return WeeksCompanion(
      weekStart: Value(weekStart),
      weekEnd: Value(weekEnd),
      revealed: Value(revealed),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
      narrative: narrative == null && nullToAbsent
          ? const Value.absent()
          : Value(narrative),
      xpAwarded: Value(xpAwarded),
      createdAt: Value(createdAt),
    );
  }

  factory Week.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Week(
      weekStart: serializer.fromJson<Day>(json['weekStart']),
      weekEnd: serializer.fromJson<Day>(json['weekEnd']),
      revealed: serializer.fromJson<bool>(json['revealed']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      narrative: serializer.fromJson<String?>(json['narrative']),
      xpAwarded: serializer.fromJson<int>(json['xpAwarded']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'weekStart': serializer.toJson<Day>(weekStart),
      'weekEnd': serializer.toJson<Day>(weekEnd),
      'revealed': serializer.toJson<bool>(revealed),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'narrative': serializer.toJson<String?>(narrative),
      'xpAwarded': serializer.toJson<int>(xpAwarded),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Week copyWith({
    Day? weekStart,
    Day? weekEnd,
    bool? revealed,
    Value<String?> summaryJson = const Value.absent(),
    Value<String?> narrative = const Value.absent(),
    int? xpAwarded,
    String? createdAt,
  }) => Week(
    weekStart: weekStart ?? this.weekStart,
    weekEnd: weekEnd ?? this.weekEnd,
    revealed: revealed ?? this.revealed,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    narrative: narrative.present ? narrative.value : this.narrative,
    xpAwarded: xpAwarded ?? this.xpAwarded,
    createdAt: createdAt ?? this.createdAt,
  );
  Week copyWithCompanion(WeeksCompanion data) {
    return Week(
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      weekEnd: data.weekEnd.present ? data.weekEnd.value : this.weekEnd,
      revealed: data.revealed.present ? data.revealed.value : this.revealed,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      narrative: data.narrative.present ? data.narrative.value : this.narrative,
      xpAwarded: data.xpAwarded.present ? data.xpAwarded.value : this.xpAwarded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Week(')
          ..write('weekStart: $weekStart, ')
          ..write('weekEnd: $weekEnd, ')
          ..write('revealed: $revealed, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('narrative: $narrative, ')
          ..write('xpAwarded: $xpAwarded, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    weekStart,
    weekEnd,
    revealed,
    summaryJson,
    narrative,
    xpAwarded,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Week &&
          other.weekStart == this.weekStart &&
          other.weekEnd == this.weekEnd &&
          other.revealed == this.revealed &&
          other.summaryJson == this.summaryJson &&
          other.narrative == this.narrative &&
          other.xpAwarded == this.xpAwarded &&
          other.createdAt == this.createdAt);
}

class WeeksCompanion extends UpdateCompanion<Week> {
  final Value<Day> weekStart;
  final Value<Day> weekEnd;
  final Value<bool> revealed;
  final Value<String?> summaryJson;
  final Value<String?> narrative;
  final Value<int> xpAwarded;
  final Value<String> createdAt;
  const WeeksCompanion({
    this.weekStart = const Value.absent(),
    this.weekEnd = const Value.absent(),
    this.revealed = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.narrative = const Value.absent(),
    this.xpAwarded = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WeeksCompanion.insert({
    required Day weekStart,
    required Day weekEnd,
    this.revealed = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.narrative = const Value.absent(),
    this.xpAwarded = const Value.absent(),
    required String createdAt,
  }) : weekStart = Value(weekStart),
       weekEnd = Value(weekEnd),
       createdAt = Value(createdAt);
  static Insertable<Week> custom({
    Expression<int>? weekStart,
    Expression<int>? weekEnd,
    Expression<bool>? revealed,
    Expression<String>? summaryJson,
    Expression<String>? narrative,
    Expression<int>? xpAwarded,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (weekStart != null) 'week_start': weekStart,
      if (weekEnd != null) 'week_end': weekEnd,
      if (revealed != null) 'revealed': revealed,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (narrative != null) 'narrative': narrative,
      if (xpAwarded != null) 'xp_awarded': xpAwarded,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WeeksCompanion copyWith({
    Value<Day>? weekStart,
    Value<Day>? weekEnd,
    Value<bool>? revealed,
    Value<String?>? summaryJson,
    Value<String?>? narrative,
    Value<int>? xpAwarded,
    Value<String>? createdAt,
  }) {
    return WeeksCompanion(
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      revealed: revealed ?? this.revealed,
      summaryJson: summaryJson ?? this.summaryJson,
      narrative: narrative ?? this.narrative,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (weekStart.present) {
      map['week_start'] = Variable<int>(
        $WeeksTable.$converterweekStart.toSql(weekStart.value),
      );
    }
    if (weekEnd.present) {
      map['week_end'] = Variable<int>(
        $WeeksTable.$converterweekEnd.toSql(weekEnd.value),
      );
    }
    if (revealed.present) {
      map['revealed'] = Variable<bool>(revealed.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (narrative.present) {
      map['narrative'] = Variable<String>(narrative.value);
    }
    if (xpAwarded.present) {
      map['xp_awarded'] = Variable<int>(xpAwarded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeksCompanion(')
          ..write('weekStart: $weekStart, ')
          ..write('weekEnd: $weekEnd, ')
          ..write('revealed: $revealed, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('narrative: $narrative, ')
          ..write('xpAwarded: $xpAwarded, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiCallsTable extends AiCalls with TableInfo<$AiCallsTable, AiCall> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Day, int> day =
      GeneratedColumn<int>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Day>($AiCallsTable.$converterday);
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AiPurpose, String> purpose =
      GeneratedColumn<String>(
        'purpose',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AiPurpose>($AiCallsTable.$converterpurpose);
  static const VerificationMeta _succeededMeta = const VerificationMeta(
    'succeeded',
  );
  @override
  late final GeneratedColumn<bool> succeeded = GeneratedColumn<bool>(
    'succeeded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("succeeded" IN (0, 1))',
    ),
  );
  static const VerificationMeta _promptTokensMeta = const VerificationMeta(
    'promptTokens',
  );
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
    'prompt_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionTokensMeta = const VerificationMeta(
    'completionTokens',
  );
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
    'completion_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    at,
    model,
    purpose,
    succeeded,
    promptTokens,
    completionTokens,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiCall> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('succeeded')) {
      context.handle(
        _succeededMeta,
        succeeded.isAcceptableOrUnknown(data['succeeded']!, _succeededMeta),
      );
    } else if (isInserting) {
      context.missing(_succeededMeta);
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
        _promptTokensMeta,
        promptTokens.isAcceptableOrUnknown(
          data['prompt_tokens']!,
          _promptTokensMeta,
        ),
      );
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
        _completionTokensMeta,
        completionTokens.isAcceptableOrUnknown(
          data['completion_tokens']!,
          _completionTokensMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiCall map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiCall(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: $AiCallsTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}day'],
        )!,
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}at'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      purpose: $AiCallsTable.$converterpurpose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}purpose'],
        )!,
      ),
      succeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}succeeded'],
      )!,
      promptTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_tokens'],
      ),
      completionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_tokens'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $AiCallsTable createAlias(String alias) {
    return $AiCallsTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterday = const DayConverter();
  static JsonTypeConverter2<AiPurpose, String, String> $converterpurpose =
      const EnumNameConverter<AiPurpose>(AiPurpose.values);
}

class AiCall extends DataClass implements Insertable<AiCall> {
  final int id;
  final Day day;

  /// Full timestamp, for the 20-requests-per-minute limit.
  final String at;
  final String model;
  final AiPurpose purpose;
  final bool succeeded;
  final int? promptTokens;
  final int? completionTokens;
  final String? error;
  const AiCall({
    required this.id,
    required this.day,
    required this.at,
    required this.model,
    required this.purpose,
    required this.succeeded,
    this.promptTokens,
    this.completionTokens,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['day'] = Variable<int>($AiCallsTable.$converterday.toSql(day));
    }
    map['at'] = Variable<String>(at);
    map['model'] = Variable<String>(model);
    {
      map['purpose'] = Variable<String>(
        $AiCallsTable.$converterpurpose.toSql(purpose),
      );
    }
    map['succeeded'] = Variable<bool>(succeeded);
    if (!nullToAbsent || promptTokens != null) {
      map['prompt_tokens'] = Variable<int>(promptTokens);
    }
    if (!nullToAbsent || completionTokens != null) {
      map['completion_tokens'] = Variable<int>(completionTokens);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  AiCallsCompanion toCompanion(bool nullToAbsent) {
    return AiCallsCompanion(
      id: Value(id),
      day: Value(day),
      at: Value(at),
      model: Value(model),
      purpose: Value(purpose),
      succeeded: Value(succeeded),
      promptTokens: promptTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(promptTokens),
      completionTokens: completionTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(completionTokens),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory AiCall.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiCall(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<Day>(json['day']),
      at: serializer.fromJson<String>(json['at']),
      model: serializer.fromJson<String>(json['model']),
      purpose: $AiCallsTable.$converterpurpose.fromJson(
        serializer.fromJson<String>(json['purpose']),
      ),
      succeeded: serializer.fromJson<bool>(json['succeeded']),
      promptTokens: serializer.fromJson<int?>(json['promptTokens']),
      completionTokens: serializer.fromJson<int?>(json['completionTokens']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<Day>(day),
      'at': serializer.toJson<String>(at),
      'model': serializer.toJson<String>(model),
      'purpose': serializer.toJson<String>(
        $AiCallsTable.$converterpurpose.toJson(purpose),
      ),
      'succeeded': serializer.toJson<bool>(succeeded),
      'promptTokens': serializer.toJson<int?>(promptTokens),
      'completionTokens': serializer.toJson<int?>(completionTokens),
      'error': serializer.toJson<String?>(error),
    };
  }

  AiCall copyWith({
    int? id,
    Day? day,
    String? at,
    String? model,
    AiPurpose? purpose,
    bool? succeeded,
    Value<int?> promptTokens = const Value.absent(),
    Value<int?> completionTokens = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => AiCall(
    id: id ?? this.id,
    day: day ?? this.day,
    at: at ?? this.at,
    model: model ?? this.model,
    purpose: purpose ?? this.purpose,
    succeeded: succeeded ?? this.succeeded,
    promptTokens: promptTokens.present ? promptTokens.value : this.promptTokens,
    completionTokens: completionTokens.present
        ? completionTokens.value
        : this.completionTokens,
    error: error.present ? error.value : this.error,
  );
  AiCall copyWithCompanion(AiCallsCompanion data) {
    return AiCall(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      at: data.at.present ? data.at.value : this.at,
      model: data.model.present ? data.model.value : this.model,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      succeeded: data.succeeded.present ? data.succeeded.value : this.succeeded,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiCall(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('at: $at, ')
          ..write('model: $model, ')
          ..write('purpose: $purpose, ')
          ..write('succeeded: $succeeded, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    day,
    at,
    model,
    purpose,
    succeeded,
    promptTokens,
    completionTokens,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiCall &&
          other.id == this.id &&
          other.day == this.day &&
          other.at == this.at &&
          other.model == this.model &&
          other.purpose == this.purpose &&
          other.succeeded == this.succeeded &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.error == this.error);
}

class AiCallsCompanion extends UpdateCompanion<AiCall> {
  final Value<int> id;
  final Value<Day> day;
  final Value<String> at;
  final Value<String> model;
  final Value<AiPurpose> purpose;
  final Value<bool> succeeded;
  final Value<int?> promptTokens;
  final Value<int?> completionTokens;
  final Value<String?> error;
  const AiCallsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.at = const Value.absent(),
    this.model = const Value.absent(),
    this.purpose = const Value.absent(),
    this.succeeded = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.error = const Value.absent(),
  });
  AiCallsCompanion.insert({
    this.id = const Value.absent(),
    required Day day,
    required String at,
    required String model,
    required AiPurpose purpose,
    required bool succeeded,
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.error = const Value.absent(),
  }) : day = Value(day),
       at = Value(at),
       model = Value(model),
       purpose = Value(purpose),
       succeeded = Value(succeeded);
  static Insertable<AiCall> custom({
    Expression<int>? id,
    Expression<int>? day,
    Expression<String>? at,
    Expression<String>? model,
    Expression<String>? purpose,
    Expression<bool>? succeeded,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (at != null) 'at': at,
      if (model != null) 'model': model,
      if (purpose != null) 'purpose': purpose,
      if (succeeded != null) 'succeeded': succeeded,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (error != null) 'error': error,
    });
  }

  AiCallsCompanion copyWith({
    Value<int>? id,
    Value<Day>? day,
    Value<String>? at,
    Value<String>? model,
    Value<AiPurpose>? purpose,
    Value<bool>? succeeded,
    Value<int?>? promptTokens,
    Value<int?>? completionTokens,
    Value<String?>? error,
  }) {
    return AiCallsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      at: at ?? this.at,
      model: model ?? this.model,
      purpose: purpose ?? this.purpose,
      succeeded: succeeded ?? this.succeeded,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<int>($AiCallsTable.$converterday.toSql(day.value));
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(
        $AiCallsTable.$converterpurpose.toSql(purpose.value),
      );
    }
    if (succeeded.present) {
      map['succeeded'] = Variable<bool>(succeeded.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiCallsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('at: $at, ')
          ..write('model: $model, ')
          ..write('purpose: $purpose, ')
          ..write('succeeded: $succeeded, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, Achievement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Day?, int> weekStart =
      GeneratedColumn<int>(
        'week_start',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Day?>($AchievementsTable.$converterweekStartn);
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<String> unlockedAt = GeneratedColumn<String>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, weekStart, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Achievement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {code, weekStart},
  ];
  @override
  Achievement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Achievement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      weekStart: $AchievementsTable.$converterweekStartn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}week_start'],
        ),
      ),
      unlockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unlocked_at'],
      )!,
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }

  static TypeConverter<Day, int> $converterweekStart = const DayConverter();
  static TypeConverter<Day?, int?> $converterweekStartn =
      NullAwareTypeConverter.wrap($converterweekStart);
}

class Achievement extends DataClass implements Insertable<Achievement> {
  final int id;

  /// Stable identifier for the achievement definition.
  final String code;

  /// The week that earned it, if it was a weekly award.
  final Day? weekStart;
  final String unlockedAt;
  const Achievement({
    required this.id,
    required this.code,
    this.weekStart,
    required this.unlockedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || weekStart != null) {
      map['week_start'] = Variable<int>(
        $AchievementsTable.$converterweekStartn.toSql(weekStart),
      );
    }
    map['unlocked_at'] = Variable<String>(unlockedAt);
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      id: Value(id),
      code: Value(code),
      weekStart: weekStart == null && nullToAbsent
          ? const Value.absent()
          : Value(weekStart),
      unlockedAt: Value(unlockedAt),
    );
  }

  factory Achievement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Achievement(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      weekStart: serializer.fromJson<Day?>(json['weekStart']),
      unlockedAt: serializer.fromJson<String>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'weekStart': serializer.toJson<Day?>(weekStart),
      'unlockedAt': serializer.toJson<String>(unlockedAt),
    };
  }

  Achievement copyWith({
    int? id,
    String? code,
    Value<Day?> weekStart = const Value.absent(),
    String? unlockedAt,
  }) => Achievement(
    id: id ?? this.id,
    code: code ?? this.code,
    weekStart: weekStart.present ? weekStart.value : this.weekStart,
    unlockedAt: unlockedAt ?? this.unlockedAt,
  );
  Achievement copyWithCompanion(AchievementsCompanion data) {
    return Achievement(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      unlockedAt: data.unlockedAt.present
          ? data.unlockedAt.value
          : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Achievement(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('weekStart: $weekStart, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, weekStart, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Achievement &&
          other.id == this.id &&
          other.code == this.code &&
          other.weekStart == this.weekStart &&
          other.unlockedAt == this.unlockedAt);
}

class AchievementsCompanion extends UpdateCompanion<Achievement> {
  final Value<int> id;
  final Value<String> code;
  final Value<Day?> weekStart;
  final Value<String> unlockedAt;
  const AchievementsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.unlockedAt = const Value.absent(),
  });
  AchievementsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    this.weekStart = const Value.absent(),
    required String unlockedAt,
  }) : code = Value(code),
       unlockedAt = Value(unlockedAt);
  static Insertable<Achievement> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<int>? weekStart,
    Expression<String>? unlockedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (weekStart != null) 'week_start': weekStart,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
    });
  }

  AchievementsCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<Day?>? weekStart,
    Value<String>? unlockedAt,
  }) {
    return AchievementsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      weekStart: weekStart ?? this.weekStart,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<int>(
        $AchievementsTable.$converterweekStartn.toSql(weekStart.value),
      );
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<String>(unlockedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('weekStart: $weekStart, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $ActivityDaysTable activityDays = $ActivityDaysTable(this);
  late final $WeightsTable weights = $WeightsTable(this);
  late final $WaterLogsTable waterLogs = $WaterLogsTable(this);
  late final $WeeksTable weeks = $WeeksTable(this);
  late final $AiCallsTable aiCalls = $AiCallsTable(this);
  late final $AchievementsTable achievements = $AchievementsTable(this);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final FoodsDao foodsDao = FoodsDao(this as AppDatabase);
  late final JournalDao journalDao = JournalDao(this as AppDatabase);
  late final TrackingDao trackingDao = TrackingDao(this as AppDatabase);
  late final WeeksDao weeksDao = WeeksDao(this as AppDatabase);
  late final AiCallsDao aiCallsDao = AiCallsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    foods,
    entries,
    activityDays,
    weights,
    waterLogs,
    weeks,
    aiCalls,
    achievements,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      required Sex sex,
      required int birthYear,
      required double heightCm,
      required ActivityLevel activityLevel,
      required Goal goal,
      Value<double?> targetWeightKg,
      Value<int> weekEndsOn,
      Value<double> strideCm,
      Value<int> dailyStepGoal,
      required String createdAt,
      required String updatedAt,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<Sex> sex,
      Value<int> birthYear,
      Value<double> heightCm,
      Value<ActivityLevel> activityLevel,
      Value<Goal> goal,
      Value<double?> targetWeightKg,
      Value<int> weekEndsOn,
      Value<double> strideCm,
      Value<int> dailyStepGoal,
      Value<String> createdAt,
      Value<String> updatedAt,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Sex, Sex, String> get sex =>
      $composableBuilder(
        column: $table.sex,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ActivityLevel, ActivityLevel, String>
  get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Goal, Goal, String> get goal =>
      $composableBuilder(
        column: $table.goal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekEndsOn => $composableBuilder(
    column: $table.weekEndsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strideCm => $composableBuilder(
    column: $table.strideCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyStepGoal => $composableBuilder(
    column: $table.dailyStepGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekEndsOn => $composableBuilder(
    column: $table.weekEndsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strideCm => $composableBuilder(
    column: $table.strideCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyStepGoal => $composableBuilder(
    column: $table.dailyStepGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Sex, String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ActivityLevel, String> get activityLevel =>
      $composableBuilder(
        column: $table.activityLevel,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Goal, String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekEndsOn => $composableBuilder(
    column: $table.weekEndsOn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get strideCm =>
      $composableBuilder(column: $table.strideCm, builder: (column) => column);

  GeneratedColumn<int> get dailyStepGoal => $composableBuilder(
    column: $table.dailyStepGoal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Sex> sex = const Value.absent(),
                Value<int> birthYear = const Value.absent(),
                Value<double> heightCm = const Value.absent(),
                Value<ActivityLevel> activityLevel = const Value.absent(),
                Value<Goal> goal = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int> weekEndsOn = const Value.absent(),
                Value<double> strideCm = const Value.absent(),
                Value<int> dailyStepGoal = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                sex: sex,
                birthYear: birthYear,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goal: goal,
                targetWeightKg: targetWeightKg,
                weekEndsOn: weekEndsOn,
                strideCm: strideCm,
                dailyStepGoal: dailyStepGoal,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Sex sex,
                required int birthYear,
                required double heightCm,
                required ActivityLevel activityLevel,
                required Goal goal,
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int> weekEndsOn = const Value.absent(),
                Value<double> strideCm = const Value.absent(),
                Value<int> dailyStepGoal = const Value.absent(),
                required String createdAt,
                required String updatedAt,
              }) => ProfilesCompanion.insert(
                id: id,
                sex: sex,
                birthYear: birthYear,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goal: goal,
                targetWeightKg: targetWeightKg,
                weekEndsOn: weekEndsOn,
                strideCm: strideCm,
                dailyStepGoal: dailyStepGoal,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$FoodsTableCreateCompanionBuilder =
    FoodsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> brand,
      Value<String?> barcode,
      required String searchKey,
      required double kcal,
      Value<double> proteinG,
      Value<double> carbsG,
      Value<double> sugarG,
      Value<double?> addedSugarG,
      Value<double> fatG,
      Value<double> satFatG,
      Value<double?> transFatG,
      Value<double> fibreG,
      Value<double> sodiumMg,
      Value<double> alcoholG,
      Value<int?> glycemicIndex,
      Value<int?> novaGroup,
      Value<String?> additivesJson,
      Value<double?> gramsPerPiece,
      Value<String?> pieceName,
      required FoodSource source,
      Value<double> confidence,
      Value<String?> imagePath,
      required String createdAt,
      required String updatedAt,
    });
typedef $$FoodsTableUpdateCompanionBuilder =
    FoodsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> brand,
      Value<String?> barcode,
      Value<String> searchKey,
      Value<double> kcal,
      Value<double> proteinG,
      Value<double> carbsG,
      Value<double> sugarG,
      Value<double?> addedSugarG,
      Value<double> fatG,
      Value<double> satFatG,
      Value<double?> transFatG,
      Value<double> fibreG,
      Value<double> sodiumMg,
      Value<double> alcoholG,
      Value<int?> glycemicIndex,
      Value<int?> novaGroup,
      Value<String?> additivesJson,
      Value<double?> gramsPerPiece,
      Value<String?> pieceName,
      Value<FoodSource> source,
      Value<double> confidence,
      Value<String?> imagePath,
      Value<String> createdAt,
      Value<String> updatedAt,
    });

final class $$FoodsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodsTable, Food> {
  $$FoodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'foods__id__entries__food_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodsTableFilterComposer extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get addedSugarG => $composableBuilder(
    column: $table.addedSugarG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get satFatG => $composableBuilder(
    column: $table.satFatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get transFatG => $composableBuilder(
    column: $table.transFatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fibreG => $composableBuilder(
    column: $table.fibreG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get alcoholG => $composableBuilder(
    column: $table.alcoholG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get glycemicIndex => $composableBuilder(
    column: $table.glycemicIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get novaGroup => $composableBuilder(
    column: $table.novaGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get additivesJson => $composableBuilder(
    column: $table.additivesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gramsPerPiece => $composableBuilder(
    column: $table.gramsPerPiece,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceName => $composableBuilder(
    column: $table.pieceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FoodSource, FoodSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get addedSugarG => $composableBuilder(
    column: $table.addedSugarG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get satFatG => $composableBuilder(
    column: $table.satFatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get transFatG => $composableBuilder(
    column: $table.transFatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fibreG => $composableBuilder(
    column: $table.fibreG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get alcoholG => $composableBuilder(
    column: $table.alcoholG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get glycemicIndex => $composableBuilder(
    column: $table.glycemicIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get novaGroup => $composableBuilder(
    column: $table.novaGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get additivesJson => $composableBuilder(
    column: $table.additivesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gramsPerPiece => $composableBuilder(
    column: $table.gramsPerPiece,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceName => $composableBuilder(
    column: $table.pieceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get searchKey =>
      $composableBuilder(column: $table.searchKey, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get carbsG =>
      $composableBuilder(column: $table.carbsG, builder: (column) => column);

  GeneratedColumn<double> get sugarG =>
      $composableBuilder(column: $table.sugarG, builder: (column) => column);

  GeneratedColumn<double> get addedSugarG => $composableBuilder(
    column: $table.addedSugarG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get satFatG =>
      $composableBuilder(column: $table.satFatG, builder: (column) => column);

  GeneratedColumn<double> get transFatG =>
      $composableBuilder(column: $table.transFatG, builder: (column) => column);

  GeneratedColumn<double> get fibreG =>
      $composableBuilder(column: $table.fibreG, builder: (column) => column);

  GeneratedColumn<double> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<double> get alcoholG =>
      $composableBuilder(column: $table.alcoholG, builder: (column) => column);

  GeneratedColumn<int> get glycemicIndex => $composableBuilder(
    column: $table.glycemicIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get novaGroup =>
      $composableBuilder(column: $table.novaGroup, builder: (column) => column);

  GeneratedColumn<String> get additivesJson => $composableBuilder(
    column: $table.additivesJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gramsPerPiece => $composableBuilder(
    column: $table.gramsPerPiece,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pieceName =>
      $composableBuilder(column: $table.pieceName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FoodSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTable,
          Food,
          $$FoodsTableFilterComposer,
          $$FoodsTableOrderingComposer,
          $$FoodsTableAnnotationComposer,
          $$FoodsTableCreateCompanionBuilder,
          $$FoodsTableUpdateCompanionBuilder,
          (Food, $$FoodsTableReferences),
          Food,
          PrefetchHooks Function({bool entriesRefs})
        > {
  $$FoodsTableTableManager(_$AppDatabase db, $FoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> searchKey = const Value.absent(),
                Value<double> kcal = const Value.absent(),
                Value<double> proteinG = const Value.absent(),
                Value<double> carbsG = const Value.absent(),
                Value<double> sugarG = const Value.absent(),
                Value<double?> addedSugarG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<double> satFatG = const Value.absent(),
                Value<double?> transFatG = const Value.absent(),
                Value<double> fibreG = const Value.absent(),
                Value<double> sodiumMg = const Value.absent(),
                Value<double> alcoholG = const Value.absent(),
                Value<int?> glycemicIndex = const Value.absent(),
                Value<int?> novaGroup = const Value.absent(),
                Value<String?> additivesJson = const Value.absent(),
                Value<double?> gramsPerPiece = const Value.absent(),
                Value<String?> pieceName = const Value.absent(),
                Value<FoodSource> source = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
              }) => FoodsCompanion(
                id: id,
                name: name,
                brand: brand,
                barcode: barcode,
                searchKey: searchKey,
                kcal: kcal,
                proteinG: proteinG,
                carbsG: carbsG,
                sugarG: sugarG,
                addedSugarG: addedSugarG,
                fatG: fatG,
                satFatG: satFatG,
                transFatG: transFatG,
                fibreG: fibreG,
                sodiumMg: sodiumMg,
                alcoholG: alcoholG,
                glycemicIndex: glycemicIndex,
                novaGroup: novaGroup,
                additivesJson: additivesJson,
                gramsPerPiece: gramsPerPiece,
                pieceName: pieceName,
                source: source,
                confidence: confidence,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                required String searchKey,
                required double kcal,
                Value<double> proteinG = const Value.absent(),
                Value<double> carbsG = const Value.absent(),
                Value<double> sugarG = const Value.absent(),
                Value<double?> addedSugarG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<double> satFatG = const Value.absent(),
                Value<double?> transFatG = const Value.absent(),
                Value<double> fibreG = const Value.absent(),
                Value<double> sodiumMg = const Value.absent(),
                Value<double> alcoholG = const Value.absent(),
                Value<int?> glycemicIndex = const Value.absent(),
                Value<int?> novaGroup = const Value.absent(),
                Value<String?> additivesJson = const Value.absent(),
                Value<double?> gramsPerPiece = const Value.absent(),
                Value<String?> pieceName = const Value.absent(),
                required FoodSource source,
                Value<double> confidence = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                required String createdAt,
                required String updatedAt,
              }) => FoodsCompanion.insert(
                id: id,
                name: name,
                brand: brand,
                barcode: barcode,
                searchKey: searchKey,
                kcal: kcal,
                proteinG: proteinG,
                carbsG: carbsG,
                sugarG: sugarG,
                addedSugarG: addedSugarG,
                fatG: fatG,
                satFatG: satFatG,
                transFatG: transFatG,
                fibreG: fibreG,
                sodiumMg: sodiumMg,
                alcoholG: alcoholG,
                glycemicIndex: glycemicIndex,
                novaGroup: novaGroup,
                additivesJson: additivesJson,
                gramsPerPiece: gramsPerPiece,
                pieceName: pieceName,
                source: source,
                confidence: confidence,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FoodsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<Food, $FoodsTable, Entry>(
                      currentTable: table,
                      referencedTable: $$FoodsTableReferences._entriesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$FoodsTableReferences(db, table, p0).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.foodId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTable,
      Food,
      $$FoodsTableFilterComposer,
      $$FoodsTableOrderingComposer,
      $$FoodsTableAnnotationComposer,
      $$FoodsTableCreateCompanionBuilder,
      $$FoodsTableUpdateCompanionBuilder,
      (Food, $$FoodsTableReferences),
      Food,
      PrefetchHooks Function({bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      required int foodId,
      required Day day,
      required MealSlot mealSlot,
      required double quantity,
      required String unit,
      required double grams,
      Value<String?> rawText,
      Value<String?> photoPath,
      Value<double> confidence,
      required String createdAt,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      Value<int> foodId,
      Value<Day> day,
      Value<MealSlot> mealSlot,
      Value<double> quantity,
      Value<String> unit,
      Value<double> grams,
      Value<String?> rawText,
      Value<String?> photoPath,
      Value<double> confidence,
      Value<String> createdAt,
    });

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('entries__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day, Day, int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<MealSlot, MealSlot, String> get mealSlot =>
      $composableBuilder(
        column: $table.mealSlot,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealSlot => $composableBuilder(
    column: $table.mealSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MealSlot, String> get mealSlot =>
      $composableBuilder(column: $table.mealSlot, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, $$EntriesTableReferences),
          Entry,
          PrefetchHooks Function({bool foodId})
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<Day> day = const Value.absent(),
                Value<MealSlot> mealSlot = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> grams = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                foodId: foodId,
                day: day,
                mealSlot: mealSlot,
                quantity: quantity,
                unit: unit,
                grams: grams,
                rawText: rawText,
                photoPath: photoPath,
                confidence: confidence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int foodId,
                required Day day,
                required MealSlot mealSlot,
                required double quantity,
                required String unit,
                required double grams,
                Value<String?> rawText = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                required String createdAt,
              }) => EntriesCompanion.insert(
                id: id,
                foodId: foodId,
                day: day,
                mealSlot: mealSlot,
                quantity: quantity,
                unit: unit,
                grams: grams,
                rawText: rawText,
                photoPath: photoPath,
                confidence: confidence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodId,
                                referencedTable: $$EntriesTableReferences
                                    ._foodIdTable(db),
                                referencedColumn: $$EntriesTableReferences
                                    ._foodIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, $$EntriesTableReferences),
      Entry,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$ActivityDaysTableCreateCompanionBuilder =
    ActivityDaysCompanion Function({
      required Day day,
      Value<int> steps,
      Value<double> distanceM,
      Value<double?> activeKcal,
      required ActivitySource source,
      required String updatedAt,
    });
typedef $$ActivityDaysTableUpdateCompanionBuilder =
    ActivityDaysCompanion Function({
      Value<Day> day,
      Value<int> steps,
      Value<double> distanceM,
      Value<double?> activeKcal,
      Value<ActivitySource> source,
      Value<String> updatedAt,
    });

class $$ActivityDaysTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<Day, Day, int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get activeKcal => $composableBuilder(
    column: $table.activeKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ActivitySource, ActivitySource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get activeKcal => $composableBuilder(
    column: $table.activeKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<Day, int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get activeKcal => $composableBuilder(
    column: $table.activeKcal,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ActivitySource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActivityDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityDaysTable,
          ActivityDay,
          $$ActivityDaysTableFilterComposer,
          $$ActivityDaysTableOrderingComposer,
          $$ActivityDaysTableAnnotationComposer,
          $$ActivityDaysTableCreateCompanionBuilder,
          $$ActivityDaysTableUpdateCompanionBuilder,
          (
            ActivityDay,
            BaseReferences<_$AppDatabase, $ActivityDaysTable, ActivityDay>,
          ),
          ActivityDay,
          PrefetchHooks Function()
        > {
  $$ActivityDaysTableTableManager(_$AppDatabase db, $ActivityDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Day> day = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<double?> activeKcal = const Value.absent(),
                Value<ActivitySource> source = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
              }) => ActivityDaysCompanion(
                day: day,
                steps: steps,
                distanceM: distanceM,
                activeKcal: activeKcal,
                source: source,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required Day day,
                Value<int> steps = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<double?> activeKcal = const Value.absent(),
                required ActivitySource source,
                required String updatedAt,
              }) => ActivityDaysCompanion.insert(
                day: day,
                steps: steps,
                distanceM: distanceM,
                activeKcal: activeKcal,
                source: source,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityDaysTable,
      ActivityDay,
      $$ActivityDaysTableFilterComposer,
      $$ActivityDaysTableOrderingComposer,
      $$ActivityDaysTableAnnotationComposer,
      $$ActivityDaysTableCreateCompanionBuilder,
      $$ActivityDaysTableUpdateCompanionBuilder,
      (
        ActivityDay,
        BaseReferences<_$AppDatabase, $ActivityDaysTable, ActivityDay>,
      ),
      ActivityDay,
      PrefetchHooks Function()
    >;
typedef $$WeightsTableCreateCompanionBuilder =
    WeightsCompanion Function({
      required Day day,
      required double kg,
      required String createdAt,
    });
typedef $$WeightsTableUpdateCompanionBuilder =
    WeightsCompanion Function({
      Value<Day> day,
      Value<double> kg,
      Value<String> createdAt,
    });

class $$WeightsTableFilterComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<Day, Day, int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<Day, int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<double> get kg =>
      $composableBuilder(column: $table.kg, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WeightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightsTable,
          Weight,
          $$WeightsTableFilterComposer,
          $$WeightsTableOrderingComposer,
          $$WeightsTableAnnotationComposer,
          $$WeightsTableCreateCompanionBuilder,
          $$WeightsTableUpdateCompanionBuilder,
          (Weight, BaseReferences<_$AppDatabase, $WeightsTable, Weight>),
          Weight,
          PrefetchHooks Function()
        > {
  $$WeightsTableTableManager(_$AppDatabase db, $WeightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Day> day = const Value.absent(),
                Value<double> kg = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => WeightsCompanion(day: day, kg: kg, createdAt: createdAt),
          createCompanionCallback:
              ({
                required Day day,
                required double kg,
                required String createdAt,
              }) => WeightsCompanion.insert(
                day: day,
                kg: kg,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightsTable,
      Weight,
      $$WeightsTableFilterComposer,
      $$WeightsTableOrderingComposer,
      $$WeightsTableAnnotationComposer,
      $$WeightsTableCreateCompanionBuilder,
      $$WeightsTableUpdateCompanionBuilder,
      (Weight, BaseReferences<_$AppDatabase, $WeightsTable, Weight>),
      Weight,
      PrefetchHooks Function()
    >;
typedef $$WaterLogsTableCreateCompanionBuilder =
    WaterLogsCompanion Function({
      required Day day,
      Value<int> ml,
      required String updatedAt,
    });
typedef $$WaterLogsTableUpdateCompanionBuilder =
    WaterLogsCompanion Function({
      Value<Day> day,
      Value<int> ml,
      Value<String> updatedAt,
    });

class $$WaterLogsTableFilterComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<Day, Day, int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get ml => $composableBuilder(
    column: $table.ml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WaterLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ml => $composableBuilder(
    column: $table.ml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaterLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<Day, int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get ml =>
      $composableBuilder(column: $table.ml, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WaterLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterLogsTable,
          WaterLog,
          $$WaterLogsTableFilterComposer,
          $$WaterLogsTableOrderingComposer,
          $$WaterLogsTableAnnotationComposer,
          $$WaterLogsTableCreateCompanionBuilder,
          $$WaterLogsTableUpdateCompanionBuilder,
          (WaterLog, BaseReferences<_$AppDatabase, $WaterLogsTable, WaterLog>),
          WaterLog,
          PrefetchHooks Function()
        > {
  $$WaterLogsTableTableManager(_$AppDatabase db, $WaterLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Day> day = const Value.absent(),
                Value<int> ml = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
              }) => WaterLogsCompanion(day: day, ml: ml, updatedAt: updatedAt),
          createCompanionCallback:
              ({
                required Day day,
                Value<int> ml = const Value.absent(),
                required String updatedAt,
              }) => WaterLogsCompanion.insert(
                day: day,
                ml: ml,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WaterLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterLogsTable,
      WaterLog,
      $$WaterLogsTableFilterComposer,
      $$WaterLogsTableOrderingComposer,
      $$WaterLogsTableAnnotationComposer,
      $$WaterLogsTableCreateCompanionBuilder,
      $$WaterLogsTableUpdateCompanionBuilder,
      (WaterLog, BaseReferences<_$AppDatabase, $WaterLogsTable, WaterLog>),
      WaterLog,
      PrefetchHooks Function()
    >;
typedef $$WeeksTableCreateCompanionBuilder =
    WeeksCompanion Function({
      required Day weekStart,
      required Day weekEnd,
      Value<bool> revealed,
      Value<String?> summaryJson,
      Value<String?> narrative,
      Value<int> xpAwarded,
      required String createdAt,
    });
typedef $$WeeksTableUpdateCompanionBuilder =
    WeeksCompanion Function({
      Value<Day> weekStart,
      Value<Day> weekEnd,
      Value<bool> revealed,
      Value<String?> summaryJson,
      Value<String?> narrative,
      Value<int> xpAwarded,
      Value<String> createdAt,
    });

class $$WeeksTableFilterComposer extends Composer<_$AppDatabase, $WeeksTable> {
  $$WeeksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<Day, Day, int> get weekStart =>
      $composableBuilder(
        column: $table.weekStart,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Day, Day, int> get weekEnd =>
      $composableBuilder(
        column: $table.weekEnd,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xpAwarded => $composableBuilder(
    column: $table.xpAwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeksTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeksTable> {
  $$WeeksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekEnd => $composableBuilder(
    column: $table.weekEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xpAwarded => $composableBuilder(
    column: $table.xpAwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeksTable> {
  $$WeeksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<Day, int> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, int> get weekEnd =>
      $composableBuilder(column: $table.weekEnd, builder: (column) => column);

  GeneratedColumn<bool> get revealed =>
      $composableBuilder(column: $table.revealed, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get narrative =>
      $composableBuilder(column: $table.narrative, builder: (column) => column);

  GeneratedColumn<int> get xpAwarded =>
      $composableBuilder(column: $table.xpAwarded, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WeeksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeksTable,
          Week,
          $$WeeksTableFilterComposer,
          $$WeeksTableOrderingComposer,
          $$WeeksTableAnnotationComposer,
          $$WeeksTableCreateCompanionBuilder,
          $$WeeksTableUpdateCompanionBuilder,
          (Week, BaseReferences<_$AppDatabase, $WeeksTable, Week>),
          Week,
          PrefetchHooks Function()
        > {
  $$WeeksTableTableManager(_$AppDatabase db, $WeeksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Day> weekStart = const Value.absent(),
                Value<Day> weekEnd = const Value.absent(),
                Value<bool> revealed = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> narrative = const Value.absent(),
                Value<int> xpAwarded = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => WeeksCompanion(
                weekStart: weekStart,
                weekEnd: weekEnd,
                revealed: revealed,
                summaryJson: summaryJson,
                narrative: narrative,
                xpAwarded: xpAwarded,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                required Day weekStart,
                required Day weekEnd,
                Value<bool> revealed = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> narrative = const Value.absent(),
                Value<int> xpAwarded = const Value.absent(),
                required String createdAt,
              }) => WeeksCompanion.insert(
                weekStart: weekStart,
                weekEnd: weekEnd,
                revealed: revealed,
                summaryJson: summaryJson,
                narrative: narrative,
                xpAwarded: xpAwarded,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeksTable,
      Week,
      $$WeeksTableFilterComposer,
      $$WeeksTableOrderingComposer,
      $$WeeksTableAnnotationComposer,
      $$WeeksTableCreateCompanionBuilder,
      $$WeeksTableUpdateCompanionBuilder,
      (Week, BaseReferences<_$AppDatabase, $WeeksTable, Week>),
      Week,
      PrefetchHooks Function()
    >;
typedef $$AiCallsTableCreateCompanionBuilder =
    AiCallsCompanion Function({
      Value<int> id,
      required Day day,
      required String at,
      required String model,
      required AiPurpose purpose,
      required bool succeeded,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<String?> error,
    });
typedef $$AiCallsTableUpdateCompanionBuilder =
    AiCallsCompanion Function({
      Value<int> id,
      Value<Day> day,
      Value<String> at,
      Value<String> model,
      Value<AiPurpose> purpose,
      Value<bool> succeeded,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<String?> error,
    });

class $$AiCallsTableFilterComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day, Day, int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AiPurpose, AiPurpose, String> get purpose =>
      $composableBuilder(
        column: $table.purpose,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get succeeded => $composableBuilder(
    column: $table.succeeded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiCallsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get succeeded => $composableBuilder(
    column: $table.succeeded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiCallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AiPurpose, String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<bool> get succeeded =>
      $composableBuilder(column: $table.succeeded, builder: (column) => column);

  GeneratedColumn<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$AiCallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiCallsTable,
          AiCall,
          $$AiCallsTableFilterComposer,
          $$AiCallsTableOrderingComposer,
          $$AiCallsTableAnnotationComposer,
          $$AiCallsTableCreateCompanionBuilder,
          $$AiCallsTableUpdateCompanionBuilder,
          (AiCall, BaseReferences<_$AppDatabase, $AiCallsTable, AiCall>),
          AiCall,
          PrefetchHooks Function()
        > {
  $$AiCallsTableTableManager(_$AppDatabase db, $AiCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Day> day = const Value.absent(),
                Value<String> at = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<AiPurpose> purpose = const Value.absent(),
                Value<bool> succeeded = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => AiCallsCompanion(
                id: id,
                day: day,
                at: at,
                model: model,
                purpose: purpose,
                succeeded: succeeded,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Day day,
                required String at,
                required String model,
                required AiPurpose purpose,
                required bool succeeded,
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => AiCallsCompanion.insert(
                id: id,
                day: day,
                at: at,
                model: model,
                purpose: purpose,
                succeeded: succeeded,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiCallsTable,
      AiCall,
      $$AiCallsTableFilterComposer,
      $$AiCallsTableOrderingComposer,
      $$AiCallsTableAnnotationComposer,
      $$AiCallsTableCreateCompanionBuilder,
      $$AiCallsTableUpdateCompanionBuilder,
      (AiCall, BaseReferences<_$AppDatabase, $AiCallsTable, AiCall>),
      AiCall,
      PrefetchHooks Function()
    >;
typedef $$AchievementsTableCreateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      required String code,
      Value<Day?> weekStart,
      required String unlockedAt,
    });
typedef $$AchievementsTableUpdateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<Day?> weekStart,
      Value<String> unlockedAt,
    });

class $$AchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day?, Day, int> get weekStart =>
      $composableBuilder(
        column: $table.weekStart,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day?, int> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<String> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );
}

class $$AchievementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AchievementsTable,
          Achievement,
          $$AchievementsTableFilterComposer,
          $$AchievementsTableOrderingComposer,
          $$AchievementsTableAnnotationComposer,
          $$AchievementsTableCreateCompanionBuilder,
          $$AchievementsTableUpdateCompanionBuilder,
          (
            Achievement,
            BaseReferences<_$AppDatabase, $AchievementsTable, Achievement>,
          ),
          Achievement,
          PrefetchHooks Function()
        > {
  $$AchievementsTableTableManager(_$AppDatabase db, $AchievementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<Day?> weekStart = const Value.absent(),
                Value<String> unlockedAt = const Value.absent(),
              }) => AchievementsCompanion(
                id: id,
                code: code,
                weekStart: weekStart,
                unlockedAt: unlockedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                Value<Day?> weekStart = const Value.absent(),
                required String unlockedAt,
              }) => AchievementsCompanion.insert(
                id: id,
                code: code,
                weekStart: weekStart,
                unlockedAt: unlockedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AchievementsTable,
      Achievement,
      $$AchievementsTableFilterComposer,
      $$AchievementsTableOrderingComposer,
      $$AchievementsTableAnnotationComposer,
      $$AchievementsTableCreateCompanionBuilder,
      $$AchievementsTableUpdateCompanionBuilder,
      (
        Achievement,
        BaseReferences<_$AppDatabase, $AchievementsTable, Achievement>,
      ),
      Achievement,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$ActivityDaysTableTableManager get activityDays =>
      $$ActivityDaysTableTableManager(_db, _db.activityDays);
  $$WeightsTableTableManager get weights =>
      $$WeightsTableTableManager(_db, _db.weights);
  $$WaterLogsTableTableManager get waterLogs =>
      $$WaterLogsTableTableManager(_db, _db.waterLogs);
  $$WeeksTableTableManager get weeks =>
      $$WeeksTableTableManager(_db, _db.weeks);
  $$AiCallsTableTableManager get aiCalls =>
      $$AiCallsTableTableManager(_db, _db.aiCalls);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
}
