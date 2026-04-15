import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/events/db_events.dart';
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

  List<DatabaseRecord> get allActiveRecordList => _allActiveRecordList;

  // getter
  int get lastIndex => _lastIndex;

  int generateNextId() {
    _lastIndex++;
    return _lastIndex;
  }

  Future<void> removeRecordToRAM(
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

  Future<void> addRecordToRAM(DatabaseRecord record) async {
    _allActiveRecordList.add(record);
    // print('Added to RAM: ${_allActiveRecordList.length}');
  }

  Future<void> loadIndexed() async {
    if (!dbFile.existsSync()) {
      final raf = await File(dbFile.path).open(mode: FileMode.append);
      await writeHeader(raf);
      await raf.close();
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

  Future<void> writeHeader(RandomAccessFile raf) async {
    if (config.dbType.length != 4) {
      throw Exception(
        'Invalid DB type length: expected 4 bytes, got ${config.dbType.length}.',
      );
    }

    await raf.writeFrom(utf8.encode(config.dbType));
    await raf.writeByte(config.dbVersion);
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
      final statusByte = await raf.readByte();
      if (statusByte == -1) break; // End of file

      final status = RecordStatus.values[statusByte];
      final type = RecordType.values[await raf.readByte()];

      DatabaseRecord? record;
      // print(type);
      switch (type) {
        case RecordType.cover:
          record = await CoverRecord.read(raf);
          if (record != null && record.status == RecordStatus.active) {
            _coverRecord = (record as CoverRecord);
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

  ///
  /// ### When Database Remove [`Auto Compact`];
  ///
  Future<void> mabyCompact() async {
    if (config.autoCompact &&
        (config.needToCompact(deletedCount, deletedSize))) {
      await compact();
    }
  }

  ///
  /// Reduce Removed Record List
  ///
  /// Or DB Clean Up
  ///
  Future<void> compact({
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    final (activeList, removeList) = await readAllRecords();
    if (removeList.isEmpty) return;

    final sourceRaf = await dbFile.open();
    final compactFile = File('${dbFile.path}.compact');
    final compactRaf = await compactFile.open(mode: FileMode.write);

    // write header
    await writeHeader(compactRaf);

    for (var rec in activeList) {
      int recordTotalSize = 0;
      int startOffset = -1;
      if (rec.type == RecordType.cover) {
        final record = (rec as CoverRecord);
        startOffset = record.dataStartOffset - record.headerSize;
        recordTotalSize = record.headerSize + record.size;
      }
      if (rec.type == RecordType.json) {
        final record = (rec as JsonRecord);
        startOffset = record.dataStartOffset - record.headerSize;
        recordTotalSize = record.headerSize + record.jsonSize;
      }
      if (rec.type == RecordType.file) {
        final record = (rec as FileRecord);
        startOffset =
            (record.dataStartOffset - record.infoSize) - record.headerSize;
        recordTotalSize = record.headerSize + record.infoSize + record.fileSize;
      }
      if (startOffset == -1 || recordTotalSize == 0) continue;

      await rec.transferRecord(
        sourceRaf: sourceRaf,
        targetRaf: compactRaf,
        startOffset: startOffset,
        recordTotalSize: recordTotalSize,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    }

    // close compact raf
    await compactRaf.close();
    // config
    if (config.whenCompactAndCreateBkFile) {
      await dbFile.rename('${dbFile.path}.bk');
    } else {
      await dbFile.delete();
    }
    await compactFile.rename(dbFile.path);
    await loadIndexed();
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
        size += rec.jsonSize;
      }
      if (rec is CoverRecord) {
        size += rec.size;
      }
    }
    return size;
  }

  ///
  /// ## Cover Image Data
  ///
  Future<Uint8List?> getCoverData() async {
    print('record: $_coverRecord');
    if (_coverRecord == null ||
        !dbFile.existsSync() ||
        _coverRecord!.dataStartOffset == -1) {
      return null;
    }
    final raf = await dbFile.open();
    return await _coverRecord!.getData(raf);
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
