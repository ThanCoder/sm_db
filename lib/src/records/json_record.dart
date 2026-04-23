import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/extensions/smdb_byte_data_extensions.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/records/db_records.dart';

class JsonRecord extends DatabaseRecord {
  final int adapterTypeId;
  final int parentId;
  final int jsonSize;
  final Uint8List jsonBytes;

  const JsonRecord({
    required this.adapterTypeId,
    required this.parentId,
    required this.jsonSize,
    required this.jsonBytes,
    required super.offset,
    super.type = RecordType.json,
  });

  @override
  int getTotalRecordSize() {
    return offset + jsonHeaderSize + jsonSize;
  }

  @override
  int getDataSize() {
    return jsonSize;
  }

  /// Header (27 bytes): [Status(1)][Type(1)][AdapterTypeId(1)][ID(8)][ParentID(8)][JsonDataSize(8)]
  @override
  int get headerSize => jsonHeaderSize;

  @override
  Future<int> write(RandomAccessFile raf) async {
    final startOffset = await raf.position();

    final header = ByteData(headerSize);
    header.setInt1Byte(0, RecordStatus.active.index);
    header.setInt1Byte(1, type.index);
    header.setInt1Byte(2, adapterTypeId);
    header.setInt8Bytes(3, id);
    header.setInt8Bytes(11, parentId);
    header.setInt8Bytes(19, jsonSize);
    //builder
    final builder = BytesBuilder(copy: false);
    builder.add(header.buffer.asUint8List());
    builder.add(jsonBytes);
    // write
    await raf.writeFrom(builder.takeBytes());

    return startOffset;
  }

  static Future<RecordMeta> readMeta(RandomAccessFile raf) async {
    final headerOffset = (await raf.position()) - 2; //status,type
    final data = ByteData.sublistView(await raf.read(jsonHeaderSize - 2));

    final adapterTypeId = data.getInt1Byte(0);
    final id = data.getInt8Bytes(1);
    final parentId = data.getInt8Bytes(9);
    final jsonSize = data.getInt8Bytes(17);
    final recordTotalSize = jsonHeaderSize + jsonSize;

    //ခုန်ကျော်မယ်
    final endPos = await raf.position();
    await raf.setPosition(endPos + jsonSize);

    return RecordMeta(
      type: RecordType.json,
      id: id,
      adapterTypeId: adapterTypeId,
      parentId: parentId,
      offset: headerOffset,
      recordTotalSize: recordTotalSize,
      dataSize: jsonSize,
    );
  }
}
