import 'dart:convert';
import 'dart:io';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

class IndexedDB {
  late File dbFile;
  late SMDBConfig config;
  late SMDB db;

  void setConfig({
    required SMDB db,
    required File dbFile,
    required SMDBConfig config,
  }) {
    this.db = db;
    this.config = config;
    this.dbFile = dbFile;
    // _onEventListener();
  }

  int _lastIndex = 0;
  CoverRecord? _coverRecord;
  final List<RecordMeta> _allActiveRecordList = [];
  int _deletedCount = 0;
  int _deletedSized = 0;
  (String, int)? _header;
  File get _lockFile => File('${dbFile.path}.lock');

  (String, int)? get header => _header;

  List<RecordMeta> get allActiveRecordList => _allActiveRecordList;

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
    final index = _allActiveRecordList.indexWhere(
      (e) => e.id != -1 && e.id == record.id,
    );
    if (index == -1) return;
    if (record is CoverRecord) {
      _coverRecord = null;
    }
    _allActiveRecordList.removeAt(index);

    _deletedCount++;
    _deletedSized += record.getTotalRecordSize();
    if (isCallMabyCompact) {
      await mabyCompact();
    }
  }

  Future<void> addRecordToRAM(DatabaseRecord record) async {
    if (record.type != RecordType.json) return;
    _allActiveRecordList.add(
      RecordMeta(
        id: record.id,
        adapterTypeId: record.getAdapterTypeId(),
        parentId: record.getParentId(),
        type: record.type,
        offset: record.offset,
        recordTotalSize: record.getTotalRecordSize(),
        dataSize: record.getDataSize(),
        fileInfoSize: record.getInfoSize(),
      ),
    );
    // print('Added to RAM: ${_allActiveRecordList.length}');
  }

  Future<void> loadIndexed() async {
    if (!dbFile.existsSync()) {
      final raf = await File(dbFile.path).open(mode: FileMode.append);
      await writeHeader(raf);
      await raf.close();
    }
    if (_lockFile.existsSync()) {
    } else {
      await _loadDatabase();
    }
  }

  Future<void> _loadDatabase() async {
    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    _header = await readHeader(
      raf,
      type: config.dbType,
      version: config.dbVersion,
    );
    _allActiveRecordList.clear();
    _deletedCount = 0;
    _deletedSized = 0;

    while (await raf.position() < total) {
      final statusByte = await raf.readByte();
      if (statusByte == -1) break; // End of file

      final status = RecordStatus.values[statusByte];
      final type = RecordType.values[await raf.readByte()];

      final position = await raf.position();

      final meta = await RecordMeta.read(raf, position, type);
      if (status == RecordStatus.active) {
        if (type == RecordType.json) {
          _allActiveRecordList.add(meta);
          _lastIndex = meta.id > _lastIndex ? meta.id : _lastIndex;
        }
      } else {
        _deletedCount++;
        _deletedSized += meta.dataSize;
        await raf.setPosition(position + meta.recordTotalSize);
      }
    }

    await raf.close();
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
  /// ### Read Header
  ///
  /// Return `(type, version)`
  ///
  // Future<(String, int)> _readHeader() async {
  //   final raf = await dbFile.open();
  //   final res = await readHeader(
  //     raf,
  //     type: config.dbType,
  //     version: config.dbVersion,
  //   );
  //   await raf.close();
  //   return res;
  // }

  ///
  /// ### Read All JsonRecords In Database
  ///
  // Future<List<JsonRecord>> readAllJsonRecordsInDatabase() async {
  //   final activeList = <JsonRecord>[];

  //   final raf = await File(dbFile.path).open();
  //   final total = await raf.length();
  //   // read header
  //   await readHeader(raf, type: config.dbType, version: config.dbVersion);

  //   while (await raf.position() < total) {
  //     final statusByte = await raf.readByte();
  //     if (statusByte == -1) break; // End of file

  //     final status = RecordStatus.values[statusByte];
  //     final type = RecordType.values[await raf.readByte()];

  //     DatabaseRecord? record;
  //     // print(type);
  //     switch (type) {
  //       case RecordType.cover:
  //         record = await CoverRecord.read(raf);
  //         break;
  //       case RecordType.json:
  //         record = await JsonRecord.read(raf);
  //         break;
  //       case RecordType.file:
  //         // print(record);
  //         record = await FileRecord.read(raf);
  //         break;
  //     }

  //     if (record == null || status != RecordStatus.active) continue;
  //     if (record.type != RecordType.json) continue;
  //     activeList.add(record as JsonRecord);
  //   }

  //   await raf.close();
  //   return activeList;
  // }

  ///
  /// ### Read All FileRecord In Database
  ///
  Future<List<FileRecord>> readAllFileRecordsInDatabase() async {
    final activeList = <FileRecord>[];

    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    await readHeader(raf, type: config.dbType, version: config.dbVersion);

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
          break;
        case RecordType.json:
          record = await JsonRecord.read(raf);
          break;
        case RecordType.file:
          // print(record);
          record = await FileRecord.read(raf);
          break;
      }

      if (record == null || status != RecordStatus.active) continue;
      if (record.type != RecordType.file) continue;
      activeList.add(record as FileRecord);
    }

    await raf.close();
    return activeList;
  }

  ///
  /// ## Read All `Active` Records
  /// Return -> `(activeList, removeList)`
  ///
  Future<(List<DatabaseRecord>, List<DatabaseRecord>)>
  readAllRecordsInDatabase() async {
    final activeList = <DatabaseRecord>[];
    final removeList = <DatabaseRecord>[];

    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    await readHeader(raf, type: config.dbType, version: config.dbVersion);

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

      if (record == null) continue;
      if (status == RecordStatus.active) {
        activeList.add(record);
      } else {
        removeList.add(record);
      }
    }

    await raf.close();
    return (activeList, removeList);
  }

  ///
  /// ### Read All `Active Records` List
  ///
  Future<List<DatabaseRecord>> readAllActiveRecordsInDatabase() async {
    final activeList = <DatabaseRecord>[];

    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    await readHeader(raf, type: config.dbType, version: config.dbVersion);

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

      if (record == null) continue;
      if (status != RecordStatus.active) continue;
      activeList.add(record);
    }

    await raf.close();
    return activeList;
  }

  ///
  /// ### Read All `Deleted Records` List
  ///
  Future<List<DatabaseRecord>> readAllDeletedRecordsInDatabase() async {
    final list = <DatabaseRecord>[];

    final raf = await File(dbFile.path).open();
    final total = await raf.length();
    // read header
    await readHeader(raf, type: config.dbType, version: config.dbVersion);

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

      if (record == null) continue;
      if (status != RecordStatus.delete) continue;
      list.add(record);
    }

    await raf.close();
    return list;
  }

  ///
  /// ### Delete Lock File
  ///
  Future<void> deleteLockFile() async {
    if (_lockFile.existsSync()) {
      await _lockFile.delete();
    }
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
    final (activeList, removeList) = await readAllRecordsInDatabase();
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

  int get deletedCount => _deletedCount;

  int get deletedSize => _deletedSized;

  ///
  /// ## Cover Image Data
  ///
  // Future<Uint8List?> getCoverData() async {
  //   print('record: $_coverRecord');
  //   if (_coverRecord == null ||
  //       !dbFile.existsSync() ||
  //       _coverRecord!.dataStartOffset == -1) {
  //     return null;
  //   }
  //   final raf = await dbFile.open();
  //   final data = await _coverRecord!.getData(raf);
  //   await raf.close();
  //   return data;
  // }

  ///
  /// ## Event Listener for DB
  ///
  // void _onEventListener() {
  //   db.eventBus.on<DBEvent>().listen((event) {
  //     if (event is CoverOffsetChanged && _coverRecord != null) {
  //       _coverRecord!.copyWith(dataStartOffset: event.offset);
  //     }
  //   });
  // }
}
