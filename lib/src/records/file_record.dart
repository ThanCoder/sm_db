import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sm_db/src/extensions/smdb_byte_data_extensions.dart';
import 'package:sm_db/src/indexed/record_meta.dart';
import 'package:sm_db/src/records/db_records.dart';

class FileRecord extends DatabaseRecord {
  final String name;
  final int fileSize;
  final int infoSize;
  final Map<String, dynamic> info;
  final String? sourcePath;

  FileRecord({
    required this.name,
    required this.fileSize,
    required this.infoSize,
    required this.info,
    required this.sourcePath,
    required super.offset,
    required super.id,
    super.type = RecordType.file,
  });

  @override
  int getDataSize() {
    return fileSize;
  }

  @override
  int getInfoSize() {
    return infoSize;
  }

  ///
  /// Header (Offset: 26) -> [Status(1),Type(1),ID(8),InfoSize(4),FileSize(8)]
  ///
  @override
  int get headerSize => fileHeaderSize;

  @override
  Future<int> write(
    RandomAccessFile raf, {
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    final startPosition = await raf.position();

    final infoBytes = utf8.encode(jsonEncode(info));
    final file = File(sourcePath!);
    final fSize = file.lengthSync();

    final header = ByteData(headerSize);
    header.setInt1Byte(0, RecordStatus.active.index);
    header.setInt1Byte(1, type.index);
    header.setInt8Bytes(2, id);
    header.setInt8Bytes(10, infoBytes.length);
    header.setInt8Bytes(18, fSize);
    final builder = BytesBuilder(copy: false);
    // add
    builder.add(header.buffer.asUint8List());
    builder.add(infoBytes);
    // write header
    await raf.writeFrom(builder.takeBytes());

    // write file
    final reader = await file.open();
    try {
      final int chunkSize = 1024 * 1024; //1MB
      final buffer = Uint8List(chunkSize);

      int totalWritten = 0;

      while (totalWritten < fSize) {
        if (isCancelled?.call() ?? false) {
          await reader.close();
          return startPosition;
        }

        final remaining = fSize - totalWritten;
        final toRead = remaining > chunkSize ? chunkSize : remaining;
        final bytesRead = await reader.readInto(buffer, 0, toRead);
        if (bytesRead <= 0) break;

        // write
        await raf.writeFrom(buffer, 0, bytesRead);
        totalWritten += bytesRead;

        // progress
        onProgress?.call(totalWritten / fSize);
      }
    } catch (e) {
      await reader.close();
    }

    return startPosition; // အောင်မြင်စွာ ရေးပြီးပြီ
  }

  @override
  int getTotalRecordSize() {
    return offset + headerSize + infoSize + fileSize;
  }

  static Future<RecordMeta> readMeta(
    RandomAccessFile raf,
    int headerOffset,
  ) async {
    // final headerOffset = (await raf.position()) - 2; //status,type
    final data = ByteData.sublistView(await raf.read(fileHeaderSize - 2));
    final id = data.getInt8Bytes(0);
    final infoSize = data.getInt8Bytes(8);
    final fileSize = data.getInt8Bytes(16);
    final recordTotalSize = fileHeaderSize + infoSize + fileSize;

    //ခုန်ကျော်မယ်
    final endPos = await raf.position();
    await raf.setPosition(endPos + infoSize + fileSize);

    return RecordMeta(
      type: RecordType.file,
      id: id,
      offset: headerOffset,
      recordTotalSize: recordTotalSize,
      dataSize: fileSize,
      fileInfoSize: infoSize,
    );
  }
}
