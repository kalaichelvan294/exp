class ItemImageLocation {
  const ItemImageLocation({
    required this.fileName,
    this.networkUrl,
    this.filePath,
  });

  final String fileName;
  final String? networkUrl;
  final String? filePath;
}

class ItemImagePath {
  ItemImagePath._();

  static String fileNameForSku(String sku) => '${sku.trim()}_MASTER.jpg';

  static String trainingFileNameForSku(
    String sku,
    String variant, {
    String extension = 'jpg',
  }) {
    return '${sku.trim()}_${variant.trim()}.$extension';
  }

  static Iterable<String> trainingFileNamesForSku(String sku) sync* {
    const variants = ['master', '1', '2', '3', '4', '5'];
    const extensions = ['jpg', 'jpeg', 'png'];
    for (final variant in variants) {
      for (final extension in extensions) {
        yield trainingFileNameForSku(sku, variant, extension: extension);
      }
    }
  }

  static ItemImageLocation resolve({
    required String sku,
    required String configuredRootPath,
    required String fallbackHost,
  }) {
    final fileName = fileNameForSku(sku);
    final root = configuredRootPath.trim();
    if (root.isEmpty) {
      final fallback = Uri(
        scheme: 'http',
        host: fallbackHost,
        port: 3000,
        pathSegments: ['images', fileName],
      ).toString();
      return ItemImageLocation(fileName: fileName, networkUrl: fallback);
    }

    final lower = root.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final base = Uri.parse(root);
      final joined = base.replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          fileName,
        ],
      );
      return ItemImageLocation(
        fileName: fileName,
        networkUrl: joined.toString(),
      );
    }

    if (lower.startsWith('file://')) {
      final dir = Uri.parse(root).toFilePath(windows: true);
      return ItemImageLocation(
        fileName: fileName,
        filePath: _joinPath(dir, fileName),
      );
    }

    return ItemImageLocation(
      fileName: fileName,
      filePath: _joinPath(root, fileName),
    );
  }

  static String? resolveStorageDirectory(String configuredRootPath) {
    final root = configuredRootPath.trim();
    if (root.isEmpty) return null;
    final lower = root.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return null;
    }
    if (lower.startsWith('file://')) {
      return Uri.parse(root).toFilePath(windows: true);
    }
    return root;
  }

  static String _joinPath(String root, String fileName) {
    final normalizedRoot = root.replaceAll(RegExp(r'[\\\/]+$'), '');
    if (normalizedRoot.isEmpty) return fileName;
    if (normalizedRoot.contains(r'\')) return '$normalizedRoot\\$fileName';
    return '$normalizedRoot/$fileName';
  }
}
