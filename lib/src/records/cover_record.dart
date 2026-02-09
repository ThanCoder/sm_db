import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/records/db_records.dart';

///
/// Header (10 bytes): [Status(1),Type(1),Size(8)]
///
class CoverRecord extends DatabaseRecord {
  final Uint8List? imageBytes;
  final int? offset;
  final int? size;
  CoverRecord({
    super.type = RecordType.cover,
    this.offset,
    this.size = 0,
    this.imageBytes,
  });

  factory CoverRecord.fromPath(String path) {
    final file = File(path);
    final imageBytes = file.readAsBytesSync();
    return CoverRecord(imageBytes: imageBytes);
  }

  @override
  int get headerSize => 10;

  @override
  Future<void> write(RandomAccessFile raf) async {
    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt64(2, imageBytes!.length);
    // write header
    await raf.writeFrom(header.buffer.asUint8List());
    await raf.writeFrom(imageBytes!);
  }

  static Future<CoverRecord?> read(
    RandomAccessFile raf,
    RecordStatus status,
  ) async {
    final meta = ByteData.sublistView(await raf.read(8));
    final size = meta.getInt64(0);
    final offset = await raf.position();
    // skip
    await raf.setPosition(offset + size);

    if (status == RecordStatus.delete) {
      return null;
    }
    return CoverRecord(size: size, offset: offset);
  }
}
