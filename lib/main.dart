import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/app_error_service.dart';
import 'core/services/bluetooth_printer_service.dart';
import 'presentation/providers/app_state.dart';
import 'core/services/session_service.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppErrorService.install();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Keep status bar + home indicator visible so iPad is never "trapped" in the app.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const FuelPosApp());
}

class FuelPosApp extends StatelessWidget {
  const FuelPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<BluetoothPrinterService>(
          create: (_) => BluetoothPrinterService.instance,
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final existing = MediaQuery.textScalerOf(context);
          final clamped = existing.scale(1.0).clamp(0.9, 1.2);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(clamped),
            ),
            child: Theme(
              data: AppTheme.build(context),
              child: SessionActivityDetector(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
