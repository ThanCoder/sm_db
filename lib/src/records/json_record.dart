import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/indexed/smdb_config.dart';
import 'package:sm_db/src/records/db_records.dart';

class JsonRecord extends DatabaseRecord {
  final int adapterTypeId;
  final int parentId;
  final String jsonData;
  JsonRecord({
    super.type = RecordType.json,
    super.dataStartOffset,
    this.adapterTypeId = 0,
    this.parentId = 0,
    required super.id,
    required this.jsonData,
  });

  @override
  int get headerSize => 27;

  /// --- JSON RECORD ---
  /// Header (27 bytes): [Status(1)][Type(1)][AdapterTypeId(1)][ID(8)][ParentID(8)][DataSize(8)]
  ///
  @override
  Future<void> write(RandomAccessFile raf, {SMDBConfig? config}) async {
    String data = jsonData;
    if (config != null) {
      data = config.compressJsonData(jsonData);
    }
    final jsonBytes = utf8.encode(data);
    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt8(2, adapterTypeId);
    header.setInt64(3, id);
    header.setInt64(11, parentId);
    header.setInt64(19, jsonBytes.length);

    // wirte
    await raf.writeFrom(header.buffer.asUint8List());
    await raf.writeFrom(jsonBytes);
  }

  static Future<JsonRecord?> read(
    RandomAccessFile raf, {
    SMDBConfig? config,
  }) async {
    final meta = ByteData.sublistView(
      await raf.read(25),
    ); // status,type ကို လျော့ထားပေးရမယ်
    final adapterTypeId = meta.getInt8(0);
    final id = meta.getInt64(1);
    final parentId = meta.getInt64(9);
    final jsonSize = meta.getInt64(17);
    var dataStartOffset = -1;

    dataStartOffset = await raf.position();

    String jsonData = utf8.decode(await raf.read(jsonSize));
    if (config != null) {
      jsonData = config.decompressJsonData(jsonData);
    }
    return JsonRecord(
      id: id,
      jsonData: jsonData,
      parentId: parentId,
      adapterTypeId: adapterTypeId,
      dataStartOffset: dataStartOffset,
    );
  }
}
