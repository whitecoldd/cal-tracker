// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weeks_dao.dart';

// ignore_for_file: type=lint
mixin _$WeeksDaoMixin on DatabaseAccessor<AppDatabase> {
  $WeeksTable get weeks => attachedDatabase.weeks;
  $AchievementsTable get achievements => attachedDatabase.achievements;
  WeeksDaoManager get managers => WeeksDaoManager(this);
}

class WeeksDaoManager {
  final _$WeeksDaoMixin _db;
  WeeksDaoManager(this._db);
  $$WeeksTableTableManager get weeks =>
      $$WeeksTableTableManager(_db.attachedDatabase, _db.weeks);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db.attachedDatabase, _db.achievements);
}
