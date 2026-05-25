import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/updater_service.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/shift.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../providers/app_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/primary_button.dart';
import 'pos_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthRepository();
  final _shiftRepo = ShiftRepository();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberUser = true;
  String? _error;
  String _stationName = AppConstants.appName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.instance.speak('ยินดีต้อนรับ กรุณาเข้าสู่ระบบ');
      UpdaterService.instance.checkForUpdate(context, silent: true);
      _loadPrefs();
    });
  }

  Future<void> _loadPrefs() async {
    final name = await SettingsRepository()
        .get('station_name', defaultValue: AppConstants.appName);
    final remember = await AuthSessionService.instance.rememberUsernameEnabled();
    final savedUser = await AuthSessionService.instance.rememberedUsername();
    if (!mounted) return;
    setState(() {
      _stationName = name;
      _rememberUser = remember;
      if (savedUser != null && savedUser.isNotEmpty) {
        _username.text = savedUser;
      }
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    var user = await _auth.login(_username.text, _password.text);
    if (user == null &&
        _username.text.trim().toLowerCase() ==
            AppConstants.defaultAdminUsername &&
        _password.text == AppConstants.defaultAdminPassword) {
      await DatabaseService.instance.resetAdminPasswordToDefault();
      user = await _auth.login(_username.text, _password.text);
    }

    if (!mounted) return;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
      });
      TtsService.instance.speak('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
      return;
    }

    await AuthSessionService.instance.setRememberUsername(
      _rememberUser,
      user.username,
    );

    final shift = await _resolveShift(user);
    if (!mounted) return;
    if (shift == null) {
      setState(() => _loading = false);
      return;
    }

    await _goDashboard(user, shift);
  }

  Future<Shift?> _resolveShift(AppUser user) async {
    var shift = await _shiftRepo.getOpenShiftForUser(user.id);
    if (shift != null) return shift;
    if (!mounted) return null;
    return OpenShiftDialog.show(context, userId: user.id);
  }

  Future<void> _goDashboard(AppUser user, Shift shift) async {
    final state = context.read<AppState>();
    state.setUser(user);
    state.setShift(shift);
    await AuthSessionService.instance.saveSession(
      username: user.username,
      userId: user.id,
      shiftId: shift.id,
    );
    SessionService.instance.reset();
    if (!mounted) return;
    setState(() => _loading = false);
    TtsService.instance.speak('ลงชื่อเข้าใช้ กะ ${shift.id}');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PosDashboardScreen()),
    );
  }

  Widget _buildForm(Responsive r, {bool compact = false}) {
    final titleSize = compact ? r.sp(18) : r.sp(20);
    final subSize = compact ? r.sp(11) : r.sp(13);
    final gapAfterTitle = compact ? r.h(2) : r.h(4);
    final gapBeforeFields = compact ? r.h(12) : r.h(20);
    final gapBetweenFields = compact ? r.h(10) : r.h(16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'เข้าสู่ระบบ',
          style: TextStyle(
            color: AppColors.corporateBlueDark,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: gapAfterTitle),
        Text(
          _stationName,
          style: TextStyle(
            color: AppColors.greyMedium,
            fontSize: subSize,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: gapBeforeFields),
        TextField(
          controller: _username,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'ชื่อผู้ใช้',
            isDense: true,
            prefixIcon: Icon(Icons.person_rounded,
                color: AppColors.corporateBlue),
          ),
        ),
        SizedBox(height: gapBetweenFields),
        TextField(
          controller: _password,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'รหัสผ่าน',
            isDense: true,
            prefixIcon: const Icon(Icons.lock_rounded,
                color: AppColors.corporateBlue),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: AppColors.corporateBlue,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: compact,
          visualDensity:
              compact ? VisualDensity.compact : VisualDensity.standard,
          value: _rememberUser,
          onChanged: (v) => setState(() => _rememberUser = v ?? true),
          title: Text(
            'จำชื่อผู้ใช้',
            style: TextStyle(fontSize: compact ? r.sp(12) : r.sp(14)),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(
              color: AppColors.redBright,
              fontSize: compact ? r.sp(11) : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? r.h(6) : r.h(8)),
        ],
        PrimaryButton(
          label: 'เข้าสู่ระบบ',
          icon: Icons.login_rounded,
          expand: true,
          onPressed: _submit,
          loading: _loading,
        ),
      ],
    );
  }

  Widget _buildFooter(Responsive r) {
    return Column(
      children: [
        Text(
          'v${AppConstants.appVersion}',
          style: TextStyle(
            color: AppColors.greyMedium,
            fontSize: r.sp(11),
          ),
        ),
        if (kDebugMode) ...[
          SizedBox(height: r.h(4)),
          TextButton(
            onPressed: _loading
                ? null
                : () async {
                    await DatabaseService.instance
                        .resetAdminPasswordToDefault();
                    if (!mounted) return;
                    setState(() {
                      _username.text = AppConstants.defaultAdminUsername;
                      _password.text = AppConstants.defaultAdminPassword;
                      _error = 'รีเซ็ต admin เป็น admin123 แล้ว — กดเข้าสู่ระบบ';
                    });
                  },
            child: Text(
              'รีเซ็ตรหัส admin (debug)',
              style: TextStyle(
                fontSize: r.sp(11),
                color: AppColors.greyMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSideBySide(
    Responsive r,
    BoxConstraints constraints,
  ) {
    final panelH = constraints.maxHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.w(820)),
      child: SizedBox(
        height: panelH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: AppLogoHero()),
            SizedBox(width: r.w(12)),
            Expanded(
              child: GlassCard(
                padding: EdgeInsets.symmetric(
                  horizontal: r.w(20),
                  vertical: r.h(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: box.maxWidth,
                              child: _buildForm(r, compact: true),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: r.h(4)),
                    _buildFooter(r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStacked(Responsive r) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.w(440)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppLogoHero(),
          SizedBox(height: r.h(16)),
          GlassCard(
            padding: EdgeInsets.all(r.w(24)),
            child: _buildForm(r),
          ),
          SizedBox(height: r.h(16)),
          Center(child: _buildFooter(r)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pad = EdgeInsets.symmetric(
      horizontal: r.w(20),
      vertical: r.h(12),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 640;

            if (sideBySide) {
              return Center(
                child: Padding(
                  padding: pad,
                  child: LayoutBuilder(
                    builder: (context, inner) =>
                        _buildSideBySide(r, inner),
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: pad,
                child: _buildStacked(r),
              ),
            );
          },
        ),
      ),
    );
  }
}
