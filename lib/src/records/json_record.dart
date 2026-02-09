import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/records/db_records.dart';

/// --- JSON RECORD ---
/// Header (26 bytes): [Status(1)][Type(1)][ID(8)][ParentID(8)][DataSize(8)]
///
class JsonRecord extends DatabaseRecord {
  final int id, parentId;
  final Map<String, dynamic> data;
  JsonRecord({
    super.type = RecordType.json,
    this.parentId = 0,
    required this.id,
    required this.data,
  });

  @override
  Future<void> write(RandomAccessFile raf) async {
    final jsonBytes = utf8.encode(jsonEncode(data));
    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt64(2, id);
    header.setInt64(10, parentId);
    header.setInt64(18, jsonBytes.length);

    // wirte
    await raf.writeFrom(header.buffer.asUint8List());
    await raf.writeFrom(jsonBytes);
  }

  @override
  int get headerSize => 26;

  static Future<JsonRecord?> read(
    RandomAccessFile raf,
    RecordStatus status,
  ) async {
    final meta = ByteData.sublistView(
      await raf.read(24),
    ); // status,type ကို လျော့ထားပေးရမယ်
    final id = meta.getInt64(0);
    final parentId = meta.getInt64(8);
    final jsonSize = meta.getInt64(16);

    if (status == RecordStatus.delete) {
      await raf.setPosition((await raf.position()) + jsonSize);
      return null;
    }
    final data = jsonDecode(utf8.decode(await raf.read(jsonSize)));
    return JsonRecord(id: id, data: data, parentId: parentId);
  }
}
