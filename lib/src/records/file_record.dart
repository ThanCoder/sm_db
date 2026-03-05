import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_core_extensions/dart_core_extensions.dart';
import 'package:sm_db/src/records/db_records.dart';

///
/// Header (Offset: 26) -> [Status(1),Type(1),ID(8),InfoSize(8),FileSize(8)]
///
class FileRecord extends DatabaseRecord {
  final int fileSize;
  final Map<String, dynamic> info;
  final String? sourcePath;
  FileRecord({
    super.id = 0,
    required this.info,
    this.sourcePath,
    this.fileSize = 0,
    super.type = RecordType.file,
    super.dataStartOffset,
  });

  factory FileRecord.fromPath(
    String path, {
    Map<String, dynamic> extraInfo = const {},
    int id = -1,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      throw PathNotFoundException(path, OSError('File Path Not Found!'));
    }
    return FileRecord(
      info: {
        'name': file.getName(),
        'ext': file.extName,
        'size': file.size,
        ...extraInfo,
      },
      id: id,
      sourcePath: path,
    );
  }

  @override
  int get headerSize => 26;

  @override
  Future<bool> write(
    RandomAccessFile raf, {
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    if (sourcePath == null) return false;

    final infoBytes = utf8.encode(jsonEncode(info));
    final file = File(sourcePath!);
    final fSize = file.lengthSync();

    final header = ByteData(headerSize);
    header.setInt8(0, status.index);
    header.setInt8(1, type.index);
    header.setInt64(2, id);
    header.setInt64(10, infoBytes.length);
    header.setInt64(18, fSize);
    // write header
    await raf.writeFrom(header.buffer.asUint8List());
    await raf.writeFrom(infoBytes);

    // write file
    final reader = await file.open();
    final int chunkSize = 1024 * 1024; //1MB
    int totalWitten = 0;

    while (totalWitten < fSize) {
      if (isCancelled?.call() ?? false) {
        await reader.close();
        return false;
      }

      final remaining = fSize - totalWitten;
      final toRead = remaining > chunkSize ? chunkSize : remaining;
      final buffer = await reader.read(toRead);

      // write
      await raf.writeFrom(buffer);
      totalWitten += buffer.length;

      // progress
      onProgress?.call(totalWitten / fSize);
    }
    await reader.close();
    return true; // အောင်မြင်စွာ ရေးပြီးပြီ
  }

  static Future<FileRecord?> read(
    RandomAccessFile raf,
    RecordStatus status,
  ) async {
    final meta = ByteData.sublistView(await raf.read(24));
    final id = meta.getInt64(0);
    final infoSize = meta.getInt64(8);
    final fileSize = meta.getInt64(16);
    // read info
    final info = jsonDecode(utf8.decode(await raf.read(infoSize)));

    final fileOffset = await raf.position();
    // skip ထားမယ် memory မှာမထားပဲ offset ပဲသိမ်းဆည်းထားမယ်
    await raf.setPosition(fileOffset + fileSize);

    if (status == RecordStatus.delete) return null;

    return FileRecord(
      info: info,
      id: id,
      fileSize: fileSize,
      dataStartOffset: fileOffset,
    );
  }
}
