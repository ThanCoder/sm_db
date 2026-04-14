import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/json_record.dart';
import 'package:sm_db/src/utils/json_db_adapter.dart';

class JsonDBBox<T> {
  final IndexedDB _indexedDB;
  final JsonDBAdapter<T> _adapter;

  const JsonDBBox({
    required IndexedDB indexedDB,
    required JsonDBAdapter<T> adapter,
  }) : _indexedDB = indexedDB,
       _adapter = adapter;

  /// ### Add in `Box<T>`
  ///
  /// Return T? `[addedValue]`
  ///
  /// `parentId ?? JsonDBAdapter.getParentId(T value)`
  ///
  /// ```dart
  /// abstract class JsonDBAdapter<T>
  ///   int getParentId(T value) => -1; <--- Need To Override
  ///
  ///```

  Future<T?> add(T value, {int? parentId}) async {
    final id = _indexedDB.generateNextId();
    final map = _adapter.toMap(value);
    map['id'] = id;

    final (record, bool) = await _indexedDB.db.addRecord(
      JsonRecord(
        id: id,
        jsonBytes: _adapter.encodeData(map),
        adapterTypeId: _adapter.getUniqueFieldId,
        parentId: parentId ?? _adapter.getParentId(value),
      ),
    );

    return bool ? _adapter.fromMap(map) : null;
  }

  ///
  /// ### Remove Record  in `Box<T>`
  ///
  Future<bool> deleteById(
    int id, {
    bool willDeleteByParentRecord = false,
    bool willDeleteByChildRecord = false,
    bool willThrowExceptionByNotFoundId = true,
  }) async {
    final boxList = <JsonRecord>[];
    for (var rec in _indexedDB.allActiveRecordList.toList()) {
      if (rec.type != RecordType.json) continue;
      // filter current box type
      final jRec = rec as JsonRecord;
      if (jRec.adapterTypeId != _adapter.getUniqueFieldId) continue;
      boxList.add(jRec);
    }

    final index = boxList.indexWhere((e) => e.id == id);
    if (index == -1 && willThrowExceptionByNotFoundId) {
      throw Exception('Not Found ID:`$id` In Box<$T> List');
    } else if (index == -1) {
      return false;
    }
    // delete
    final record = boxList[index];

    final isDeleted = await _indexedDB.db.removeRecord(record);
    // print('rec isDeleted: $isDeleted');

    // will delete parent record
    if (isDeleted && willDeleteByParentRecord) {
      for (var parent in _indexedDB.allActiveRecordList.toList()) {
        if (parent.type != RecordType.json ||
            parent.id == -1 ||
            (parent as JsonRecord).id != record.parentId) {
          continue;
        }
        await _indexedDB.db.removeRecord(parent, isCallMabyCompact: false);
      }
    }
    // will delete child record
    if (isDeleted && willDeleteByChildRecord) {
      for (var child in _indexedDB.allActiveRecordList.toList()) {
        if (child.type != RecordType.json ||
            child.id == -1 ||
            (child as JsonRecord).parentId != record.id) {
          continue;
        }
        await _indexedDB.db.removeRecord(child, isCallMabyCompact: false);
      }
    }
    return isDeleted;
  }

  ///
  /// ### Delete All in `Box<T>`
  ///
  Future<bool> deleteAll() async {
    final list = <JsonRecord>[];
    for (var rec in _indexedDB.allActiveRecordList) {
      if (rec.type != RecordType.json) continue;
      final jRec = rec as JsonRecord;
      // filter field id
      if (jRec.adapterTypeId != _adapter.getUniqueFieldId) continue;
      list.add(jRec);
    }
    return await _indexedDB.db.removeMultiRecord(list);
  }

  ///
  /// ### Get By Id in `Box<T>`
  ///
  Future<T?> getById(int id) async {
    final res = await _indexedDB.db.getById(id);
    if (res == null) return null;
    if (res.type != RecordType.json) return null;
    final raf = await _indexedDB.dbFile.open();
    final data = await (res as JsonRecord).getJsonData(raf);
    await raf.close();
    if (data == null) return null;
    return _adapter.fromMap(_adapter.decodeData(data));
  }

