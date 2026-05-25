import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/widgets/primary_button.dart';

class UpdaterService {
  UpdaterService._();
  static final UpdaterService instance = UpdaterService._();

  static const String _versionUrl = 'https://ttmb-tech.com/license-services/release_mini_fuel_pos/version.json';

  Future<void> checkForUpdate(BuildContext context, {bool silent = false}) async {
    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final remoteVersion = data['version'] as String;
      final remoteBuild = data['build_number'] as int;
      final downloadUrl = data['url'] as String;
      final changelog = data['changelog'] as String? ?? 'ไม่มีข้อมูลการเปลี่ยนแปลง';

      final pkgInfo = await PackageInfo.fromPlatform();
      final localVersion = pkgInfo.version;
      final localBuild = int.tryParse(pkgInfo.buildNumber) ?? 0;
      
      if (!context.mounted) return;

      if (_isNewer(remoteVersion, remoteBuild, localVersion, localBuild)) {
        _showUpdateDialog(context, remoteVersion, downloadUrl, changelog);
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว')),
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  bool _isNewer(String remoteVer, int remoteBuild, String localVer, int localBuild) {
    // Basic comparison: Check build number first, then version string if needed
    if (remoteBuild > localBuild) return true;
    
    List<int> remoteParts = remoteVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> localParts = localVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < remoteParts.length; i++) {
       int localPart = i < localParts.length ? localParts[i] : 0;
       if (remoteParts[i] > localPart) return true;
       if (remoteParts[i] < localPart) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url, String changelog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.gold),
            const SizedBox(width: 10),
            Text('พบเวอร์ชันใหม่ ($version)', style: const TextStyle(color: AppColors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรุณาอัปเดตแอปเพื่อให้ทำงานได้อย่างมีประสิทธิภาพและปลอดภัยยิ่งขึ้น',
              style: TextStyle(color: AppColors.softGrey),
            ),
            const SizedBox(height: 16),
            const Text('สิ่งที่เปลี่ยนไป:', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(changelog, style: const TextStyle(color: AppColors.white, fontSize: 13)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'ไว้ทีหลัง',
                    style: TextStyle(color: AppColors.softGrey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'อัปเดตเลย',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ไม่สามารถเปิดลิงก์: $url')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
