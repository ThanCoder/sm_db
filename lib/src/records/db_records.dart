// ignore_for_file: unused_field
import 'dart:io';

import 'package:sm_db/src/events/sm_db_events_listener.dart';

enum RecordType { cover, json, file }

enum RecordStatus { delete, active }

abstract class DatabaseRecord {
  int id;
  final RecordType type;
  RecordStatus status;
  int? dataStartOffset;
  DatabaseRecord({
    this.id = 0,
    required this.type,
    this.status = RecordStatus.active,
    this.dataStartOffset,
  });

  //NEED TO OVERRIDE
  int get headerSize;
  Future<void> write(RandomAccessFile raf);

  Future<void> deleteAsMark(RandomAccessFile raf) async {
    if (dataStartOffset == null) {
      SmDbEventsListener.instance.add(
        DBRecordDeleteAsMarkError(message: 'dataStartOffset is null'),
      );
      return;
    }
    final current = await raf.position();
    //data offset ကို header size လျော့ထား
    await raf.setPosition(dataStartOffset! - headerSize);
    // delete
    status = RecordStatus.delete;
    //delete mark ထား
    await raf.writeByte(status.index);

    await raf.setPosition(current);
  }
}
