import 'dart:io';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/events/db_events.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/json_record.dart';
import 'package:sm_db/src/records/db_records.dart';
import 'package:sm_db/src/records/file_record.dart';

extension SmDbRecordExtensions on SMDB {
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
  /// ## Remove Database Record
  ///
  Future<bool> removeRecord(DatabaseRecord record) async {
    bool result = false;
    final file = File(path);
    final raf = await file.open(mode: FileMode.writeOnlyAppend);

    if (record.status == RecordStatus.delete) return false;
    // delete mark
    await record.deleteAsMark(raf);
    // cover
    if (record is CoverRecord) {
      eventBus.add(CoverOffsetChanged(offset: -1));
    }

    await raf.close();
    return result;
  }
}
