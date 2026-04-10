import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/records/db_records.dart';

class CoverRecord extends DatabaseRecord {
  Uint8List? imageBytes;
  int size;
  CoverRecord({
    super.type = RecordType.cover,
    super.dataStartOffset = -1,
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
    if (imageBytes == null) throw Exception('imageBytes is null');

    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt64(2, imageBytes!.length);
    // write header
    await raf.writeFrom(header.buffer.asUint8List());
    // set info
    dataStartOffset = await raf.position();
    size = imageBytes!.length;

    await raf.writeFrom(imageBytes!);
    imageBytes = null; // Memory clean
  }

  Future<Uint8List?> getData(RandomAccessFile raf) async {
    if (dataStartOffset == -1 || size == 0) return null;

    final current = await raf.position();
    // set
    await raf.setPosition(dataStartOffset);
    final data = await raf.read(size);
    await raf.setPosition(current);

    return data;
  }

  static Future<CoverRecord?> read(RandomAccessFile raf) async {
    // Status နဲ့ Type ကို အပြင်မှာ ဖတ်ပြီးသားမို့ Size (8 bytes) ကိုပဲ ဖတ်တော့မယ်
    final sizeBytes = await raf.read(8);
    if (sizeBytes.length < 8) return null;

    final size = ByteData.sublistView(sizeBytes).getInt64(0);
    final dataOffset = await raf.position();

    // Data ကို ကျော်သွားမယ် (နောက် record ဖတ်လို့ရအောင်)
    await raf.setPosition(dataOffset + size);

    final record = CoverRecord(size: size, dataStartOffset: dataOffset);
    return record;
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