  ///
  /// ### Update By Id in `Box<T>`
  ///
  /// Return `newValue`
  ///
  Future<T?> updateById(int id, {required T value}) async {
    final addedValue = await getById(id);
    if (addedValue != null) {
      // delete
      await deleteById(_adapter.getId(addedValue));
    }
    //update
    return await add(value);
  }

  ///
  /// ### Update One in `Box<T>`
  ///
  /// Return `newValue`
  ///
  Future<T?> updateOne(bool Function(T value) test, {required T value}) async {
    final addedValue = await getOne(test);
    if (addedValue != null) {
      // delete
      await deleteById(_adapter.getId(addedValue));
    }
    //update
    return await add(value);
  }

  ///
  /// ### Get By Parent Id in `Box<T>`
  ///
  Future<T?> getByParentId(int parentId) async {
    for (var record in _indexedDB.allActiveRecordList) {
      if (record.type != RecordType.json) continue;
      final jsonRec = (record as JsonRecord);
      if (jsonRec.parentId == parentId) {
        // read json data
        final raf = await _indexedDB.dbFile.open();
        final data = await jsonRec.getJsonData(raf);
        await raf.close();
        if (data == null) continue;
        return _adapter.fromMap(_adapter.decodeData(data));
      }
    }
    return null;
  }

  ///
  /// ### Get List By Parent Id in `Box<T>`
  ///
  Future<List<T>> getListByParentId(int parentId) async {
    List<T> results = [];
    for (var record in _indexedDB.allActiveRecordList) {
      if (record.type != RecordType.json) continue;
      final jsonRec = (record as JsonRecord);
      if (jsonRec.parentId == parentId) {
        // read json data
        final raf = await _indexedDB.dbFile.open();
        final data = await jsonRec.getJsonData(raf);
        await raf.close();
        if (data == null) continue;
        final value = _adapter.fromMap(_adapter.decodeData(data));
        results.add(value);
      }
    }
    return results;
  }

  ///
  /// ### Get All in `Box<T>`
  ///
  Future<List<T>> getAll({int? parentId}) async {
    final res = await _indexedDB.db.readAll();
    // print('box list: $res');
    List<T> list = [];
    for (var record in res) {
      // json ပဲရယူမယ်
      if (record.status == RecordStatus.delete ||
          record.type != RecordType.json) {
        continue;
      }
      final jsr = record as JsonRecord;
      // print(jsr.toJson());

      if (jsr.adapterTypeId != _adapter.getUniqueFieldId) continue;
      // filter parent Id
      if (parentId != null && jsr.parentId != -1 && jsr.parentId != parentId) {
        continue;
      }
      // read json data
      final raf = await _indexedDB.dbFile.open();
      final data = await jsr.getJsonData(raf);
      await raf.close();
      if (data == null) continue;
      //add
      list.add(_adapter.fromMap(_adapter.decodeData(data)));
    }
    return list;
  }

  ///
  /// ### Get All With Stream in `Box<T>`
  ///
  Stream<T> getAllStream({int? parentId}) async* {
    final res = await _indexedDB.db.readAll();
    for (var record in res) {
      // json ပဲရယူမယ်
      if (record.status == RecordStatus.delete ||
          record.type != RecordType.json) {
        continue;
      }
      final jsr = record as JsonRecord;
      if (jsr.adapterTypeId != _adapter.getUniqueFieldId) continue;
      // filter parent Id
      if (parentId != null && jsr.parentId != parentId) continue;
      // read json data
      final raf = await _indexedDB.dbFile.open();
      final data = await jsr.getJsonData(raf);
      await raf.close();
      if (data == null) continue;

      final value = _adapter.fromMap(_adapter.decodeData(data));
      //delay
      // await Future.delayed(Duration(seconds: 1));
      yield value;
    }
  }

  ///
  /// ### Get One in `Box<T>`
  ///
  Future<T?> getOne(bool Function(T value) test, {int? parentId}) async {
    final list = await getAll(parentId: parentId);
    final index = list.indexWhere(test);
    if (index == -1) return null;
    return list[index];
  }

  ///
  /// ### Get One With Stream in `Box<T>`
  ///
  Stream<T?> getOneStream(bool Function(T value) test, {int? parentId}) async* {
    final stream = getAllStream(parentId: parentId);
    await for (var value in stream) {
      if (test(value)) {
        yield value;
        return;
      }
    }
    yield null;
  }
}
