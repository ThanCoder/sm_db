// ignore_for_file: unused_field
import 'dart:io';

import 'package:sm_db/src/events/sm_db_events_listener.dart';

enum RecordType { cover, json, file }

enum RecordStatus { delete, active }

abstract class DatabaseRecord {
  int id;
  final RecordType type;
  RecordStatus status;
  int dataStartOffset;
  DatabaseRecord({
    this.id = 0,
    required this.type,
    this.status = RecordStatus.active,
    this.dataStartOffset = -1,
  });

  //NEED TO OVERRIDE
  int get headerSize;
  Future<void> write(RandomAccessFile raf);

  ///
  /// ### Delete Mark Database Record
  ///
  Future<RecordStatus> deleteAsMark(RandomAccessFile raf) async {
    if (dataStartOffset == -1) {
      SmDbEventsListener.instance.add(
        DBRecordDeleteAsMarkError(message: 'dataStartOffset is -1'),
      );
      // Offset မရှိရင် လက်ရှိ status အတိုင်းပဲ ပြန်ပို့မယ်
      return status;
    }

    final current = await raf.position();

    // 1. Header နေရာသို့ သွား၍ Status ကို Update လုပ်မည်
    await raf.setPosition(dataStartOffset - headerSize);

    // 2. Status ကို Delete အဖြစ် ပြောင်းလဲသတ်မှတ်မည်
    status = RecordStatus.delete;

    // 3. File ထဲသို့ Status Index ကို ရေးမည်
    await raf.writeByte(status.index);

    // 4. မူလ Position သို့ ပြန်သွားမည်
    await raf.setPosition(current);

    // 5. ပြောင်းလဲသွားသော Status ကို Return ပြန်ပေးမည်
    return status;
  }

  Future<void> transferRecord({
    required RandomAccessFile sourceRaf,
    required RandomAccessFile targetRaf,
    required int startOffset, // မူရင်းဖိုင်ထဲက record အစ
    required int recordTotalSize, // Header + Info + File အားလုံးပေါင်း size
    void Function(double progress)? onProgress, // Progress callback ထည့်မယ်
    bool Function()? isCancelled,
  }) async {
    await sourceRaf.setPosition(startOffset);

    int bytesCopied = 0;
    final bufferSize = 1024 * 1024; // 1MB

    while (bytesCopied < recordTotalSize) {
      if (isCancelled?.call() ?? false) {
        break;
      }
      final remaining = recordTotalSize - bytesCopied;
      final toRead = remaining < bufferSize ? remaining : bufferSize;

      final buffer = await sourceRaf.read(toRead);
      await targetRaf.writeFrom(buffer);

      bytesCopied += buffer.length;

      // Record တစ်ခုချင်းစီရဲ့ progress ကို callback ပေးမယ်
      if (onProgress != null) {
        onProgress(bytesCopied / recordTotalSize);
      }
    }
  }
}
