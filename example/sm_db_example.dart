import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/events/sm_db_events_listener.dart';
import 'package:sm_db/src/extensions/sm_db_record_extensions.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

void main() async {
  final db = SMDB();
  await db.open('test.db');

  SmDbEventsListener.instance.stream.listen((event) {
    print('$event: ${event.message}');
  });

  // await db.addRecord(
  //   JsonRecord(id: 1, data: {'id': 1, 'name': 'thancoder json 1'}),
  // );
  // await db.addRecord(
  //   JsonRecord(id: 2, data: {'id': 2, 'name': 'thancoder json 2'}),
  // );
  // await db.addRecord(
  //   JsonRecord(id: 3, data: {'id': 3, 'name': 'thancoder json 3'}),
  // );
  // await db.addRecord(CoverRecord.fromPath('/home/thancoder/Pictures/images.jpeg'));

  // await db.setCoverFormPath('/home/thancoder/Pictures/images.jpeg');

  // await db.addRecord(
  //   FileRecord.fromPath('/home/thancoder/Videos/Supernatural S1/11.mp4'),
  //   onProgressFile: (progress) => print('progress: ${(progress * 100).toStringAsFixed(2)}%'),

  // );

  final list1 = await db.readAll();

  await db.removeRecord(list1.first);

  final list = await db.readAll();

  print(list);
  for (var e in list) {
    if (e is JsonRecord) {
      print('adapterTypeId: ${e.adapterTypeId}');
      print('offset: ${e.dataStartOffset}');
      print(e.data);
    }
  }

  print('lastIndex: ${db.lastIndex}');
}
