import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/records/db_records.dart';

class CoverRecord extends DatabaseRecord {
  final Uint8List? imageBytes;
  final int? size;
  CoverRecord({
    super.type = RecordType.cover,
    super.dataStartOffset,
    this.size = 0,
    this.imageBytes,
    super.id = 0,
  });

  factory CoverRecord.fromPath(String path) {
    final file = File(path);
    final imageBytes = file.readAsBytesSync();
    return CoverRecord(imageBytes: imageBytes);
  }

  @override
  int get headerSize => 10;

  ///
  /// Header (10 bytes): [Status(1),Type(1),Size(8)]
  ///
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

  Future<Uint8List?> getData(RandomAccessFile raf) async {
    if (dataStartOffset == null || size == null) return null;

    final current = await raf.position();
    await raf.setPosition(dataStartOffset!);

    final data = await raf.read(size!);

    await raf.setPosition(current);

    return data;
  }

  static Future<CoverRecord?> read(
    RandomAccessFile raf,
  ) async {
    final current = await raf.position();
    final meta = ByteData.sublistView(await raf.read(8));
    final size = meta.getInt64(0);
    final offset = await raf.position();
    // skip
    await raf.setPosition(offset + size);

    // if (status == RecordStatus.delete) {
    //   return null;
    // }
    await raf.setPosition(current);

    return CoverRecord(size: size, dataStartOffset: offset);
  }

  CoverRecord copyWith({
    Uint8List? imageBytes,
    int? dataStartOffset,
    int? size,
  }) {
    return CoverRecord(
      imageBytes: imageBytes ?? this.imageBytes,
      dataStartOffset: dataStartOffset ?? this.dataStartOffset,
      size: size ?? this.size,
    );
  }
}
