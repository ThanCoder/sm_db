import 'package:sm_db/sm_db.dart';
import 'package:sm_db/src/records/file_record.dart';

extension SmFileRecordExtensions on SMDB {
  ///
  /// ### Add Any File
  ///
  Future<(FileRecord, bool)> addFile(
    String path, {
    Map<String, dynamic> extraInfo = const {},
    bool Function()? isCancelledFile,
    void Function(double progress)? onProgressFile,
  }) async {
    final fileRecord = FileRecord.fromPath(
      path,
      extraInfo: extraInfo,
      id: lastIndex,
    );
    final (record, result) = await addRecord(
      fileRecord,
      isCancelledFile: isCancelledFile,
      onProgressFile: onProgressFile,
    );
    return (record as FileRecord, result);
  }

  ///
  /// ### Add Any Files
  ///
  Future<List<(FileRecord, bool)>> addFiles(
    List<String> pathList, {
    Map<String, dynamic> extraInfo = const {},
    bool Function()? isCancelledFile,
    void Function(double progress)? onProgressFile,
  }) async {
    final list = <(FileRecord, bool)>[];

    for (var path in pathList) {
      if (isCancelledFile?.call() ?? false) break;

      final record = FileRecord.fromPath(
        path,
        extraInfo: extraInfo,
        id: lastIndex,
      );
      final (re, result) = await addRecord(
        record,
        isCancelledFile: isCancelledFile,
        onProgressFile: onProgressFile,
      );
      list.add((re as FileRecord, result));
    }
    return list;
  }
}
