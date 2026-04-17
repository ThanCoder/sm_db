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

  const FileRecord({
    required this.name,
    required this.fileSize,
    required this.infoSize,
    required this.info,
    required this.sourcePath,
    required super.offset,
    required super.id,
    super.type = RecordType.file,
  });

  // factory FileRecord.fromPath(
  //   String path, {
  //   Map<String, dynamic> extraInfo = const {},
  //   int id = -1,
  // }) {
  //   final file = File(path);
  //   if (!file.existsSync()) {
  //     throw PathNotFoundException(path, OSError('File Path Not Found!'));
  //   }
  //   return FileRecord(
  //     name: file.getName(),
  //     info: {
  //       'name': file.getName(),
  //       'ext': file.extName,
  //       'size': file.size,
  //       ...extraInfo,
  //     },
  //     id: id,
  //     sourcePath: path,
  //     fileSize: file.size,
  //   );
  // }

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
      int totalWritten = 0;

      while (totalWritten < fSize) {
        if (isCancelled?.call() ?? false) {
          await reader.close();
          return startPosition;
        }

        final remaining = fSize - totalWritten;
        final toRead = remaining > chunkSize ? chunkSize : remaining;
        final buffer = await reader.read(toRead);

        // write
        await raf.writeFrom(buffer);
        totalWritten += buffer.length;

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

  static Future<RecordMeta> readMeta(RandomAccessFile raf, int offset) async {
    final headerOffset = offset - 2; //status,type
    final data = ByteData.sublistView(await raf.read(fileHeaderSize - 2));
    final id = data.getInt8Bytes(0);
    final infoSize = data.getInt8Bytes(8);
    final fileSize = data.getInt8Bytes(16);
    final recordTotalSize = fileHeaderSize + infoSize + fileSize;

    return RecordMeta(
      type: RecordType.file,
      id: id,
      offset: headerOffset,
      recordTotalSize: recordTotalSize,
      dataSize: fileSize,
      fileInfoSize: infoSize,
    );
  }

  ///
  /// ## Extract File
  ///
  // Future<void> extract(
  //   RandomAccessFile raf, {
  //   required String savePath,
  //   bool Function()? isCancelled,
  //   void Function(double progress)? onProgress,
  // }) async {
  //   if (dataStartOffset == -1) {
  //     throw Exception('File `dataStartOffset` is -1');
  //   }
  //   final currentPos = await raf.position();
  //   // go to
  //   await raf.setPosition(dataStartOffset);

  //   // 2. Output file ကို အသစ်ဆောက်မည်
  //   final outputFile = File(savePath);
  //   final ios = await outputFile.open(mode: FileMode.write);

  //   int bytesReaded = 0;
  //   final int bufferSize = 1024 * 1024; //1MB

  //   while (bytesReaded < fileSize) {
  //     // Cancel လုပ်ထားလျှင် ရပ်မည်
  //     if (isCancelled != null && isCancelled()) {
  //       break;
  //     }
  //     // ကျန်ရှိသော byte ပမာဏနှင့် buffer size ထဲမှ အနည်းဆုံးကို ယူမည်
  //     final remaining = fileSize - bytesReaded;
  //     final toRead = remaining < bufferSize ? remaining : bufferSize;
  //     // Data ကို ဖတ်ပြီး အသစ်ထဲသို့ ရေးမည်
  //     final buffer = await raf.read(toRead);
  //     await ios.writeFrom(buffer);
  //     // add
  //     bytesReaded += buffer.length;
  //     // Progress ကို 0.0 မှ 1.0 ကြား တွက်ချက်ပေးမည်
  //     if (onProgress != null) {
  //       onProgress(bytesReaded / fileSize);
  //     }
  //   }

  //   await raf.setPosition(currentPos);
  //   await ios.close();
  // }

  // static Future<FileRecord?> read(RandomAccessFile raf) async {
  //   final meta = ByteData.sublistView(await raf.read(24));
  //   final id = meta.getInt64(0);
  //   final infoSize = meta.getInt64(8);
  //   final fileSize = meta.getInt64(16);
  //   // read info
  //   final info = jsonDecode(utf8.decode(await raf.read(infoSize)));

  //   final fileOffset = await raf.position();
  //   // skip ထားမယ် memory မှာမထားပဲ offset ပဲသိမ်းဆည်းထားမယ်
  //   await raf.setPosition(fileOffset + fileSize);

  //   return FileRecord(
  //     name: info['name'],
  //     info: info,
  //     id: id,
  //     fileSize: fileSize,
  //     infoSize: infoSize,
  //     dataStartOffset: fileOffset,
  //   );
  // }
}
