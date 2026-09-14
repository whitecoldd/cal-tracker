// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_calls_dao.dart';

// ignore_for_file: type=lint
mixin _$AiCallsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AiCallsTable get aiCalls => attachedDatabase.aiCalls;
  AiCallsDaoManager get managers => AiCallsDaoManager(this);
}

class AiCallsDaoManager {
  final _$AiCallsDaoMixin _db;
  AiCallsDaoManager(this._db);
  $$AiCallsTableTableManager get aiCalls =>
      $$AiCallsTableTableManager(_db.attachedDatabase, _db.aiCalls);
}
