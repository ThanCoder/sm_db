import 'dart:io';

import 'package:sm_db/src/events/event_bus.dart';
import 'package:sm_db/src/indexed/smdb_config.dart';
import 'package:sm_db/src/indexed/indexed_db.dart';
import 'package:sm_db/src/utils/json_db_adapter.dart';
import 'package:sm_db/src/utils/json_db_box.dart';

class SMDB {
  // singleton
  static SMDB? _instance;
  static SMDB getInstance() {
    _instance ??= SMDB();
    return _instance!;
  }

  late String path;
  final IndexedDB _indexedDB = IndexedDB();
  bool _isInitializing = false;
  final EventBus eventBus = EventBus();
  // adapter
  final Map<Type, SMDBJsonAdapter> _adapters = {};
  final Map<Type, JsonDBBox> _boxs = {};

  ///
  /// ### Database Open
  ///
  Future<void> open(
    String dbPath, {
    SMDBConfig? config,
    bool databaseIfOpenWillCloseReOpen = false,
  }) async {
    if (isOpened && databaseIfOpenWillCloseReOpen) {
      await close(isClearAllAdapter: true);
    }
    if (isOpened && !databaseIfOpenWillCloseReOpen) return;

    path = dbPath;
    _indexedDB.setConfig(
      db: this,
      dbFile: File(path),
      config: config ?? SMDBConfig.empty(),
    );

    await _indexedDB.loadIndexed();
    _isInitializing = true;
  }

  ///
  /// ### Set Adapter`<T>`
  ///
  /// Usage `db.registerAdapterNotExists<User>(UserAdapter());`
  ///
  void registerAdapterNotExists<T>(SMDBJsonAdapter<T> adapter) {
    if (_adapters.containsKey(T)) return;
    final ids = _adapters.values.map((e) => e.adapterTypeId);
    if (ids.contains(adapter.adapterTypeId)) {
      throw Exception(
        """ Duplicate Adapter: `${adapter.runtimeType}` Unique id detected: `${adapter.adapterTypeId}`\n---Please Change---
        @override
        int get adapterTypeId => `${adapter.adapterTypeId}`; <<<-----
        """,
      );
    }
    _adapters[T] = adapter;
    _boxs[T] = JsonDBBox<T>(db: this, indexedDB: _indexedDB, adapter: adapter);
  }

  ///
  /// ### Clear All Registered Adapter
  ///
  void clearAllAdapter() {
    _adapters.clear();
    _boxs.clear();
  }

  ///
  /// ### Get Adapter`<T>`
  ///
  SMDBJsonAdapter<T> getAdapter<T>() {
    if (_adapters[T] == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return _adapters[T] as SMDBJsonAdapter<T>;
  }

  ///
  /// ### Get Box`<T>`
  ///
  JsonDBBox<T> getBox<T>() {
    if (_boxs[T] == null) {
      throw Exception('No Adapter Registerd for type `$T`');
    }
    return _boxs[T] as JsonDBBox<T>;
  }

  ///
  /// ## Database Is Opened
  ///
  bool get isOpened {
    return _isInitializing;
  }

  ///
  /// ### Close Database
  ///
  /// No Working For Now
  ///
  Future<void> close({bool isClearAllAdapter = true}) async {
    _isInitializing = false;
    if (isClearAllAdapter) {
      clearAllAdapter();
    }
  }

  ///
  /// ### When Database Remove [`Auto Compact`];
  ///
  Future<void> mabyCompact() async {
    await _indexedDB.mabyCompact();
  }

  ///
  /// Reduce Removed Record List
  ///
  /// Or DB Clean Up
  ///
  ///  if (removeList.isEmpty) Not Do Anything.
  ///
  Future<void> compact({
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    await _indexedDB.compact(isCancelled: isCancelled, onProgress: onProgress);
  }

  ///
  /// ### Get CoverRecord
  ///
  // CoverRecord? get coverRecod => _indexedDB.getCoverRecord;

  ///
  /// ### Database Binary Last Index
  ///
  int get lastIndex => _indexedDB.lastIndex;

  int get deletedCount => _indexedDB.deletedCount;

  int get deletedSize => _indexedDB.deletedSize;

  (String, int)? get header => _indexedDB.header;

  ///
  /// Read Rader From Database Files
  ///
  static Future<(String, int)> readHeaderFromPath(
    String dbPath, {
    required String type,
    required int version,
  }) async {
    final raf = await File(dbPath).open();
    final res = await IndexedDB.readHeader(raf, type: type, version: version);
    await raf.close();
    return res;
  }
}
