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

  void setConfig({
    required SMDB db,
    required File dbFile,
    required SMDBConfig config,
  }) {
    this.config = config;
    this.dbFile = dbFile;
    // _onEventListener();
  }

  int _lastIndex = 0;
  CoverRecord? _coverRecord;
  final List<RecordMeta> _allRecordList = [];
  int _deletedCount = 0;
  int _deletedSized = 0;
  (String, int)? _header;

  (String, int)? get header => _header;
  List<RecordMeta> get allRecordList => _allRecordList;

  // getter
  int get lastIndex => _lastIndex;

  int generateNextId() {
    _lastIndex++;
    return _lastIndex;
  }

  Future<void> loadIndexed() async {
    if (!dbFile.existsSync()) {
      final raf = await File(dbFile.path).open(mode: FileMode.append);
      await writeHeader(raf);
      await raf.close();
    }
    await _buildIndexInDatabase();
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

  Future<void> _buildIndexInDatabase() async {
    _allRecordList.clear();
    _deletedCount = 0;
    _deletedSized = 0;

    final raf = await dbFile.open();
    if (!dbFile.existsSync()) return;
    final size = dbFile.lengthSync();
    // read header
    await readHeader(raf, type: config.dbType, version: config.dbVersion);

    while (await raf.position() < size) {
      final statusIndex = await raf.readByte();
      if (statusIndex == -1) {
        throw Exception('Status Not Found / End of File!');
      }
      final status = RecordStatus.values[statusIndex];
      final type = RecordType.values[await raf.readByte()];

      final meta = await RecordMeta.read(raf, type);
      if (status == RecordStatus.active) {
        _allRecordList.add(meta);
      } else {
        //delete
        _deletedCount++;
        _deletedSized += meta.recordTotalSize;
      }
      // last index
      _lastIndex = meta.id > _lastIndex ? meta.id : lastIndex;
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
}
