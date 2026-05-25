import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Captures uncaught Flutter/async errors to a rotating local log file.
class AppErrorService {
  AppErrorService._();

  static const _maxLogBytes = 512 * 1024;

  static Future<void> install() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(log(details.exception, details.stack));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(log(error, stack));
      return true;
    };
  }

  static Future<void> log(Object error, StackTrace? stack) async {
    if (kIsWeb) {
      debugPrint('[AppError] $error\n$stack');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'app_errors.log'));
      final stamp = DateTime.now().toIso8601String();
      final entry = StringBuffer()
        ..writeln('--- $stamp ---')
        ..writeln(error)
        ..writeln(stack ?? StackTrace.current)
        ..writeln();
      await file.writeAsString(entry.toString(), mode: FileMode.append);

      if (await file.length() > _maxLogBytes) {
        final text = await file.readAsString();
        await file.writeAsString(
          text.substring(text.length - (_maxLogBytes ~/ 2)),
        );
      }
    } catch (e) {
      debugPrint('[AppError] failed to write log: $e');
      debugPrint('[AppError] $error');
    }
  }
}
