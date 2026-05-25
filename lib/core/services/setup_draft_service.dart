import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// เก็บความคืบหน้า Setup Wizard (ขั้น 1–5) ก่อนเปิดใช้งาน License สำเร็จ
class SetupDraftService {
  SetupDraftService._();
  static final SetupDraftService instance = SetupDraftService._();

  static const _key = 'setup_wizard_draft_v1';

  Future<void> save(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
