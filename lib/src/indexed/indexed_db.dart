import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

class IndexedDB {
  late File dbFile;
  late SMDBConfig config;
  late RandomAccessFile _writeRaf;
  late RandomAccessFile readRaf;

  Future<void> setConfig({
    required SMDB db,
    required File dbFile,
    required SMDBConfig config,
  }) async {
    this.config = config;
    this.dbFile = dbFile;
  }

  int _lastIndex = 0;
  final List<RecordMeta> _allRecordList = [];
  final Map<int, List<RecordMeta>> _parentOfChild = {};
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
    _writeRaf = await dbFile.open(mode: FileMode.append);
    readRaf = await dbFile.open(mode: FileMode.read);
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

  Future<void> _buildIndexInDatabase() async {
    _allRecordList.clear();
    _parentOfChild.clear();
    _lastIndex = 0;
    _deletedCount = 0;
    _deletedSized = 0;

    final raf = await dbFile.open();
    if (!dbFile.existsSync()) return;
    final size = dbFile.lengthSync();
    // read header
    _header = await readHeader(
      raf,
      type: config.dbType,
      version: config.dbVersion,
    );

    while ((await raf.position()) < size) {
      final statusIndex = await raf.readByte();
      if (statusIndex == -1) {
        throw Exception('Status Not Found / End of File!');
      }
      final status = RecordStatus.values[statusIndex];
      final type = RecordType.values[await raf.readByte()];

      final meta = await RecordMeta.read(raf, type);

      if (status == RecordStatus.active) {
        _allRecordList.add(meta);
        // set parent
        if (meta.parentId != -1) {
          _parentOfChild.putIfAbsent(meta.parentId, () => []).add(meta);
        }
      } else {
        //delete
        _deletedCount++;
        _deletedSized += meta.recordTotalSize;
      }
      // last index
      _lastIndex = meta.id > _lastIndex ? meta.id : lastIndex;
    }
    await raf.close();
  }

  List<RecordMeta> getAll({int? parentId}) {
    if (parentId != null) {
      return _parentOfChild[parentId] ?? [];
    }
    return _allRecordList;
  }

  List<RecordMeta> getAllJson({int? parentId}) {
    final list = getAll(parentId: parentId);
    return list.where((e) => e.type == RecordType.json).toList();
  }

  RecordMeta? get getCoverRecord {
    final index = getAll().indexWhere((e) => e.type == RecordType.cover);
    if (index == -1) return null;
    return getAll()[index];
  }

  List<RecordMeta> get getAllFiles {
    return getAll().where((e) => e.type == RecordType.file).toList();
  }

  ///
  /// ### Update parentOfChild List
  ///
  Future<void> _updateParentOfChildList() async {
    // Remove RAM
    _parentOfChild.clear();

    for (var record in _allRecordList) {
      if (record.parentId == -1) continue;
      _parentOfChild.putIfAbsent(record.parentId, () => []).add(record);
    }
  }

