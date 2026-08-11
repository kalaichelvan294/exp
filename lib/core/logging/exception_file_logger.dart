import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExceptionFileLogger {
  const ExceptionFileLogger();

  static const String _logsFolderName = 'logs';
  static const String _logFileName = 'exceptions.txt';
  static const int _maxLogBytes = 10 * 1024 * 1024;
  static const int _retainLogBytes = 8 * 1024 * 1024;

  Future<void> logException({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    try {
      final file = await _resolveLogFile();
      final level = fatal ? 'FATAL' : 'ERROR';
      final now = DateTime.now().toUtc().toIso8601String();
      final record = StringBuffer()
        ..writeln('[$now] [$level] [$source]')
        ..writeln('message: ${error.toString()}');
      if (stackTrace != null) {
        record
          ..writeln('stacktrace:')
          ..writeln(stackTrace.toString().trimRight());
      }
      record.writeln('---');

      await file.writeAsString(
        record.toString(),
        mode: FileMode.append,
        flush: true,
      );
      await _trimIfNeeded(file);
    } catch (_) {
      // Intentionally ignored to avoid recursive failures during crash logging.
    }
  }

  Future<String?> exportLogFile() async {
    final file = await _resolveLogFile();
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    final suffix = _timestampForFileName();
    final path = await FilePicker.saveFile(
      dialogTitle: 'Download exception log',
      fileName: 'exceptions_$suffix.txt',
      bytes: Uint8List.fromList(bytes),
    );
    if (path == null) return null;

    final target = File(path);
    if (!await target.exists() || await target.length() == 0) {
      await target.writeAsBytes(bytes, flush: true);
    }
    return path;
  }

  Future<File> _resolveLogFile() async {
    final root = Directory.current.path;
    final logsDir = Directory(_joinPath(root, _logsFolderName));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    final file = File(_joinPath(logsDir.path, _logFileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> _trimIfNeeded(File file) async {
    final length = await file.length();
    if (length <= _maxLogBytes) return;

    final bytes = await file.readAsBytes();
    final start = bytes.length - _retainLogBytes;
    if (start <= 0) return;

    var adjustedStart = start;
    while (adjustedStart < bytes.length && bytes[adjustedStart] != 10) {
      adjustedStart++;
    }
    if (adjustedStart < bytes.length) {
      adjustedStart++;
    }
    final trimmed = bytes.sublist(adjustedStart.clamp(0, bytes.length));
    await file.writeAsBytes(trimmed, flush: true);
  }

  String _timestampForFileName() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  String _joinPath(String left, String right) {
    if (left.endsWith('\\') || left.endsWith('/')) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}

final exceptionFileLoggerProvider = Provider<ExceptionFileLogger>(
  (ref) => const ExceptionFileLogger(),
);
