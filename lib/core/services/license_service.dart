import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import '../models/license_resolve_result.dart';
import '../../data/repositories/settings_repository.dart';

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const String _apiEndpoint =
      'https://ttmb-tech.com/license-services/api/verify.php';
  static const String _productVerifyEndpoint =
      'https://ttmb-tech.com/license/api.php';
  static const int defaultGraceDays = 7;
  static const String _keyLastVerifiedAt = 'license_last_verified_at';
  final _settings = SettingsRepository();

  /// Reads tier from verify API — supports several field names from server.
  /// Returns empty string when package is not present in the payload.
  static String parseLicenseType(Map<String, dynamic> data) {
    final maps = <Map<String, dynamic>>[data];
    for (final nested in [
      data['data'],
      data['product'],
      data['license'],
      data['result'],
    ]) {
      if (nested is Map<String, dynamic>) maps.add(nested);
    }

    for (final map in maps) {
      for (final key in [
        'license_type',
        'package',
        'package_type',
        'plan',
        'tier',
        'product_package',
        'license_package',
        'subscription',
        'subscription_type',
        'product_type',
      ]) {
        final v = map[key];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s.toLowerCase();
      }
    }
    return '';
  }

  static String displayLicenseType(String type) {
    switch (type.toLowerCase()) {
      case 'pro':
        return 'Pro';
      case 'standard':
        return 'Standard';
      case 'enterprise':
        return 'Enterprise';
      case 'free':
        return 'Free';
      default:
        if (type.isEmpty) return 'Free';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      return 'web-client';
    }
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return 'unknown-device';
  }

  Future<Map<String, dynamic>> getTrackingInfo() async {
    final Map<String, dynamic> info = {
      'device_model': 'Unknown',
      'os_version': 'Unknown',
      'app_version': 'Unknown',
      'latitude': null,
      'longitude': null,
    };

    try {
      final deviceInfo = DeviceInfoPlugin();
      final pkgInfo = await PackageInfo.fromPlatform();
      info['app_version'] = '${pkgInfo.version}+${pkgInfo.buildNumber}';

      if (kIsWeb) {
        info['device_model'] = 'Browser';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        info['device_model'] = ios.utsname.machine;
        info['os_version'] = ios.systemVersion;
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        info['device_model'] = android.model;
        info['os_version'] = android.version.release;
      }

      // Location tracking
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          info['latitude'] = pos.latitude;
          info['longitude'] = pos.longitude;
        }
      }
    } catch (e) {
      debugPrint('Tracking info error: $e');
    }
    return info;
  }

  /// ตรวจสอบ Product Key (Setup Wizard — GET)
  Future<Map<String, dynamic>> verifyProductKey(
    String productKey, {
    bool preserveTypeIfMissing = false,
  }) async {
    final key = productKey.trim();
    if (key.isEmpty) {
      return {'success': false, 'message': 'กรุณากรอก Product Key'};
    }

    try {
      final uri = Uri.parse(_productVerifyEndpoint).replace(
        queryParameters: {
          'product_id': key,
          'action': 'verify',
        },
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 20));
      final body = response.body.trim();

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message':
              'Server ตอบ ${response.statusCode}${body.isEmpty ? '' : ': ${body.length > 120 ? '${body.substring(0, 120)}…' : body}'}',
        };
      }

      if (body.isEmpty) {
        return {'success': false, 'message': 'Server ตอบว่าง (ไม่มี JSON)'};
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'message': 'รูปแบบข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง',
        };
      }

      final ok = response.statusCode == 200 &&
          (data['success'] == true || data['status'] == 'success');
      if (ok) {
        final fromApi = parseLicenseType(data);
        final packageFromApi = fromApi.isNotEmpty;
        String licenseType;
        if (packageFromApi) {
          licenseType = fromApi;
        } else if (preserveTypeIfMissing) {
          licenseType =
              await _settings.get('license_type', defaultValue: 'standard');
        } else {
          licenseType = 'standard';
        }

        await _settings.set('license_key', key);
        await _settings.set('license_token', data['token']?.toString() ?? '');
        await _settings.set(
          'license_customer_name',
          data['customer_name']?.toString() ?? '',
        );
        if (packageFromApi || !preserveTypeIfMissing) {
          await _settings.set('license_type', licenseType);
        }
        await _settings.set('license_verified', 'true');
        await _markVerifiedNow();
        if (data['expires_at'] != null) {
          await _settings.set('license_expiry', data['expires_at'].toString());
        }
        return {
          'success': true,
          'type': licenseType,
          'package_from_api': packageFromApi,
          'token': data['token'],
          'customer_name': data['customer_name'],
          if (!packageFromApi)
            'message':
                'Server ไม่ส่ง package (license_type/package) — แอปใช้ ${displayLicenseType(licenseType)}',
        };
      }

      return {
        'success': false,
        'message': data['message']?.toString() ?? 'ไม่สามารถยืนยัน License ได้',
      };
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้: $e'};
    }
  }

  Future<bool> isLicenseVerified() async {
    return (await _settings.get('license_verified', defaultValue: 'false')) ==
        'true';
  }

  Future<Map<String, dynamic>> activate(String key) async {
    final deviceId = await getDeviceId();
    final tracking = await getTrackingInfo();
    
    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'license_key': key,
          'device_id': deviceId,
          ...tracking,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final map =
            data is Map<String, dynamic> ? data : <String, dynamic>{};
        final fromApi = parseLicenseType(map);
        final licenseType =
            fromApi.isNotEmpty ? fromApi : 'standard';
        await _settings.set('license_key', key);
        await _settings.set('license_type', licenseType);
        if (data['token'] != null) {
          await _settings.set('license_token', data['token'].toString());
        }
        await _settings.set('license_expiry', data['expires_at'] ?? '');
        await _settings.set('license_verified', 'true');
        await _markVerifiedNow();
        return {'success': true, 'type': licenseType};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Activation failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<String> getLicenseToken() async =>
      await _settings.get('license_token', defaultValue: '');

  Future<String> getLicenseType() async {
    return await _settings.get('license_type', defaultValue: 'free');
  }

  Future<bool> isPro() async {
    final type = await getLicenseType();
    return type.toLowerCase() == 'pro';
  }

  Future<Map<String, String>> getStoredLicenseInfo() async {
    final token = await getLicenseToken();
    return {
      'key': await _settings.get('license_key', defaultValue: ''),
      'type': await _settings.get('license_type', defaultValue: 'free'),
      'verified':
          await _settings.get('license_verified', defaultValue: 'false'),
      'customer_name':
          await _settings.get('license_customer_name', defaultValue: ''),
      'expiry': await _settings.get('license_expiry', defaultValue: ''),
      'token': token,
      'token_hint': tokenHint(token),
      'has_token': token.isNotEmpty ? 'true' : 'false',
    };
  }

  static String tokenHint(String token) {
    if (token.isEmpty) return '';
    if (token.length <= 8) return '••••••••';
    return '••••${token.substring(token.length - 6)}';
  }

  /// Re-verify stored key against server (sync package/tier).
  Future<Map<String, dynamic>> refreshStoredLicense() async {
    final key = await _settings.get('license_key', defaultValue: '');
    if (key.trim().isEmpty) {
      return {'success': false, 'message': 'ไม่มี Product Key'};
    }
    return verifyProductKey(key, preserveTypeIfMissing: true);
  }

  Future<void> _markVerifiedNow() async {
    await _settings.set(
      _keyLastVerifiedAt,
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastVerifiedAt() async {
    final raw = await _settings.get(_keyLastVerifiedAt, defaultValue: '');
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> getGraceDays() async {
    final raw =
        await _settings.get('license_offline_grace_days', defaultValue: '7');
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1) return defaultGraceDays;
    return parsed.clamp(1, 30);
  }

  @visibleForTesting
  static bool isWithinGracePeriod({
    required DateTime? lastVerifiedAt,
    required DateTime now,
    required int graceDays,
  }) {
    if (lastVerifiedAt == null) return false;
    final until = lastVerifiedAt.add(Duration(days: graceDays));
    return !now.isAfter(until);
  }

  @visibleForTesting
  static int graceDaysRemaining({
    required DateTime? lastVerifiedAt,
    required DateTime now,
    required int graceDays,
  }) {
    if (lastVerifiedAt == null) return 0;
    final until = lastVerifiedAt.add(Duration(days: graceDays));
    final remaining = until.difference(now).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  Future<LicenseGraceStatus> getGraceStatus({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final verified = await isLicenseVerified();
    if (!verified) return const LicenseGraceStatus();

    final graceDays = await getGraceDays();
    var lastVerified = await getLastVerifiedAt();
    if (lastVerified == null) {
      await _markVerifiedNow();
      lastVerified = clock;
    }

    final until = lastVerified.add(Duration(days: graceDays));
    final active = isWithinGracePeriod(
      lastVerifiedAt: lastVerified,
      now: clock,
      graceDays: graceDays,
    );
    final remaining = graceDaysRemaining(
      lastVerifiedAt: lastVerified,
      now: clock,
      graceDays: graceDays,
    );

    return LicenseGraceStatus(
      active: active,
      expired: !active,
      graceDays: graceDays,
      lastVerifiedAt: lastVerified,
      graceUntil: until,
      daysRemaining: remaining,
    );
  }

  /// Startup / background sync — online refresh with offline grace fallback.
  Future<LicenseResolveResult> resolveLicenseOnStartup({
    Duration networkTimeout = const Duration(seconds: 10),
  }) async {
    final verified = await isLicenseVerified();
    final cachedType = await getLicenseType();
    if (!verified) {
      return LicenseResolveResult(licenseType: cachedType);
    }

    var lastVerified = await getLastVerifiedAt();
    if (lastVerified == null) {
      await _markVerifiedNow();
      lastVerified = DateTime.now();
    }

    Map<String, dynamic> refresh;
    try {
      refresh = await refreshStoredLicense().timeout(networkTimeout);
    } catch (_) {
      refresh = {
        'success': false,
        'message': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
        'offline': true,
      };
    }

    if (refresh['success'] == true) {
      final type = await getLicenseType();
      return LicenseResolveResult(
        licenseType: type,
        syncedOnline: true,
        message: refresh['message']?.toString(),
      );
    }

    final grace = await getGraceStatus();
    if (grace.active) {
      return LicenseResolveResult(
        licenseType: cachedType,
        offlineGrace: true,
        message: grace.displayMessage,
        grace: grace,
      );
    }

    return LicenseResolveResult(
      licenseType: cachedType,
      graceExpired: true,
      message: refresh['message']?.toString() ?? grace.displayMessage,
      grace: grace,
    );
  }
}
