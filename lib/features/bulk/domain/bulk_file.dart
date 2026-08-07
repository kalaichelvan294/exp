import 'dart:convert';

// File payload models for bulk downloads and uploads.

/// A generated file returned by a download endpoint
/// ({ fileName, base64, contentType }).
class BulkFile {
  const BulkFile({
    required this.fileName,
    required this.base64,
    required this.contentType,
  });

  final String fileName;
  final String base64;
  final String contentType;

  /// Decoded file bytes.
  List<int> get bytes => base64Decode(base64);

  factory BulkFile.fromJson(Map<String, dynamic> json) => BulkFile(
        fileName: (json['fileName'] ?? '').toString(),
        base64: (json['base64'] ?? '').toString(),
        contentType: (json['contentType'] ?? '').toString(),
      );
}

/// A file chosen by the user for upload.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  bool get isEmpty => bytes.isEmpty;
}
