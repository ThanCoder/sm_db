import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_core_extensions/dart_core_extensions.dart';
import 'package:sm_db/src/events/sm_db_events_listener.dart';
import 'package:sm_db/src/records/db_records.dart';

class FileRecord extends DatabaseRecord {
  final int fileSize;
  final Map<String, dynamic> info;
  final String? sourcePath;
  final String name;
  final int infoSize;
  FileRecord({
    super.id = 0,
    required this.info,
    required this.name,
    this.sourcePath,
    this.fileSize = 0,
    this.infoSize = 0,
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
      name: file.getName(),
      info: {
        'name': file.getName(),
        'ext': file.extName,
        'size': file.size,
        ...extraInfo,
      },
      id: id,
      sourcePath: path,
      fileSize: file.size,
    );
  }

  ///
  /// Header (Offset: 26) -> [Status(1),Type(1),ID(8),InfoSize(8),FileSize(8)]
  ///
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

  ///
  /// ### Delete Mark Database Record
  ///
  @override
  Future<RecordStatus> deleteAsMark(RandomAccessFile raf) async {
    if (dataStartOffset == null) {
      SmDbEventsListener.instance.add(
        DBRecordDeleteAsMarkError(message: 'dataStartOffset is null'),
      );
      // Offset မရှိရင် လက်ရှိ status အတိုင်းပဲ ပြန်ပို့မယ်
      return status;
    }

    final current = await raf.position();

    // 1. Header နေရာသို့ သွား၍ Status ကို Update လုပ်မည်
    await raf.setPosition((dataStartOffset! - infoSize) - headerSize);

    // 2. Status ကို Delete အဖြစ် ပြောင်းလဲသတ်မှတ်မည်
    status = RecordStatus.delete;

    // 3. File ထဲသို့ Status Index ကို ရေးမည်
    await raf.writeByte(status.index);

    // 4. မူလ Position သို့ ပြန်သွားမည်
    await raf.setPosition(current);

    // 5. ပြောင်းလဲသွားသော Status ကို Return ပြန်ပေးမည်
    return status;
  }

  ///
  /// ## Extract File
  ///
  Future<void> extract(
    RandomAccessFile raf, {
    required Directory outDir,
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    if (dataStartOffset == null) {
      throw Exception('File `dataStartOffset` is Null');
    }
    final currentPos = await raf.position();
    // go to
    await raf.setPosition(dataStartOffset!);

    // 2. Output file ကို အသစ်ဆောက်မည်
    final outputFile = File('${outDir.path}${Platform.pathSeparator}$name');
    final ios = await outputFile.open(mode: FileMode.write);

    int bytesReaded = 0;
    final int bufferSize = 1024 * 1024; //1MB

    while (bytesReaded < fileSize) {
      // Cancel လုပ်ထားလျှင် ရပ်မည်
      if (isCancelled != null && isCancelled()) {
        break;
      }
      // ကျန်ရှိသော byte ပမာဏနှင့် buffer size ထဲမှ အနည်းဆုံးကို ယူမည်
      final remaining = fileSize - bytesReaded;
      final toRead = remaining < bufferSize ? remaining : bufferSize;
      // Data ကို ဖတ်ပြီး အသစ်ထဲသို့ ရေးမည်
      final buffer = await raf.read(toRead);
      await ios.writeFrom(buffer);
      // add
      bytesReaded += buffer.length;
      // Progress ကို 0.0 မှ 1.0 ကြား တွက်ချက်ပေးမည်
      if (onProgress != null) {
        onProgress(bytesReaded / fileSize);
      }
    }

    await raf.setPosition(currentPos);
    await ios.close();
  }

  static Future<FileRecord?> read(RandomAccessFile raf) async {
    final meta = ByteData.sublistView(await raf.read(24));
    final id = meta.getInt64(0);
    final infoSize = meta.getInt64(8);
    final fileSize = meta.getInt64(16);
    // read info
    final info = jsonDecode(utf8.decode(await raf.read(infoSize)));

    final fileOffset = await raf.position();
    // skip ထားမယ် memory မှာမထားပဲ offset ပဲသိမ်းဆည်းထားမယ်
    await raf.setPosition(fileOffset + fileSize);

    return FileRecord(
      name: info['name'],
      info: info,
      id: id,
      fileSize: fileSize,
      infoSize: infoSize,
      dataStartOffset: fileOffset,
    );
  }

  FileRecord copyWith({
    int? fileSize,
    Map<String, dynamic>? info,
    String? sourcePath,
    String? name,
  }) {
    return FileRecord(
      fileSize: fileSize ?? this.fileSize,
      info: info ?? this.info,
      sourcePath: sourcePath ?? this.sourcePath,
      name: name ?? this.name,
    );
  }
}
