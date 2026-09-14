// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackingDaoMixin on DatabaseAccessor<AppDatabase> {
  $ActivityDaysTable get activityDays => attachedDatabase.activityDays;
  $WeightsTable get weights => attachedDatabase.weights;
  $WaterLogsTable get waterLogs => attachedDatabase.waterLogs;
  TrackingDaoManager get managers => TrackingDaoManager(this);
}

class TrackingDaoManager {
  final _$TrackingDaoMixin _db;
  TrackingDaoManager(this._db);
  $$ActivityDaysTableTableManager get activityDays =>
      $$ActivityDaysTableTableManager(_db.attachedDatabase, _db.activityDays);
  $$WeightsTableTableManager get weights =>
      $$WeightsTableTableManager(_db.attachedDatabase, _db.weights);
  $$WaterLogsTableTableManager get waterLogs =>
      $$WaterLogsTableTableManager(_db.attachedDatabase, _db.waterLogs);
}
