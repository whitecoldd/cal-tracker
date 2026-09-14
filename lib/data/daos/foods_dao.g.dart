// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foods_dao.dart';

// ignore_for_file: type=lint
mixin _$FoodsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FoodsTable get foods => attachedDatabase.foods;
  FoodsDaoManager get managers => FoodsDaoManager(this);
}

class FoodsDaoManager {
  final _$FoodsDaoMixin _db;
  FoodsDaoManager(this._db);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db.attachedDatabase, _db.foods);
}
