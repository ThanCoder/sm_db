import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/extensions/smdb_byte_data_extensions.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/records/db_records.dart';

class CoverRecord extends DatabaseRecord {
  final Uint8List imageBytes;

  const CoverRecord({
    required this.imageBytes,
    required super.offset,
    super.type = RecordType.cover,
  });

  // factory CoverRecord.fromPath(String path) {
  //   final file = File(path);
  //   final imageBytes = file.readAsBytesSync();
  //   return CoverRecord(imageBytes: imageBytes);
  // }

  @override
  int getDataSize() {
    return imageBytes.length;
  }

  @override
  int get headerSize => coverHeaderSize;

  @override
  Future<int> write(RandomAccessFile raf) async {
    final offset = await raf.position();

    final header = ByteData(headerSize);

    header.setInt1Byte(0, RecordStatus.active.index);
    header.setInt1Byte(1, type.index);
    header.setInt8Bytes(2, imageBytes.length);
    final builder = BytesBuilder(copy: false);
    // add header
    builder.add(header.buffer.asUint8List());
    // add image data
    builder.add(imageBytes);

    await raf.writeFrom(builder.takeBytes());

    return offset;
  }

  @override
  int getTotalRecordSize() {
    return offset + headerSize + imageBytes.length;
  }

  static Future<RecordMeta> readMeta(RandomAccessFile raf) async {
    final headerOffset = (await raf.position()) - 2; //status,type
    final data = ByteData.sublistView(await raf.read(coverHeaderSize - 2));
    final size = data.getInt8Bytes(0);
    final recordTotalSize = coverHeaderSize + size;

    //ခုန်ကျော်မယ်
    final endPos = await raf.position();
    await raf.setPosition(endPos + size);

    return RecordMeta(
      type: RecordType.cover,
      offset: headerOffset,
      recordTotalSize: recordTotalSize,
      dataSize: size,
    );
  }
}
