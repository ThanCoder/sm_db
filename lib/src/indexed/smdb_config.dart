typedef OnNeedToCompactCallback =
    bool Function(int deletedCount, int deletedSize);

bool defaultCompackLogic(int deletedCount, int deletedSize) =>
    deletedSize > 2048 || deletedCount > 100; // size > 2MB Or count > 100

class SMDBConfig {
  final bool autoCompact;
  final bool saveLocalIndexLockFile;

  ///
  /// `Default` [size > 2MB Or count > 100]
  ///
  final OnNeedToCompactCallback needToCompact;

  final String dbType;
  final int dbVersion;

  const SMDBConfig({
    required this.autoCompact,
    required this.saveLocalIndexLockFile,
    required this.needToCompact,
    required this.dbType,
    required this.dbVersion,
  });

  factory SMDBConfig.empty() {
    return SMDBConfig(
      autoCompact: false,
      saveLocalIndexLockFile: false,
      needToCompact: defaultCompackLogic,
      dbType: 'SMDB',
      dbVersion: 1,
    );
  }

  SMDBConfig copyWith({
    bool? autoCompact,
    bool? saveLocalIndexLockFile,
    OnNeedToCompactCallback? needToCompact,
    String? dbType,
    int? dbVersion,
  }) {
    return SMDBConfig(
      autoCompact: autoCompact ?? this.autoCompact,
      saveLocalIndexLockFile:
          saveLocalIndexLockFile ?? this.saveLocalIndexLockFile,
      needToCompact: needToCompact ?? this.needToCompact,
      dbType: dbType ?? this.dbType,
      dbVersion: dbVersion ?? this.dbVersion,
    );
  }
}
