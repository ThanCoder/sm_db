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
  int id;
  final int offset;
  final RecordType type;

  DatabaseRecord({required this.offset, this.id = -1, required this.type});

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
}
