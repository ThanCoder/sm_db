// ignore_for_file: unused_field
import 'dart:io';

enum RecordType { cover, json, file }

enum RecordStatus { delete, active }

abstract class DatabaseRecord {
  final RecordType type;
  RecordStatus status;
  DatabaseRecord({required this.type, this.status = RecordStatus.active});

  //NEED TO OVERRIDE
  int get headerSize;
  Future<void> write(RandomAccessFile raf);
}
