import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/file_record.dart';
import 'package:sm_db/src/records/json_record.dart';

void main() async {
  final db = SMDB();
  await db.open('test.db');

  // await db.addRecord(
  //   JsonRecord(id: 2, data: {'id': 2, 'name': 'thancoder json 2'}),
  // );
  // await db.addRecord(CoverRecord.fromPath('/home/thancoder/Pictures/images.jpeg'));

  // await db.addRecord(
  //   FileRecord.fromPath('/home/thancoder/Videos/Supernatural S1/11.mp4'),
  //   onProgress: (progress) => print('progress: ${(progress * 100).toStringAsFixed(2)}%'),

  // );

  final list = await db.readAll();
  print(list);
}
