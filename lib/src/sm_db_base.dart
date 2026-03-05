import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/events/db_events.dart';
import 'package:sm_db/src/events/event_bus.dart';
import 'package:sm_db/src/indexed/db_config.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';

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
  Future<void> open(String dbPath) async {
    path = dbPath;
    _indexedDB = IndexedDB(db: this, dbFile: File(path), config: DBConfig());

    await _indexedDB.loadIndexed();
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
    if (record.id == 0) {
      record.id = lastIndex;
      eventBus.add(IncreLastIndex());
    }

    bool result = false;

    final file = File(path);
    final raf = await file.open(mode: FileMode.writeOnlyAppend);
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
    return (record, result);
  }

  ///
  /// ### Get CoverRecord
  ///
  CoverRecord? get coverRecod => _indexedDB.coverRecord;

  ///
  /// ### Database Binary Last Index
  ///
  int get lastIndex => _indexedDB.lastIndex;
}