  // ------- CRUD ----- //
  ///
  /// ### Add Single
  ///
  /// Return `header start offset`
  ///
  Future<int> add(
    DatabaseRecord record, {
    bool Function()? isCancelled,
    void Function(double)? onProgress,
  }) async {
    // cover
    if (record.type == RecordType.cover) {
      final offset = await (record as CoverRecord).write(_writeRaf);
      await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း
      final res = await CoverRecord.readMeta(readRaf, headerOffset: offset);
      _allRecordList.add(res);
      return offset;
    }
    // json
    if (record.type == RecordType.json) {
      final offset = await (record as JsonRecord).write(_writeRaf);
      await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း
      final res = await JsonRecord.readMeta(readRaf, realHeaderOffset: offset);
      _allRecordList.add(res);
      if (res.parentId != -1) {
        _parentOfChild.putIfAbsent(res.parentId, () => []).add(res);
      }
      return offset;
    }
    // file
    if (record.type == RecordType.file) {
      final offset = await (record as FileRecord).write(
        _writeRaf,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း
      final res = await FileRecord.readMeta(readRaf, headerOffset: offset);
      _allRecordList.add(res);
      return offset;
    }
    return -1;
  }

  ///
  /// ### Add Multiple
  ///
  ///
  Future<void> addMultiple(
    List<DatabaseRecord> records, {
    bool Function()? isCancelled,
    void Function(double)? onProgress,
  }) async {
    final addedRecords = <(int, RecordType)>[];

    for (var record in records) {
      // cover
      if (record.type == RecordType.cover) {
        final offset = await (record as CoverRecord).write(_writeRaf);
        addedRecords.add((offset, RecordType.cover));
      }
      // cover
      if (record.type == RecordType.json) {
        final offset = await (record as JsonRecord).write(_writeRaf);
        addedRecords.add((offset, RecordType.json));
      }
      // cover
      if (record.type == RecordType.file) {
        final offset = await (record as FileRecord).write(
          _writeRaf,
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
        addedRecords.add((offset, RecordType.file));
      }
    }

    await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း
    final raf = await dbFile.open();

    // add RAM
    for (var added in addedRecords) {
      if (added.$2 == RecordType.cover) {
        final res = await CoverRecord.readMeta(raf, headerOffset: added.$1);
        _allRecordList.add(res);
      }
      if (added.$2 == RecordType.json) {
        final res = await JsonRecord.readMeta(raf, realHeaderOffset: added.$1);
        if (res.parentId != -1) {
          _parentOfChild.putIfAbsent(res.parentId, () => []).add(res);
        }
        _allRecordList.add(res);
      }
      if (added.$2 == RecordType.file) {
        final res = await FileRecord.readMeta(raf, headerOffset: added.$1);
        _allRecordList.add(res);
      }
    }

    await raf.close();
  }

  ///
  /// ### Update By id
  ///
  /// Working Records -> `json`,`file`
  ///
  Future<bool> updateById(
    int id,
    DatabaseRecord record, {
    bool Function()? isCancelled,
    void Function(double)? onProgress,
  }) async {
    final index = _allRecordList.indexWhere((e) => e.id == id);
    if (index == -1) throw Exception('ID: $id Not Found!');
    // record ရယူ
    final record = _allRecordList[index];
    // delete mark
    final isDeleted = await record.deleteAsMark(_writeRaf);
    if (isDeleted) return false;
    // update လုပ်မယ်

    // json
    if (record.type == RecordType.json) {
      final offset = await (record as JsonRecord).write(_writeRaf);
      await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း

      final raf = await dbFile.open();
      final res = await JsonRecord.readMeta(raf, realHeaderOffset: offset);
      await raf.close();
      _allRecordList[index] = res;
    }
    // file
    if (record.type == RecordType.file) {
      final offset = await (record as FileRecord).write(
        _writeRaf,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      await _writeRaf.flush(); //disk ထဲထည့်သွင်းခြင်း
      final raf = await dbFile.open();
      final res = await FileRecord.readMeta(raf, headerOffset: offset);
      await raf.close();
      _allRecordList[index] = res;
    }
    await _updateParentOfChildList();

    return isDeleted;
  }

  ///
  /// ### Delete By id
  ///
  Future<bool> deleteById(int id) async {
    final index = _allRecordList.indexWhere((e) => e.id == id);
    if (index == -1) throw Exception('ID: $id Not Found!');
    // record ရယူ
    final record = _allRecordList[index];
    // delete mark
    final isDeleted = await record.deleteAsMark(_writeRaf);
    if (isDeleted) {
      // Remove RAM
      _allRecordList.removeAt(index);
      _updateParentOfChildList();
    }
    await _writeRaf.flush(); //disk ထဲရောက်အောင်

    return isDeleted;
  }

  ///
  /// ### Delete By Multiple id
  ///
  Future<void> deleteMultiple(List<int> idList) async {
    for (var id in idList) {
      final index = _allRecordList.indexWhere((e) => e.id == id);
      if (index == -1) throw Exception('ID: $id Not Found!');
      // record ရယူ
      final record = _allRecordList[index];
      // delete mark
      if (await record.deleteAsMark(_writeRaf)) {
        _allRecordList.removeAt(index);
      }
    }

    _updateParentOfChildList();

    await _writeRaf.flush(); //disk ထဲရောက်အောင်
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
    if (_deletedCount == 0 || _deletedSized == 0) return;

    final sourceRaf = await dbFile.open();
    final compactFile = File('${dbFile.path}.compact');
    final compactRaf = await compactFile.open(mode: FileMode.write);

    // write header
    await writeHeader(compactRaf);
    // Buffer size ကို 1MB လောက်ထားတာ အသင့်တော်ဆုံးပါပဲ
    const int bufferSize = 1024 * 1024;
    final Uint8List buffer = Uint8List(bufferSize);
    int i = 0;

    for (var rec in _allRecordList) {
      i++;
      // offset နဲ့ read မယ်
      await sourceRaf.setPosition(rec.offset);

      int bytesToRead = rec.recordTotalSize;

      while (bytesToRead > 0) {
        if (isCancelled?.call() ?? false) {
          break;
        }
        int readLength = bytesToRead > bufferSize ? bufferSize : bytesToRead;
        int bytesActuallyRead = await sourceRaf.readInto(buffer, 0, readLength);

        if (bytesActuallyRead <= 0) break;

        await compactRaf.writeFrom(buffer, 0, bytesActuallyRead);
        bytesToRead -= bytesActuallyRead;
      }
      await compactRaf.flush(); //disk ထဲရောက်တာ သေချာစေဘို့

      // progress
      onProgress?.call(i / _allRecordList.length);
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

  Future<void> close() async {
    await _writeRaf.close();
    await readRaf.close();
  }

  int get deletedCount => _deletedCount;

  int get deletedSize => _deletedSized;

  // ---- Static ----- //
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
}
