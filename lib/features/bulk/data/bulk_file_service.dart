import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bulk_file.dart';

/// Platform edge for choosing an upload file and saving a generated download.
///
/// Abstracted so the controller and widget tests never touch native plugins.
abstract class BulkFileService {
  /// Opens a picker for an .xlsx/.csv file. Returns null if the user cancels.
  Future<PickedFile?> pickSpreadsheet();

  /// Prompts for a save location and persists [file]. Returns the saved path,
  /// or null if the user cancels.
  Future<String?> saveDownload(BulkFile file);
}

/// Default desktop implementation using file_picker's native dialogs.
class PlatformBulkFileService implements BulkFileService {
  const PlatformBulkFileService();

  @override
  Future<PickedFile?> pickSpreadsheet() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    final bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) return null;
    return PickedFile(name: picked.name, bytes: bytes);
  }

  @override
  Future<String?> saveDownload(BulkFile file) async {
    final data = Uint8List.fromList(file.bytes);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save file',
      fileName: file.fileName,
      bytes: data,
    );
    if (path == null) return null;
    // On desktop file_picker writes the bytes itself; guarantee persistence in
    // case the platform only returned a target path.
    final target = File(path);
    if (!await target.exists() || await target.length() == 0) {
      await target.writeAsBytes(file.bytes, flush: true);
    }
    return path;
  }
}

final bulkFileServiceProvider = Provider<BulkFileService>(
  (ref) => const PlatformBulkFileService(),
);
