import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

class RecordMeta {
  final RecordType type;
  final int offset;
  final int id;
  final int adapterTypeId;
  final int parentId;
  final int recordTotalSize;
  final int dataSize;
  final int fileInfoSize;

  const RecordMeta({
    required this.type,
    required this.offset,
    required this.recordTotalSize,
    required this.dataSize,
    this.id = -1,
    this.adapterTypeId = -1,
    this.parentId = -1,
    this.fileInfoSize = 0,
  });

  ///
  /// ### Read Cover
  ///
  static Future<RecordMeta> read(RandomAccessFile raf, RecordType type) async {
    final pos = await raf.position() - 2;
    switch (type) {
      case RecordType.cover:
        return CoverRecord.readMeta(raf, pos);
      case RecordType.json:
        return JsonRecord.readMeta(raf, pos);
      case RecordType.file:
        return FileRecord.readMeta(raf, pos);
    }
  }

  ///
  /// ### Delete Mark Database Record
  ///
  Future<bool> deleteAsMark(RandomAccessFile raf) async {
    if (offset == -1) return false;

    final current = await raf.position();

    // 1. Header နေရာသို့ သွား၍ Status ကို Update လုပ်မည်
    await raf.setPosition(offset);

    // 3. File ထဲသို့ Status Index ကို ရေးမည်
    await raf.writeByte(RecordStatus.delete.index);

    // 4. မူလ Position သို့ ပြန်သွားမည်
    await raf.setPosition(current);

    return true;
  }

  ///
  /// ### Read Data Bytes
  ///
  /// Working `cover`,`json`
  ///
  /// Not Working `file`!!!
  ///
  static Future<Uint8List?> getData(
    RandomAccessFile raf,
    int dataStartOffset,
    int dataSize,
  ) async {
    if (dataStartOffset == -1 || dataSize == 0) return null;

    // set
    await raf.setPosition(dataStartOffset);
    final data = await raf.read(dataSize);

    return data;
  }
}
