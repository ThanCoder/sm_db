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

  const SMDBConfig({
    this.autoCompact = true,
    this.saveLocalIndexLockFile = false,
    required this.needToCompact,
  });

  factory SMDBConfig.empty() {
    return SMDBConfig(
      autoCompact: false,
      saveLocalIndexLockFile: false,
      needToCompact: defaultCompackLogic,
    );
  }

  String compressJsonData(String data) {
    return data;
  }

  String decompressJsonData(String data) {
    return data;
  }

  SMDBConfig copyWith({
    bool? autoCompact,
    bool? saveLocalIndexLockFile,
    OnNeedToCompactCallback? needToCompact,
  }) {
    return SMDBConfig(
      autoCompact: autoCompact ?? this.autoCompact,
      saveLocalIndexLockFile:
          saveLocalIndexLockFile ?? this.saveLocalIndexLockFile,
      needToCompact: needToCompact ?? this.needToCompact,
    );
  }
}
