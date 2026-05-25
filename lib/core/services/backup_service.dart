import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../../data/repositories/settings_repository.dart';
import 'database_import_report.dart';
import 'database_service.dart';
import 'license_service.dart';

class LocalBackupInfo {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;

  const LocalBackupInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get sizeLabel {
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

class BackupHealthStatus {
  final bool isStale;
  final int daysSinceLastBackup;
  final String? message;
  final LocalBackupInfo? latestLocalBackup;
  final bool hasNeverBackedUp;

  const BackupHealthStatus({
    required this.isStale,
    required this.daysSinceLastBackup,
    this.message,
    this.latestLocalBackup,
    this.hasNeverBackedUp = false,
  });

  static const ok = BackupHealthStatus(
    isStale: false,
    daysSinceLastBackup: 0,
  );
}

/// Backup service:
/// - Local export to app documents/backups/
/// - Restore (.db file picked via file_picker)
/// - Cloud backup via user-configurable HTTPS endpoint
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _maxLocalBackups = 10;
  static const _cloudMaxRetries = 3;
  static const _cloudTimeout = Duration(seconds: 60);

  void init() {}

  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<void> _trimOldBackups(Directory dir) async {
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.db'))
        .cast<File>()
        .toList();
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    for (var i = _maxLocalBackups; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  /// บันทึกสำรองลง local storage (โฟลเดอร์ backups ในแอป)
  Future<LocalBackupInfo?> saveToLocalStorage({String? label}) async {
    if (kIsWeb) return null;
    final dir = await _backupDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final prefix = label != null && label.isNotEmpty ? '${label}_' : '';
    final name = '${prefix}fuel_pos_$stamp.db';
    final destPath = p.join(dir.path, name);

    await DatabaseService.instance.copyDatabaseFile(destPath);

    final verify = await DatabaseService.instance.verifyBackupFile(destPath);
    if (!verify.ok) {
      try {
        await File(destPath).delete();
      } catch (_) {}
      return null;
    }

    final file = File(destPath);
    final stat = await file.stat();
    await _trimOldBackups(dir);

    final repo = SettingsRepository();
    await repo.set('last_local_backup_at', DateTime.now().toIso8601String());
    await repo.set(
      'local_backup_db_version',
      '${DatabaseService.schemaVersion}',
    );

    return LocalBackupInfo(
      path: destPath,
      name: name,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<List<LocalBackupInfo>> listLocalBackups() async {
    if (kIsWeb) return [];
    final dir = await _backupDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.db'))
        .cast<File>()
        .toList();
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    final list = <LocalBackupInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      list.add(LocalBackupInfo(
        path: f.path,
        name: p.basename(f.path),
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
      ));
    }
    return list;
  }

  Future<LocalBackupInfo?> getLatestLocalBackup() async {
    final list = await listLocalBackups();
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<({bool ok, String message})> restoreLatestLocalBackup() async {
    final latest = await getLatestLocalBackup();
    if (latest == null) {
      return (ok: false, message: 'ไม่พบไฟล์สำรองในเครื่อง');
    }
    return restoreFromPath(latest.path);
  }

  Future<BackupHealthStatus> evaluateBackupHealth() async {
    if (kIsWeb) return BackupHealthStatus.ok;

    final repo = SettingsRepository();
    DateTime? lastAt;

    final lastAtStr =
        await repo.get('last_local_backup_at', defaultValue: '');
    if (lastAtStr.isNotEmpty) {
      lastAt = DateTime.tryParse(lastAtStr);
    }

    LocalBackupInfo? latestFile;
    if (lastAt == null) {
      latestFile = await getLatestLocalBackup();
      lastAt = latestFile?.modifiedAt;
    }

    if (lastAt == null) {
      return BackupHealthStatus(
        isStale: true,
        daysSinceLastBackup: AppConstants.backupWarnDays + 1,
        hasNeverBackedUp: true,
        latestLocalBackup: latestFile,
        message: latestFile == null
            ? 'ยังไม่เคยสำรองข้อมูล — แนะนำบันทึกสำรองทันที'
            : 'ไม่พบบันทึกวันที่สำรองล่าสุด — แนะนำสำรองข้อมูลอีกครั้ง',
      );
    }

    final days = DateTime.now().difference(lastAt).inDays;
    if (days <= AppConstants.backupWarnDays) {
      return BackupHealthStatus(
        isStale: false,
        daysSinceLastBackup: days,
        latestLocalBackup: latestFile,
      );
    }

    return BackupHealthStatus(
      isStale: true,
      daysSinceLastBackup: days,
      latestLocalBackup: latestFile,
      message:
          'ไม่ได้สำรองข้อมูลมา $days วันแล้ว (เกิน ${AppConstants.backupWarnDays} วัน) — แนะนำสำรองทันที',
    );
  }

  Future<void> _recordCloudSuccess(String backupName, int bytes) async {
    final repo = SettingsRepository();
    final now = DateTime.now().toIso8601String();
    await repo.set('last_cloud_backup_at', now);
    await repo.set('last_cloud_backup_error', '');
    await repo.set('last_cloud_backup_status', 'ok');
    await repo.set(
      'last_cloud_backup_details',
      '$backupName ($bytes bytes)',
    );
  }

  Future<void> _recordCloudFailure(String error) async {
    final repo = SettingsRepository();
    await repo.set('last_cloud_backup_error', error);
    await repo.set('last_cloud_backup_status', 'failed');
    await repo.set(
      'last_cloud_backup_failed_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<({String endpoint, String token})> _resolveCloudCredentials() async {
    final repo = SettingsRepository();
    var endpoint =
        await repo.get('backup_cloud_endpoint', defaultValue: '');
    if (endpoint.isEmpty) {
      endpoint = AppConstants.cloudBackupEndpoint;
    }
    if (!endpoint.endsWith('/')) {
      endpoint = '$endpoint/';
    }

    var token = await repo.get('backup_cloud_token', defaultValue: '');
    if (token.isEmpty) {
      token = await repo.get('license_token', defaultValue: '');
    }

    return (endpoint: endpoint, token: token);
  }

  String _parseCloudError(String body, int statusCode) {
    if (body.isEmpty) return 'HTTP $statusCode';
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    } catch (_) {}
    return 'HTTP $statusCode';
  }

  bool _cloudUploadSucceeded(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data['success'] == true;
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  /// ใช้ token จาก hosting DB — ดึงจาก settings หรือ refresh verify
  Future<({bool ok, String message, String tokenHint})> ensureCloudToken({
    bool refreshFromServer = true,
  }) async {
    final repo = SettingsRepository();
    var token = await repo.get('backup_cloud_token', defaultValue: '');
    if (token.isEmpty) {
      token = await repo.get('license_token', defaultValue: '');
    }

    if (token.isNotEmpty) {
      return (
        ok: true,
        message: 'มี License token พร้อมใช้งาน',
        tokenHint: LicenseService.tokenHint(token),
      );
    }

    if (!refreshFromServer) {
      return (
        ok: false,
        message: 'ยังไม่มี token — กดซิงค์จาก License หรือวาง token จาก hosting',
        tokenHint: '',
      );
    }

    final refresh = await LicenseService.instance.refreshStoredLicense();
    if (refresh['success'] == true) {
      token = await repo.get('license_token', defaultValue: '');
      if (token.isEmpty) {
        token = await repo.get('backup_cloud_token', defaultValue: '');
      }
      if (token.isNotEmpty) {
        return (
          ok: true,
          message: 'ดึง token จาก server สำเร็จ',
          tokenHint: LicenseService.tokenHint(token),
        );
      }
      return (
        ok: false,
        message:
            'verify สำเร็จแต่ server ไม่ส่ง token — วาง token จาก hosting DB เอง',
        tokenHint: '',
      );
    }

    return (
      ok: false,
      message: refresh['message']?.toString() ?? 'ซิงค์ License ไม่สำเร็จ',
      tokenHint: '',
    );
  }

  Future<XFile?> exportLocal() async {
    final info = await saveToLocalStorage();
    if (info == null) return null;
    return XFile(info.path);
  }

  Future<void> shareLocalBackup() async {
    if (kIsWeb) return;
    final xFile = await exportLocal();
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    await Share.shareXFiles(
      [xFile],
      text: 'FUEL POS Backup (${bytes.length ~/ 1024} KB)',
    );
  }

  /// ให้ผู้ใช้เลือกโฟลเดอร์/ path บนเครื่อง (Android: Files / Downloads)
  Future<({bool ok, String message})> saveBackupToUserPath({
    String? existingPath,
  }) async {
    if (kIsWeb) {
      return (ok: false, message: 'ไม่รองรับบน Web');
    }

    final srcPath = existingPath ?? (await exportLocal())?.path;
    if (srcPath == null || !await File(srcPath).exists()) {
      return (ok: false, message: 'สร้างไฟล์สำรองไม่สำเร็จ');
    }

    try {
      final defaultName = p.basename(srcPath);
      final bytes = await File(srcPath).readAsBytes();
      final destPath = await FilePicker.platform.saveFile(
        dialogTitle: 'บันทึกไฟล์สำรอง',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: bytes,
      );

      if (destPath == null) {
        return (ok: false, message: 'ยกเลิกการบันทึก');
      }

      return (ok: true, message: 'บันทึกแล้ว');
    } catch (e) {
      return (ok: false, message: 'บันทึกไม่สำเร็จ: $e');
    }
  }

  Future<({bool ok, String message})> saveCsvToUserPath() async {
    if (kIsWeb) {
      return (ok: false, message: 'ไม่รองรับบน Web');
    }

    final xFile = await exportTransactionsCsv();
    if (xFile == null) {
      return (ok: false, message: 'สร้างไฟล์ CSV ไม่สำเร็จ');
    }

    try {
      final bytes = await File(xFile.path).readAsBytes();
      final destPath = await FilePicker.platform.saveFile(
        dialogTitle: 'บันทึกไฟล์ CSV',
        fileName: p.basename(xFile.path),
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (destPath == null) {
        return (ok: false, message: 'ยกเลิกการบันทึก');
      }

      return (ok: true, message: 'บันทึกแล้ว');
    } catch (e) {
      return (ok: false, message: 'บันทึกไม่สำเร็จ: $e');
    }
  }

  Future<DatabaseImportReport> validateImportFile(String sourcePath) =>
      DatabaseService.instance.validateImportFile(sourcePath);

  Future<({bool ok, String message})> restoreFromPath(
    String sourcePath, {
    bool safetyBackup = true,
  }) async {
    if (kIsWeb) return (ok: false, message: 'ไม่รองรับบน Web');
    if (!await File(sourcePath).exists()) {
      return (ok: false, message: 'ไม่พบไฟล์');
    }

    final preCheck = await DatabaseService.instance.validateImportFile(sourcePath);
    if (!preCheck.ok) {
      return (ok: false, message: preCheck.message);
    }

    if (safetyBackup) {
      try {
        await saveToLocalStorage(label: 'pre_restore');
      } catch (_) {}
    }

    await DatabaseService.instance.replaceDatabaseFile(sourcePath);

    final postCheck = await DatabaseService.instance.verifyCurrentSchema();
    if (!postCheck.ok) {
      return (ok: false, message: postCheck.message);
    }

    await DatabaseService.instance.finalizeAfterImport();

    final repo = SettingsRepository();
    await repo.set(
      'local_backup_db_version',
      '${DatabaseService.schemaVersion}',
    );

    return (ok: true, message: 'กู้คืนสำเร็จ (${postCheck.versionLabel})');
  }

  Future<({bool ok, String message})> restoreFromFile() async {
    if (kIsWeb) return (ok: false, message: 'ไม่รองรับบน Web');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );
    if (result == null || result.files.single.path == null) {
      return (ok: false, message: 'ยกเลิกการเลือกไฟล์');
    }
    return restoreFromPath(result.files.single.path!);
  }

  /// สำรองอัตโนมัติเมื่อ schema เปลี่ยนหรือครบ 24 ชม.
  Future<void> autoLocalBackupIfNeeded() async {
    if (kIsWeb) return;
    final repo = SettingsRepository();
    final enabled =
        (await repo.get('auto_local_backup_enabled', defaultValue: 'true')) ==
            'true';
    if (!enabled) return;

    final lastVerStr =
        await repo.get('local_backup_db_version', defaultValue: '0');
    final lastVer = int.tryParse(lastVerStr) ?? 0;
    final schemaChanged = lastVer < DatabaseService.schemaVersion;

    final lastAtStr =
        await repo.get('last_local_backup_at', defaultValue: '');
    var dueByTime = true;
    if (lastAtStr.isNotEmpty) {
      final lastAt = DateTime.tryParse(lastAtStr);
      if (lastAt != null) {
        dueByTime = DateTime.now().difference(lastAt).inHours >= 24;
      }
    }

    if (schemaChanged || dueByTime) {
      await saveToLocalStorage(
        label: schemaChanged ? 'schema_v${DatabaseService.schemaVersion}' : null,
      );
    }
  }

  Future<({bool ok, String message})> uploadToCloud({
    bool requireLocalFirst = true,
  }) async {
    final repo = SettingsRepository();
    final enabled =
        (await repo.get('backup_cloud_enabled', defaultValue: 'false')) ==
            'true';
    if (!enabled) return (ok: false, message: 'Cloud backup disabled');

    final creds = await _resolveCloudCredentials();
    final endpoint = creds.endpoint;
    var token = creds.token;
    if (endpoint.isEmpty) {
      await _recordCloudFailure('ยังไม่ได้ตั้งค่า endpoint');
      return (ok: false, message: 'No endpoint configured');
    }
    if (token.isEmpty) {
      try {
        final refresh = await LicenseService.instance.refreshStoredLicense();
        if (refresh['success'] == true) {
          token = await repo.get('license_token', defaultValue: '');
        }
      } catch (_) {}
    }
    if (token.isEmpty) {
      await _recordCloudFailure('ไม่มี License token — ตรวจสอบ Product Key ใหม่');
      return (
        ok: false,
        message: 'ไม่มี License token — ไปตั้งค่าทั่วไป → ตรวจสอบ License ใหม่',
      );
    }

    LocalBackupInfo? localInfo;
    if (requireLocalFirst) {
      localInfo = await saveToLocalStorage(label: 'cloud');
      if (localInfo == null) {
        const msg = 'สร้างสำรองในเครื่องไม่สำเร็จ — ยกเลิกอัปโหลดคลาวด์';
        await _recordCloudFailure(msg);
        return (ok: false, message: msg);
      }
    } else {
      final exported = await exportLocal();
      if (exported == null) {
        const msg = 'Local export failed';
        await _recordCloudFailure(msg);
        return (ok: false, message: msg);
      }
      localInfo = LocalBackupInfo(
        path: exported.path,
        name: p.basename(exported.path),
        sizeBytes: await File(exported.path).length(),
        modifiedAt: DateTime.now(),
      );
    }

    final bytes = await File(localInfo.path).readAsBytes();
    var lastError = 'Unknown error';

    for (var attempt = 1; attempt <= _cloudMaxRetries; attempt++) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(endpoint))
          ..headers['X-License-Token'] = token
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              localInfo.path,
              filename: localInfo.name,
            ),
          );

        final streamed = await request.send().timeout(_cloudTimeout);
        final response = await http.Response.fromStream(streamed);

        if (_cloudUploadSucceeded(response)) {
          var savedName = localInfo.name;
          var savedSize = bytes.length;
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            savedName = data['filename']?.toString() ?? savedName;
            savedSize = (data['size'] as num?)?.toInt() ?? savedSize;
          } catch (_) {}
          await _recordCloudSuccess(savedName, savedSize);
          return (
            ok: true,
            message: 'อัปโหลดสำเร็จ ($savedSize bytes)',
          );
        }
        lastError = _parseCloudError(response.body, response.statusCode);
      } on TimeoutException {
        lastError = 'หมดเวลา (${_cloudTimeout.inSeconds}s)';
      } catch (e) {
        lastError = 'Network error: $e';
      }

      if (attempt < _cloudMaxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    await _recordCloudFailure(lastError);
    return (
      ok: false,
      message: 'อัปโหลดล้มเหลวหลัง $_cloudMaxRetries ครั้ง: $lastError',
    );
  }

  Future<XFile?> exportTransactionsCsv({DateTime? from, DateTime? to}) async {
    final db = await DatabaseService.instance.database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('t.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('t.created_at <= ?');
      args.add(to.toIso8601String());
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT t.receipt_no, t.created_at, u.username, f.name as fuel, t.payment_method,
             t.liters, t.price_per_liter, t.subtotal,
             t.promotion_amount, t.discount_amount, t.total, t.received, t.change_amount
      FROM transactions t
      JOIN users u ON u.id = t.cashier_id
      JOIN fuel_types f ON f.id = t.fuel_type_id
      $whereClause
      ORDER BY t.created_at DESC
    ''', args);

    final header = [
      'Receipt',
      'Date',
      'Cashier',
      'Fuel',
      'Payment',
      'Liters',
      'Price/L',
      'Subtotal',
      'Promotion',
      'Discount',
      'Total',
      'Received',
      'Change',
    ].join(',');
    final body = rows.map((r) {
      return [
        r['receipt_no'],
        r['created_at'],
        r['username'],
        _csv(r['fuel']),
        r['payment_method'],
        r['liters'],
        r['price_per_liter'],
        r['subtotal'],
        r['promotion_amount'],
        r['discount_amount'],
        r['total'],
        r['received'],
        r['change_amount'],
      ].join(',');
    }).join('\n');

    if (kIsWeb) {
      return null;
    }
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final filePath = p.join(dir.path, 'transactions_$stamp.csv');
    final file = File(filePath);
    await file.writeAsString('$header\n$body', encoding: utf8);
    return XFile(filePath);
  }

  static String _csv(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(',') || s.contains('"')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<BackupHealthStatus> scheduledAutoBackup() async {
    await autoLocalBackupIfNeeded();
    final repo = SettingsRepository();
    final cloudEnabled =
        (await repo.get('backup_cloud_enabled', defaultValue: 'false')) ==
            'true';
    if (cloudEnabled) {
      await uploadToCloud();
    }
    return evaluateBackupHealth();
  }
}
