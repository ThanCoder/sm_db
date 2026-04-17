// ignore_for_file: unused_field
import 'dart:io';

enum RecordType { cover, json, file }

enum RecordStatus { delete, active }

///  Header (10 bytes): [Status(1),Type(1),Size(8)]
const int coverHeaderSize = 10;

/// Header (27 bytes): [Status(1)][Type(1)][AdapterTypeId(1)][ID(8)][ParentID(8)][JsonDataSize(8)]
const int jsonHeaderSize = 27;

/// Header (26 bytes): [Status(1),Type(1),ID(8),InfoSize(8),FileSize(8)]
const int fileHeaderSize = 26;

abstract class DatabaseRecord {
  final int id;
  final int offset;
  final RecordType type;

  const DatabaseRecord({
    required this.offset,
    this.id = -1,
    required this.type,
  });

  //NEED TO OVERRIDE
  ///
  /// ### Need To Return Start Header `Offset`
  ///
  Future<int> write(RandomAccessFile raf);
  int getTotalRecordSize();
  int getDataSize();
  int getInfoSize() => 0;
  int getAdapterTypeId() => -1;
  int getParentId() => -1;
  int get headerSize;

  ///
  /// ### Delete Mark Database Record
  ///
  Future<bool> deleteAsMark(RandomAccessFile raf) async {
    if (offset == -1) return false;

    final current = await raf.position();

    // 1. Header နေရာသို့ သွား၍ Status ကို Update လုပ်မည်
    await raf.setPosition(offset - headerSize);

    // 3. File ထဲသို့ Status Index ကို ရေးမည်
    await raf.writeByte(RecordStatus.delete.index);

    // 4. မူလ Position သို့ ပြန်သွားမည်
    await raf.setPosition(current);

    return true;
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
