/// Result of inspecting / validating an external FUEL POS database file.
class DatabaseImportReport {
  final bool ok;
  final String message;
  final int? fileVersion;
  final int expectedVersion;
  final List<String> missingTables;
  final String? stationName;
  final int userCount;
  final bool isInitialized;
  final bool needsMigration;

  const DatabaseImportReport({
    required this.ok,
    required this.message,
    this.fileVersion,
    required this.expectedVersion,
    this.missingTables = const [],
    this.stationName,
    this.userCount = 0,
    this.isInitialized = false,
    this.needsMigration = false,
  });

  String get versionLabel {
    if (fileVersion == null) return '-';
    if (needsMigration) {
      return 'v$fileVersion → v$expectedVersion';
    }
    return 'v$fileVersion';
  }
}
