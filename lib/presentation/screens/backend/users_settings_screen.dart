import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';

class UsersSettingsScreen extends StatefulWidget {
  const UsersSettingsScreen({super.key});

  @override
  State<UsersSettingsScreen> createState() => _UsersSettingsScreenState();
}

class _UsersSettingsScreenState extends State<UsersSettingsScreen> {
  final _repo = AuthRepository();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final u = await _repo.list();
    setState(() {
      _users = u;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final username = TextEditingController();
    final displayName = TextEditingController();
    final password = TextEditingController();
    String role = 'cashier';

    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'เพิ่มผู้ใช้',
      content: StatefulBuilder(
        builder: (context, setSt) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: username,
              decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: displayName,
              decoration: const InputDecoration(labelText: 'ชื่อแสดง'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'บทบาท'),
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('แคชเชียร์')),
                DropdownMenuItem(value: 'admin', child: Text('ผู้ดูแลระบบ')),
              ],
              onChanged: (v) => setSt(() => role = v ?? 'cashier'),
            ),
          ],
        ),
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'สร้าง',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (ok == true &&
        username.text.trim().isNotEmpty &&
        password.text.isNotEmpty) {
      await _repo.create(
        username: username.text,
        password: password.text,
        role: role,
        displayName: displayName.text,
      );
      await _load();
      if (mounted) ToastUtils.show(context, 'สร้างผู้ใช้แล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'ผู้ใช้งาน',
        subtitle: 'แคชเชียร์และผู้ดูแลระบบ',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.white),
            onPressed: _create,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: EdgeInsets.all(r.w(16)),
              itemCount: _users.length,
              separatorBuilder: (_, __) => SizedBox(height: r.h(8)),
              itemBuilder: (_, i) {
                final u = _users[i];
                return GlassCard(
                  padding: EdgeInsets.all(r.w(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isAdmin
                          ? AppColors.corporateBlueDark
                          : AppColors.corporateBlue,
                      child: Text(
                        u.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      u.displayName ?? u.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${u.username} • ${u.role == 'admin' ? 'ผู้ดูแล' : 'แคชเชียร์'}'),
                    trailing: Switch(
                      value: u.isActive,
                      onChanged: u.username == 'admin'
                          ? null
                          : (v) async {
                              await _repo.setActive(u.id, v);
                              await _load();
                            },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
