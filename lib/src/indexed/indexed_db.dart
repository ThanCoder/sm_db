import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/events/db_events.dart';
import 'package:sm_db/src/indexed/smdb_config.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

class IndexedDB {
  final File dbFile;
  final SMDBConfig config;
  final SMDB db;
  IndexedDB({required this.db, required this.dbFile, required this.config}) {
    _onEventListener();
  }

  int _lastIndex = 0;
  CoverRecord? _coverRecord;
  final List<DatabaseRecord> _allActiveRecordList = [];
  final List<DatabaseRecord> _allDeleteRecordList = [];
  (String, int)? _header;

  (String, int)? get header => _header;

  List<DatabaseRecord> get allRecordList => _allActiveRecordList;
  // getter
  int get lastIndex => _lastIndex;

  int generateNextId() {
    _lastIndex++;
    return _lastIndex;
  }

  Future<void> removeRecord(
    DatabaseRecord record, {
    bool isCallMabyCompact = true,
  }) async {
    final index = _allActiveRecordList.indexWhere((e) => e.id == record.id);
    if (index == -1) return;
    if (record is CoverRecord) {
      _coverRecord = null;
    }
    _allActiveRecordList.removeAt(index);
    _allDeleteRecordList.add(record);
    if (isCallMabyCompact) {
      await mabyCompact();
    }
  }

  void addRecord(DatabaseRecord record) {
    _allActiveRecordList.add(record);
  }

  Future<void> loadIndexed() async {
    if (!dbFile.existsSync()) {
      await writeHeader();
    }
    final (activeList, removeList) = await readAllRecords();
    _allActiveRecordList.clear();
    _allDeleteRecordList.clear();
    _allActiveRecordList.addAll(activeList);
    _allDeleteRecordList.addAll(removeList);

    int currentMax = -1;
    // search last index
    final allList = [...activeList, ...removeList];
    for (var rc in allList) {
      if (rc.id != -1) {
        if (rc.id > currentMax) currentMax = rc.id;
      }
    }
    for (var e in _allActiveRecordList) {
      if (e is CoverRecord) {
        // check cover offset
        _coverRecord = e;
      }
    }
    if (currentMax != -1) {
      _lastIndex = currentMax;
    }
  }

  Future<void> writeHeader() async {
    if (config.dbType.length != 4) {
      throw Exception(
        'Invalid DB type length: expected 4 bytes, got ${config.dbType.length}.',
      );
    }
    final raf = await File(dbFile.path).open(mode: FileMode.append);
    await raf.writeFrom(utf8.encode(config.dbType));
    await raf.writeByte(config.dbVersion);
    await raf.close();
  }

  ///
  /// ### Read Header
  ///
  /// Return `(type, version)`
  ///
  static Future<(String, int)> readHeader(
    RandomAccessFile raf, {
    required String type,
    required int version,
  }) async {
    final typeBytes = await raf.read(4);
    if (typeBytes.isEmpty) {
      throw Exception('Database Type Not Found!');
    }
    final type = utf8.decode(typeBytes);

    final version = await raf.readByte();
    if (type != type) {
      throw Exception('Invalid Database Type: excepted `$type` got `$type`');
    }

    return (type, version);
  }

  ///
  /// ## Read All `Active` Records
  /// Return -> `(activeList, removeList)`
  ///
  Future<(List<DatabaseRecord>, List<DatabaseRecord>)> readAllRecords() async {
    final activeList = <DatabaseRecord>[];
    final removeList = <DatabaseRecord>[];

    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    _header = await readHeader(
      raf,
      type: config.dbType,
      version: config.dbVersion,
    );

    while (await raf.position() < total) {
      // header ကိုအရင် ဖတ်မယ်
      final status = RecordStatus.values[await raf.readByte()];
      final type = RecordType.values[await raf.readByte()];

      DatabaseRecord? record;
      // print(type);
      switch (type) {
        case RecordType.cover:
          final coverRecord = await CoverRecord.read(raf);
          if (coverRecord != null && status == RecordStatus.delete) {
            _allDeleteRecordList.add(coverRecord);
          } else {
            _coverRecord = coverRecord;
          }
          break;
        case RecordType.json:
          record = await JsonRecord.read(raf);
          // print((record as JsonRecord).data);
          break;
        case RecordType.file:
          // print(record);
          record = await FileRecord.read(raf);
          break;
      }

      if (record != null) {
        if (status == RecordStatus.active) {
          activeList.add(record);
        } else {
          removeList.add(record);
        }
      }
    }

    await raf.close();
    return (activeList, removeList);
  }

  Future<void> mabyCompact() async {
    if (config.autoCompact &&
        (config.needToCompact(deletedCount, deletedSize))) {
      await compact();
    }
  }

  Future<void> compact() async {
    // final (activeList, _) = await readAllRecords();
  }

  ///
  /// ## CoverRecord?
  ///
  CoverRecord? get coverRecord => _coverRecord;

  int get deletedCount => _allDeleteRecordList.length;

  int get deletedSize {
    int size = 0;
    for (var rec in _allDeleteRecordList) {
      if (rec is FileRecord) {
        size += rec.fileSize;
      }
      if (rec is JsonRecord) {
        size += rec.jsonData.length;
      }
      if (rec is CoverRecord) {
        size += rec.size ?? 0;
      }
    }
    return size;
  }

  ///
  /// ## Cover Image Data
  ///
  Future<Uint8List?> getCoverData() async {
    if (_coverRecord == null ||
        !dbFile.existsSync() ||
        _coverRecord!.dataStartOffset == null) {
      return null;
    }
    final raf = await dbFile.open();
    return await _coverRecord!.getData(raf);
  }

  ///
  /// ### Remove Cover Data
  ///
  Future<bool> deleteCover() async {
    if (_coverRecord == null) return false;
    final raf = await dbFile.open(mode: FileMode.append);

    await coverRecord!.deleteAsMark(raf);

    await raf.close();
    _coverRecord = null;
    return true;
  }

  ///
  /// ## Event Listener for DB
  ///
  void _onEventListener() {
    db.eventBus.on<DBEvent>().listen((event) {
      if (event is CoverOffsetChanged && _coverRecord != null) {
        _coverRecord!.copyWith(dataStartOffset: event.offset);
      }
    });
  }
}
