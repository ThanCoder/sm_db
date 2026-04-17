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
  final IndexedDB _indexedDB = IndexedDB();
  bool _isInitializing = false;
  final EventBus eventBus = EventBus();
  // adapter
  final Map<Type, SMDBJsonAdapter> _adapters = {};
  final Map<Type, JsonDBBox> _boxs = {};

  ///
  /// ### Database Open
  ///
  Future<void> open(
    String dbPath, {
    SMDBConfig? config,
    bool databaseIfOpenWillCloseReOpen = false,
  }) async {
    if (isOpened && databaseIfOpenWillCloseReOpen) {
      await close(isClearAllAdapter: true);
    }
    if (isOpened && !databaseIfOpenWillCloseReOpen) return;

    path = dbPath;
    _indexedDB.setConfig(
      db: this,
      dbFile: File(path),
      config: config ?? SMDBConfig.empty(),
    );

    await _indexedDB.loadIndexed();
    _isInitializing = true;
  }

  ///
  /// ### Set Adapter`<T>`
  ///
  /// Usage `db.registerAdapterNotExists<User>(UserAdapter());`
  ///
  void registerAdapterNotExists<T>(SMDBJsonAdapter<T> adapter) {
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
  /// ### Clear All Registered Adapter
  ///
  void clearAllAdapter() {
    _adapters.clear();
    _boxs.clear();
  }

  ///
  /// ### Get Adapter`<T>`
  ///
  SMDBJsonAdapter<T> getAdapter<T>() {
    if (_adapters[T] == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return _adapters[T] as SMDBJsonAdapter<T>;
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
    return _isInitializing;
  }

  ///
  /// ### Close Database
  ///
  /// No Working For Now
  ///
  Future<void> close({bool isClearAllAdapter = true}) async {
    _isInitializing = false;
    if (isClearAllAdapter) {
      clearAllAdapter();
    }
  }

  ///
  /// ### CoverRecord `[Uint8List]` data
  ///
  Future<Uint8List?> getCoverData() async {
    return await _indexedDB.getCoverData();
  }

  ///
  /// ### Cover Data `[Uint8List]`
  ///
  Future<Uint8List?> readCoverDataInDatabase() async {
    final res = await _indexedDB.readCoverRecordInDatabase();
    if (res == null) return null;
    final raf = await File(path).open();
    final data = await res.getData(raf);
    await raf.close();
    return data;
  }

  ///
  /// Export Cover File
  ///
  Future<bool> exportCoverFile(String path) async {
    final outFile = File(path);
    final data = await _indexedDB.getCoverData();
    if (data == null) return false;
    await outFile.writeAsBytes(data);
    return true;
  }

  ///
  /// ### Delete Cover
  ///
  /// Return `<isDeleted>`
  ///
  Future<bool> deleteCover() async {
    final cover = _indexedDB.coverRecord;
    if (cover == null) return false;
    await removeRecord(cover);
    return true;
  }

  ///
  /// ### SetCover From Path
  ///
  Future<bool> setCoverFormPath(String path) async {
    if (!File(path).existsSync()) {
      throw Exception('File Not Found!: `$path`');
    }
    // ရှိနေရင် auto delete cover data
    if (_indexedDB.coverRecord != null) {
      await removeRecord(_indexedDB.coverRecord!, isCallMabyCompact: false);
    }

    final record = CoverRecord.fromPath(path);
    final (_, result) = await addRecord(record);
    return result;
  }

  ///
  /// ### Read All `Active JsonRecords`
  ///
  Future<List<JsonRecord>> readAll() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    return _indexedDB.allActiveRecordList;
  }

  ///
  /// ### Get By Id
  ///
  Future<DatabaseRecord?> getById(int id) async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    final index = _indexedDB.allActiveRecordList.indexWhere((e) => e.id == id);
    if (index == -1) return null;
    return _indexedDB.allActiveRecordList[index];
  }

  ///
  /// ### Read All `Active FileRecords`
  ///
  Future<List<FileRecord>> readAllFileRecordsInDatabase() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    return await _indexedDB.readAllFileRecordsInDatabase();
  }

  ///
  /// ### Read All `Active JsonRecords`
  ///
  Future<List<JsonRecord>> readAllJsonRecordsInDatabase() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    return await _indexedDB.readAllJsonRecordsInDatabase();
  }

  ///
  /// ### Read All `Active Records` List
  ///
  Future<List<DatabaseRecord>> readAllActiveRecordsInDatabase() async {
    return await _indexedDB.readAllActiveRecordsInDatabase();
  }

  ///
  /// ### Read All `Deleted Records` List
  ///
  Future<List<DatabaseRecord>> readAllDeletedRecordsInDatabase() async {
    return await _indexedDB.readAllDeletedRecordsInDatabase();
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

    for (var file in await readAllFileRecordsInDatabase()) {
      final savePath = '${outDir.path}${Platform.pathSeparator}${file.name}';
      await file.extract(
        raf,
        savePath: savePath,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
    }
    await raf.close();
  }

  ///
  /// ### Extract File
  ///
  Future<void> extractFile(
    FileRecord fileRecord, {
    required String savePath,
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');
    final raf = await File(path).open();

    await fileRecord.extract(
      raf,
      savePath: savePath,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    await raf.close();
  }

  ///
  /// ### Delete All File
  ///
  Future<void> deleteAllFiles() async {
    for (var file in await readAllFileRecordsInDatabase()) {
      await removeRecord(file, isCallMabyCompact: false);
    }
    await _indexedDB.mabyCompact();
  }

  ///
  /// ### Delete All Json Records
  ///
  Future<void> deleteAllJsonRecords() async {
    for (var rc in await readAll()) {
      await removeRecord(rc, isCallMabyCompact: false);
    }
    await _indexedDB.mabyCompact();
  }

  ///
  /// ### Add Database Record
  ///
  /// Return-> `(record, result)`
  ///
  ///  `parentId ?? SMDBJsonAdapter.getParentId(T value)`
  ///
  /// ```dart
  /// /// For JsonRecord
  /// abstract class SMDBJsonAdapter<T>
  ///   int getParentId(T value) => -1; <--- Need To Override
  ///
  ///```
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

    // add index db
    if (record is JsonRecord) {
      record.jsonBytes = null;
    }
    await _indexedDB.addRecordToRAM(record);

    await raf.close();

    return (record, result);
  }

  ///
  /// ### Remove Record By Id
  ///
  Future<bool> removeRecordById(int id) async {
    final index = _indexedDB.allActiveRecordList.indexWhere((e) => e.id == id);
    if (index == -1) {
      throw Exception('Not Found ID:`$id` In indexedDB.allActiveRecordList');
    }
    final res = await _indexedDB.db.removeRecord(
      _indexedDB.allActiveRecordList[index],
    );

    return res;
  }

  ///
  /// ### Remove Database Record
  ///
  /// Return -> isDeleted
  ///
  Future<bool> removeRecord(
    DatabaseRecord record, {
    bool isCallMabyCompact = true,
  }) async {
    final file = File(path);
    final raf = await file.open(mode: FileMode.append);

    if (record.status == RecordStatus.delete) return true;
    // delete mark
    final recordStatus = await record.deleteAsMark(raf);

    record.status = recordStatus;
    // remove indexDB list
    await _indexedDB.removeRecordToRAM(
      record,
      isCallMabyCompact: isCallMabyCompact,
    );

    await raf.close();
    return true;
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
      await _indexedDB.removeRecordToRAM(record, isCallMabyCompact: false);
    }
    await raf.close();
    await _indexedDB.mabyCompact();

    return false;
  }

  ///
  /// ### When Database Remove [`Auto Compact`];
  ///
  Future<void> mabyCompact() async {
    await _indexedDB.mabyCompact();
  }

  ///
  /// Reduce Removed Record List
  ///
  /// Or DB Clean Up
  ///
  ///  if (removeList.isEmpty) Not Do Anything.
  ///
  Future<void> compact({
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    await _indexedDB.compact(isCancelled: isCancelled, onProgress: onProgress);
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
