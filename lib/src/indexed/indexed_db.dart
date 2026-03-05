// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/events/db_events.dart';
import 'package:sm_db/src/extensions/sm_db_record_extensions.dart';
import 'package:sm_db/src/indexed/db_config.dart';
import 'package:sm_db/src/records/cover_record.dart';
import 'package:sm_db/src/records/db_records.dart';

class IndexedDB {
  final File dbFile;
  final DBConfig config;
  final SMDB db;
  IndexedDB({required this.db, required this.dbFile, required this.config}) {
    _onEventListener();
  }

  int _lastIndex = 1;
  CoverRecord? _coverRecord;
  List<DatabaseRecord> _list = [];

  // getter
  int get lastIndex => _lastIndex;

  //setter
  void incrementLastIndex() {
    _lastIndex++;
  }

  Future<void> loadIndexed() async {
    if (!dbFile.existsSync()) return;
    _list = await db.readAll();
    int currentMax = -1;
    for (var e in _list) {
      if (e is CoverRecord && e.status == RecordStatus.active) {
        // check cover offset
        _coverRecord = e;
      } else if (e.id != -1) {
        if (e.id > currentMax) currentMax = e.id;
      }
    }
    if (currentMax != -1) {
      _lastIndex = currentMax + 1;
    }
  }

  ///
  /// ## CoverRecord?
  ///
  CoverRecord? get coverRecord => _coverRecord;

  ///
  /// ## Cover Image Data
  ///
  Future<Uint8List?> getCoverData() async {
    if (_coverRecord == null ||
        !dbFile.existsSync() ||
        _coverRecord!.dataStartOffset == null) {
      return null;
    }
    final raf = await dbFile.open();
    return await _coverRecord!.getData(raf);
  }

  Future<bool> deleteCover() async {
    if (_coverRecord == null) return false;
    final raf = await dbFile.open(mode: FileMode.writeOnlyAppend);

    await coverRecord!.deleteAsMark(raf);

    await raf.close();
    _coverRecord = null;
    return true;
  }

  ///
  /// ## Event Listener for DB
  ///
  void _onEventListener() {
    db.eventBus.on<DBEvent>().listen((event) {
      if (event is CoverOffsetChanged && _coverRecord != null) {
        _coverRecord!.copyWith(dataStartOffset: event.offset);
      }
      if (event is IncreLastIndex) {
        incrementLastIndex();
      }
    });
  }
}
