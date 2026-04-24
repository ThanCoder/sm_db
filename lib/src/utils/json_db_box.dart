import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/interfaces/smdb_box_interface.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/json_record.dart';

class JsonDBBox<T> extends SmdbBoxInterface<T> {
  final IndexedDB _indexedDB;
  final SMDBJsonAdapter<T> _adapter;

  JsonDBBox({
    required SMDB db,
    required IndexedDB indexedDB,
    required SMDBJsonAdapter<T> adapter,
  }) : _indexedDB = indexedDB,
       _adapter = adapter;

  @override
  Future<T?> add(T value, {int? parentId}) async {
    final id = _indexedDB.generateNextId();
    final map = _adapter.toMap(value);
    map['id'] = id;
    map['autoId'] = id;
    final jsonBytes = _adapter.encodeData(map);

    await _indexedDB.add(
      JsonRecord(
        id: id,
        adapterTypeId: _adapter.adapterTypeId,
        parentId: parentId ?? _adapter.getParentId(value),
        jsonSize: jsonBytes.length,
        jsonBytes: jsonBytes,
      ),
    );
    return _adapter.fromMap(map);
  }

  @override
  Future<void> addAll(List<T> values, {int? parentId}) async {
    final records = values.map((e) {
      final id = _indexedDB.generateNextId();
      final map = _adapter.toMap(e);
      map['id'] = id;
      map['autoId'] = id;
      final jsonBytes = _adapter.encodeData(map);
      return JsonRecord(
        id: id,
        adapterTypeId: _adapter.adapterTypeId,
        parentId: parentId ?? _adapter.getParentId(e),
        jsonSize: jsonBytes.length,
        jsonBytes: jsonBytes,
      );
    }).toList();
    await _indexedDB.addMultiple(records);
  }

  @override
  Future<void> deleteAll(List<int> idList) async {
    await _indexedDB.deleteMultiple(idList);
  }

  @override
  Future<bool> deleteById(int id) async {
    return await _indexedDB.deleteById(id);
  }

  @override
  Future<List<T>> getAll({int? parentId}) async {
    final results = <T>[];
    final raf = _indexedDB.readRaf;

    for (var item in _indexedDB.getAllJson(parentId: parentId)) {
      final data = await RecordMeta.getData(
        raf,
        dataStartOffset: item.offset + jsonHeaderSize,
        dataSize: item.dataSize,
      );
      if (data == null) continue;
      // print(_adapter.decodeData(data));
      results.add(_adapter.fromMap(_adapter.decodeData(data)));
      // print(item);
    }
    return results;
  }

  @override
  Future<List<T>> getAllQuery(
    bool Function(T value) test, {
    int? parentId,
  }) async {
    final list = await getAll(parentId: parentId);
    return list.where(test).toList();
  }

  @override
  Stream<T> getAllQueryStream(
    bool Function(T value) test, {
    int? parentId,
  }) async* {
    await for (var item in getAllStream(parentId: parentId)) {
      if (test(item)) {
        yield item;
      }
    }
  }

  @override
  Stream<T> getAllStream({int? parentId}) async* {
    final raf = await _indexedDB.dbFile.open();

    for (var item in _indexedDB.getAllJson(parentId: parentId)) {
      final data = await RecordMeta.getData(
        raf,
        dataStartOffset: item.offset + jsonHeaderSize,
        dataSize: item.dataSize,
      );
      if (data == null) continue;
      yield _adapter.fromMap(_adapter.decodeData(data));
    }
    await raf.close();
  }

  @override
  Future<T?> getOne(bool Function(T value) test, {int? parentId}) async {
    for (var item in await getAll(parentId: parentId)) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  @override
  Stream<T?> getOneStream(bool Function(T value) test, {int? parentId}) async* {
    await for (var item in getAllStream(parentId: parentId)) {
      if (test(item)) {
        yield item;
        return;
      }
    }
    yield null;
  }

  @override
  Future<bool> updateById(int id, T value) async {
    final map = _adapter.toMap(value);
    map['id'] = id;
    map['autoId'] = id;
    final jsonBytes = _adapter.encodeData(map);
    final record = JsonRecord(
      id: id,
      adapterTypeId: _adapter.adapterTypeId,
      parentId: _adapter.getParentId(value),
      jsonSize: jsonBytes.length,
      jsonBytes: jsonBytes,
    );
    return _indexedDB.updateById(id, record);
  }
}
