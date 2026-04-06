import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/json_record.dart';
import 'package:sm_db/src/utils/json_db_adapter.dart';

class JsonDBBox<T> {
  final IndexedDB _indexedDB;
  final JsonDBAdapter _adapter;

  const JsonDBBox({
    required IndexedDB indexedDB,
    required JsonDBAdapter adapter,
  }) : _indexedDB = indexedDB,
       _adapter = adapter;

  ///
  /// Return (DatabaseRecord, bool)
  ///
  Future<(JsonRecord, bool)> add(T value) async {
    final id = _indexedDB.generateNextId();
    final map = _adapter.toMap(value);
    map['id'] = id;

    final (record, bool) = await _indexedDB.db.addRecord(
      JsonRecord(
        id: id,
        jsonData: _adapter.encodeData(map),
        adapterTypeId: _adapter.getUniqueFieldId,
        parentId: _adapter.getParentId,
      ),
    );

    return (record as JsonRecord, bool);
  }

  ///
  /// ### Remove Record
  ///
  Future<bool> deleteById(int id) async {
    final index = _indexedDB.allRecordList.indexWhere((e) => e.id == id);
    if (index == -1) {
      throw Exception('Not Found ID:`$id` In IndexDB.allRecordList List');
    }
    return await _indexedDB.db.removeRecord(_indexedDB.allRecordList[index]);
  }

  Future<List<T>> getAll() async {
    final res = await _indexedDB.db.readAll();
    List<T> list = [];
    for (var record in res) {
      // json ပဲရယူမယ်
      if (record.status == RecordStatus.delete ||
          record.type != RecordType.json) {
        continue;
      }
      final jsr = record as JsonRecord;
      if (jsr.adapterTypeId != _adapter.getUniqueFieldId) continue;
      list.add(_adapter.fromMap(_adapter.decodeData(jsr.jsonData)));
    }
    return list;
  }

  Stream<T> getAllStream() async* {
    final res = await _indexedDB.db.readAll();
    for (var record in res) {
      // json ပဲရယူမယ်
      if (record.status == RecordStatus.delete ||
          record.type != RecordType.json) {
        continue;
      }
      final jsr = record as JsonRecord;
      if (jsr.adapterTypeId != _adapter.getUniqueFieldId) continue;
      final value = _adapter.fromMap(_adapter.decodeData(jsr.jsonData)) as T;
      //delay
      // await Future.delayed(Duration(seconds: 1));
      yield value;
    }
  }
}
