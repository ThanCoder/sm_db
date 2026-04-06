import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/events/event_bus.dart';
import 'package:sm_db/src/indexed/smdb_config.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';
import 'package:sm_db/src/utils/json_db_adapter.dart';
import 'package:sm_db/src/utils/json_db_box.dart';

class SMDB {
  // singleton
  static SMDB? _instance;
  static SMDB getInstance() {
    _instance ??= SMDB();
    return _instance!;
  }

  late String path;
  late IndexedDB _indexedDB;
  final EventBus eventBus = EventBus();
  // adapter
  final Map<Type, JsonDBAdapter> _adapters = {};
  final Map<Type, JsonDBBox> _boxs = {};

  ///
  /// ### Database Open
  ///
  Future<void> open(String dbPath, {SMDBConfig? config}) async {
    if (isOpened) {
      await close();
    }
    path = dbPath;
    _indexedDB = IndexedDB(
      db: this,
      dbFile: File(path),
      config: config ?? SMDBConfig.empty(),
    );

    await _indexedDB.loadIndexed();
  }

  ///
  /// ### Set Adapter`<T>`
  ///
  /// Usage `db.registerAdapterNotExists<User>(UserAdapter());`
  ///
  void registerAdapterNotExists<T>(JsonDBAdapter adapter) {
    if (_adapters.containsKey(T)) return;
    final ids = _adapters.values.map((e) => e.getUniqueFieldId);
    if (ids.contains(adapter.getUniqueFieldId)) {
      throw Exception(
        """ Duplicate Adapter: `${adapter.runtimeType}` Unique id detected: `${adapter.getUniqueFieldId}`\n---Please Change---
        @override
        int get getUniqueFieldId => `${adapter.getUniqueFieldId}`; <<<-----
        """,
      );
    }
    _adapters[T] = adapter;
    _boxs[T] = JsonDBBox<T>(indexedDB: _indexedDB, adapter: adapter);
  }

  ///
  /// ### All Registered Adapter Clear
  ///
  void clearAllAdapter() {
    _adapters.clear();
    _boxs.clear();
  }

  ///
  /// ### Get Adapter`<T>`
  ///
  JsonDBAdapter<T> getAdapter<T>() {
    if (_adapters[T] == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return _adapters[T] as JsonDBAdapter<T>;
  }

  ///
  /// ### Get Box`<T>`
  ///
  JsonDBBox<T> getBox<T>() {
    if (_boxs[T] == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return _boxs[T] as JsonDBBox<T>;
  }

  ///
  /// ## Database Is Opened
  ///
  bool get isOpened {
    try {
      path;
      return true;
    } catch (e) {
      return false;
    }
  }

  ///
  /// ### Close Database
  ///
  Future<void> close() async {}

  ///
  /// ### CoverRecord `[Uint8List]` data
  ///
  Future<Uint8List?> getCoverData() async {
    return await _indexedDB.getCoverData();
  }

  ///
  /// ### SetCover From Path
  ///
  Future<bool> setCoverFormPath(String path) async {
    // ရှိနေရင် auto delete cover data
    await _indexedDB.deleteCover();

    final record = CoverRecord.fromPath(path);
    final (_, result) = await addRecord(record);
    return result;
  }

  ///
  /// ### Read All `Active` Records
  ///
  Future<List<DatabaseRecord>> readAll() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    return _indexedDB.allRecordList;
  }

  ///
  /// ### Read All `Active File` Records
  ///
  Future<List<FileRecord>> readAllFiles() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    List<FileRecord> list = [];

    for (var rec in _indexedDB.allRecordList) {
      if (rec.type != RecordType.file) continue;
      list.add(rec as FileRecord);
    }
    return list;
  }

  ///
  /// ### Read All `Active Json` Records
  ///
  Future<List<JsonRecord>> readAllJson() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    List<JsonRecord> list = [];

    for (var rec in _indexedDB.allRecordList) {
      if (rec.type != RecordType.json) continue;
      list.add(rec as JsonRecord);
    }
    return list;
  }

  ///
  /// ### Extract All File
  ///
  Future<void> extractAllFiles({
    required Directory outDir,
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    final raf = await File(path).open();

    for (var file in await readAllFiles()) {
      await file.extract(
        raf,
        outDir: outDir,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
    }
    await raf.close();
  }

  ///
  /// ### Delete All File
  ///
  Future<void> deleteAllFiles() async {
    for (var file in await readAllFiles()) {
      await removeRecord(file, isCallMabyCompact: false);
    }
    await _indexedDB.mabyCompact();
  }

  ///
  /// ### Delete All Json Records
  ///
  Future<void> deleteAllJsonRecords() async {
    for (var rc in await readAllJson()) {
      await removeRecord(rc, isCallMabyCompact: false);
    }
    await _indexedDB.mabyCompact();
  }

  ///
  /// ### Add Database Record
  /// Return-> `(record, result)`
  ///
  Future<(DatabaseRecord, bool)> addRecord(
    DatabaseRecord record, {
    bool Function()? isCancelledFile,
    void Function(double progress)? onProgressFile,
  }) async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');

    // lastindex
    if (record.id == 0 || record.id == -1) {
      record.id = _indexedDB.generateNextId();
    }

    bool result = false;

    final file = File(path);
    final raf = await file.open(mode: FileMode.append);
    if (record is FileRecord) {
      result = await record.write(
        raf,
        isCancelled: isCancelledFile,
        onProgress: onProgressFile,
      );
    } else {
      await record.write(raf);
      result = true;
    }
    await raf.close();
    // add index db
    _indexedDB.addRecord(record);

    return (record, result);
  }

  ///
  /// ### Remove Database Record
  ///
  Future<bool> removeRecord(
    DatabaseRecord record, {
    bool isCallMabyCompact = true,
  }) async {
    final file = File(path);
    final raf = await file.open(mode: FileMode.append);

    if (record.status == RecordStatus.delete) return false;
    // delete mark
    final recordStatus = await record.deleteAsMark(raf);

    record.status = recordStatus;
    // remove indexDB list
    await _indexedDB.removeRecord(record, isCallMabyCompact: isCallMabyCompact);

    await raf.close();
    return false;
  }

  ///
  /// ### Remove Multi Database Record
  ///
  Future<bool> removeMultiRecord(List<DatabaseRecord> records) async {
    final file = File(path);
    final raf = await file.open(mode: FileMode.append);

    for (var record in records) {
      if (record.status == RecordStatus.delete) return false;
      // delete mark
      final recordStatus = await record.deleteAsMark(raf);

      record.status = recordStatus;
      // remove indexDB list
      await _indexedDB.removeRecord(record, isCallMabyCompact: false);
    }
    await raf.close();
    await _indexedDB.mabyCompact();

    return false;
  }

  ///
  /// ### Get CoverRecord
  ///
  CoverRecord? get coverRecod => _indexedDB.coverRecord;

  ///
  /// ### Database Binary Last Index
  ///
  int get lastIndex => _indexedDB.lastIndex;

  int get deletedCount => _indexedDB.deletedCount;

  int get deletedSize => _indexedDB.deletedSize;

  (String, int)? get header => _indexedDB.header;

  ///
  /// Read Rader From Database Files
  ///
  static Future<(String, int)> readHeaderFromPath(
    String dbPath, {
    required String type,
    required int version,
  }) async {
    final raf = await File(dbPath).open();
    final res = await IndexedDB.readHeader(raf, type: type, version: version);
    await raf.close();
    return res;
  }
}

// Future<void> _addFileRecordInBackground((String, FileRecord) params) async {}
