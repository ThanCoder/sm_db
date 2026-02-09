import 'dart:io';

import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

class SMDB {
  late String path;
  Future<void> open(String dbPath) async {
    path = dbPath;
  }

  ///
  /// ## Add Database Record
  ///
  Future<bool> addRecord(
    DatabaseRecord record, {
    bool Function()? isCancelledFile,
    void Function(double progress)? onProgressFile,
  }) async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');

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
    return result;
  }

  ///
  /// ## Read All `Active` Records
  ///
  Future<List<DatabaseRecord>> readAll() async {
    if (!isOpened) throw Exception('You Should Call -> SMDB.open()');

    final list = <DatabaseRecord>[];

    final raf = await File(path).open();
    final total = await raf.length();
    while (await raf.position() < total) {
      // header ကိုအရင် ဖတ်မယ်
      final status = RecordStatus.values[await raf.readByte()];
      final type = RecordType.values[await raf.readByte()];

      DatabaseRecord? record;
      // print(type);

      switch (type) {
        case RecordType.cover:
          record = await CoverRecord.read(raf, status);
          break;
        case RecordType.json:
          record = await JsonRecord.read(raf, status);
          // print((record as JsonRecord).data);
          break;
        case RecordType.file:
          // print(record);
          record = await FileRecord.read(raf, status);
          break;
      }

      if (record != null) {
        list.add(record);
      }
    }

    await raf.close();
    return list;
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
}
