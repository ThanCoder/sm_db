import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/indexed/smdb_config.dart';
import 'package:sm_db/src/records/db_records.dart';

class JsonRecord extends DatabaseRecord {
  final int adapterTypeId;
  final int parentId;
  int jsonSize;
  Uint8List? jsonBytes;
  JsonRecord({
    super.type = RecordType.json,
    super.dataStartOffset,
    this.adapterTypeId = 0,
    this.parentId = -1,
    this.jsonSize = 0,
    this.jsonBytes,
    required super.id,
  });

  @override
  int get headerSize => 27;

  /// --- JSON RECORD ---
  /// Header (27 bytes): [Status(1)][Type(1)][AdapterTypeId(1)][ID(8)][ParentID(8)][DataSize(8)]
  ///
  @override
  Future<void> write(RandomAccessFile raf, {SMDBConfig? config}) async {
    if (jsonBytes == null) throw Exception('jsonBytes required in JsonRecord');

    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt8(2, adapterTypeId);
    header.setInt64(3, id);
    header.setInt64(11, parentId);
    header.setInt64(19, jsonBytes!.length);

    // wirte
    await raf.writeFrom(header.buffer.asUint8List());
    // set json data start offset
    dataStartOffset = await raf.position();
    // set json bytes length
    jsonSize = jsonBytes!.length;

    await raf.writeFrom(jsonBytes!);
  }

  Future<Uint8List?> getJsonData(RandomAccessFile raf) async {
    if (dataStartOffset == -1) return null;
    await raf.setPosition(dataStartOffset);
    final jsonData = await raf.read(jsonSize);
    return jsonData;
  }

  static Future<JsonRecord?> read(RandomAccessFile raf) async {
    final meta = ByteData.sublistView(
      await raf.read(25),
    ); // status,type ကို လျော့ထားပေးရမယ်
    final adapterTypeId = meta.getInt8(0);
    final id = meta.getInt64(1);
    final parentId = meta.getInt64(9);
    final jsonSize = meta.getInt64(17);
    var dataStartOffset = -1;

    dataStartOffset = await raf.position();
    // skip position
    await raf.setPosition(dataStartOffset + jsonSize);

    // final jsonData = await raf.read(jsonSize);
    return JsonRecord(
      id: id,
      parentId: parentId,
      adapterTypeId: adapterTypeId,
      dataStartOffset: dataStartOffset,
      jsonSize: jsonSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'adapterTypeId': adapterTypeId,
      'type': type.name,
      'dataStartOffset': dataStartOffset,
    };
  }
}
