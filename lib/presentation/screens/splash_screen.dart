import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/license_service.dart';
import '../../core/services/splash_init_cache.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/formatter.dart';
import '../../data/repositories/settings_repository.dart';
import '../providers/app_state.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';
import 'pos_dashboard_screen.dart';
import 'setup_wizard_screen.dart';

/// Branded splash — matches native launch screen, runs init, then fades in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minDisplay = Duration(milliseconds: 900);

  String? _error;
  LocalBackupInfo? _restoreCandidate;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrap());
    });
    // Hard exit — no async/DB; prevents full UI freeze if SQLite blocks the isolate.
    Future.delayed(const Duration(milliseconds: 2500), _hardExitToLogin);
  }

  void _hardExitToLogin() {
    if (!mounted || _navigated || _error != null) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _handleDbFailure(String message) async {
    LocalBackupInfo? latest;
    if (!kIsWeb) {
      try {
        latest = await BackupService.instance
            .getLatestLocalBackup()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _error = message;
      _restoreCandidate = latest;
    });
  }

  Future<void> _restoreFromLatest() async {
    final candidate = _restoreCandidate;
    if (candidate == null) return;

    setState(() {
      _restoring = true;
      _error = null;
    });

    final result = await BackupService.instance.restoreFromPath(candidate.path);
    if (!mounted) return;

    if (result.ok) {
      setState(() {
        _restoring = false;
        _restoreCandidate = null;
        _error = null;
      });
      _bootstrap();
    } else {
      setState(() {
        _restoring = false;
        _error = result.message;
      });
    }
  }

  Future<void> _applyBackupHealthWarning() async {
    if (!mounted || kIsWeb) return;
    final health = await BackupService.instance.evaluateBackupHealth();
    if (!mounted) return;
    context.read<AppState>().setBackupWarning(
          health.isStale ? health.message : null,
        );
  }

  Future<void> _finishStartup({
    required DateTime started,
    required bool isInitialized,
  }) async {
    if (!kIsWeb) {
      unawaited(
        BackupService.instance.scheduledAutoBackup().then((_) async {
          await _applyBackupHealthWarning();
        }),
      );
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minDisplay) {
      await Future.delayed(_minDisplay - elapsed);
    }
    if (!mounted || _navigated) return;
    await SplashInitCache.write(isInitialized);
    await _navigateAway(isInitialized: isInitialized);
  }

  Future<void> _navigateAway({required bool isInitialized}) async {
    if (!mounted || _navigated) return;
    _navigated = true;

    final next =
        isInitialized ? const LoginScreen() : const SetupWizardScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _exitSplashSafely() async {
    if (_navigated || !mounted) return;
    _hardExitToLogin();
  }

  Future<void> _bootstrap() async {
    if (_navigated) return;
    final started = DateTime.now();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_navigated && _error == null) {
        setState(() => _showSkip = true);
      }
    });

    try {
      await _runBootstrapSteps(
        started: started,
        onProgress: (step) {
          if (mounted) setState(() => _status = step);
        },
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('เริ่มต้นระบบใช้เวลานานเกินไป'),
      );
    } on TimeoutException {
      await _exitSplashSafely();
    } catch (e) {
      await _handleDbFailure('ฐานข้อมูลมีปัญหา: $e');
    }
  }

  String _status = 'กำลังเริ่มต้นระบบ…';
  bool _showSkip = false;
  bool _navigated = false;

  Future<void> _resolveLicenseInBackground() async {
    try {
      final verified =
          (await SettingsRepository().get('license_verified', defaultValue: 'false')) ==
              'true';
      if (!verified) return;

      final resolved = await LicenseService.instance
          .resolveLicenseOnStartup()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      context.read<AppState>().setLicenseType(resolved.licenseType);
    } catch (_) {}
  }

  Future<void> _runBootstrapSteps({
    required DateTime started,
    void Function(String step)? onProgress,
  }) async {
    if (_navigated) return;

    bool isInitialized = false;
    String licenseType = 'free';

    onProgress?.call('กำลังเปิดฐานข้อมูล…');
    if (_navigated) return;
    await DatabaseService.instance.database.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('เปิดฐานข้อมูลช้าเกินไป'),
    );
    final health = await DatabaseService.instance
        .startupHealthCheck()
        .timeout(const Duration(seconds: 5));
    if (!health.ok) {
      if (!_navigated) await _handleDbFailure(health.message);
      return;
    }

    if (_navigated) return;
    onProgress?.call('กำลังเตรียมระบบ…');
    BackupService.instance.init();
    unawaited(TtsService.instance.init());

    final settings = SettingsRepository();
    isInitialized =
        (await settings.get('is_initialized', defaultValue: 'false')) == 'true';
    await SplashInitCache.write(isInitialized);
    licenseType = await LicenseService.instance.getLicenseType();
    unawaited(_resolveLicenseInBackground());

    if (mounted) {
      context.read<AppState>().setLicenseType(licenseType);
    }

    if (isInitialized && mounted) {
      onProgress?.call('กำลังเข้าสู่ระบบ…');
      final restored = await AuthSessionService.instance
          .tryRestoreLogin()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (restored != null && mounted) {
        final app = context.read<AppState>();
        app.setUser(restored.user);
        app.setShift(restored.shift);

        if (!kIsWeb) {
          unawaited(
            BackupService.instance.scheduledAutoBackup().then((_) async {
              await _applyBackupHealthWarning();
            }),
          );
        }

        final elapsed2 = DateTime.now().difference(started);
        if (elapsed2 < _minDisplay) {
          await Future.delayed(_minDisplay - elapsed2);
        }
        if (!mounted || _navigated) return;
        _navigated = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PosDashboardScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        return;
      }
    }

    await _finishStartup(started: started, isInitialized: isInitialized);
  }

  Future<void> _skipToLogin() async {
    await _exitSplashSafely();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = size.shortestSide * 0.22;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.corporateBlueDark,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.corporateBlueDark, AppColors.corporateBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppLogo(
                    size: logoSize.clamp(96.0, 160.0),
                    showName: true,
                    showTagline: true,
                    nameColor: AppColors.white,
                    taglineColor: AppColors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 48),
                  if (_restoring)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.white,
                      ),
                    )
                  else if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                    if (_restoreCandidate != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'พบไฟล์สำรองล่าสุด:\n${_restoreCandidate!.name}\n'
                          '${Fmt.dateTime(_restoreCandidate!.modifiedAt)} · ${_restoreCandidate!.sizeLabel}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _restoreFromLatest,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.corporateBlueDark,
                        ),
                        child: const Text('กู้คืนจาก backup ล่าสุด'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _restoreCandidate = null;
                        });
                        _bootstrap();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.white),
                      ),
                      child: const Text('ลองใหม่'),
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    if (_showSkip) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _skipToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.white),
                        ),
                        child: const Text('ข้าม — เข้าสู่ระบบ'),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'v${AppConstants.appVersion}',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
