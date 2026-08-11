import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:yomu/yomu.dart';

import '../../../core/database/db_connection.dart';
import '../../../core/database/db_providers.dart';
import '../../../core/images/item_image_path.dart';
import '../../billing/domain/product.dart';
import '../domain/vision_embedding_service.dart';

class EmbeddingRefreshSummary {
  const EmbeddingRefreshSummary({
    required this.productsIndexed,
    required this.imagesIndexed,
    required this.barcodeUpdates,
    required this.productsSkipped,
  });

  final int productsIndexed;
  final int imagesIndexed;
  final int barcodeUpdates;
  final int productsSkipped;
}

class ImageSearchMatch {
  const ImageSearchMatch({
    required this.product,
    required this.similarity,
    required this.imageUrl,
  });

  final Product product;
  final double similarity;
  final String imageUrl;
}

class _StoredEmbedding {
  const _StoredEmbedding({
    required this.productId,
    required this.imageUrl,
    required this.embedding,
  });

  final String productId;
  final String imageUrl;
  final List<double> embedding;
}

class ProductEmbeddingRepository {
  ProductEmbeddingRepository(this._db, this._vision);

  final DbConnection _db;
  final VisionEmbeddingService _vision;

  List<_StoredEmbedding>? _cache;
  Map<String, Product>? _productCache;

  String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

  List<double> _parseEmbedding(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => (e as num).toDouble()).toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((e) => (e as num).toDouble())
            .toList(growable: false);
      }
    }
    return const [];
  }

  Future<Map<String, Product>> _loadProducts() async {
    final cached = _productCache;
    if (cached != null) return cached;
    final rows = await _db.query('SELECT * FROM products');
    final products = <String, Product>{};
    for (final row in rows) {
      final product = Product.fromJson(row);
      products[product.id] = product;
    }
    _productCache = products;
    return products;
  }

  Future<List<_StoredEmbedding>> _loadEmbeddings() async {
    final cached = _cache;
    if (cached != null) return cached;

    final rows = await _db.query(
      'SELECT product_id, image_url, embedding FROM product_embeddings',
    );
    final embeddings = <_StoredEmbedding>[];
    for (final row in rows) {
      final productId = (row['product_id'] ?? '').toString().trim();
      final imageUrl = (row['image_url'] ?? '').toString().trim();
      final vector = _parseEmbedding(row['embedding']);
      if (productId.isEmpty || imageUrl.isEmpty || vector.isEmpty) {
        continue;
      }
      embeddings.add(
        _StoredEmbedding(
          productId: productId,
          imageUrl: imageUrl,
          embedding: vector,
        ),
      );
    }
    _cache = embeddings;
    return embeddings;
  }

  void _invalidateCache() {
    _cache = null;
    _productCache = null;
  }

  Future<EmbeddingRefreshSummary> rebuildIndex({
    required String imagesRootPath,
    required bool cleanupTrainingImages,
  }) async {
    final storageRoot = ItemImagePath.resolveStorageDirectory(imagesRootPath);
    if (storageRoot == null || storageRoot.trim().isEmpty) {
      throw StateError('Item images root path must point to a local folder.');
    }
    final root = Directory(storageRoot);
    if (!await root.exists()) {
      throw StateError('Item images root folder does not exist.');
    }

    final products = await _db.query(
      'SELECT * FROM products ORDER BY id',
    );
    var productsIndexed = 0;
    var imagesIndexed = 0;
    var barcodeUpdates = 0;
    var productsSkipped = 0;

    for (final row in products) {
      final product = Product.fromJson(row);
      final files = await _collectTrainingImages(root, product.sku);
      if (files == null) {
        productsSkipped++;
        continue;
      }

      final embeddings = <Map<String, Object?>>[];
      String? detectedBarcode;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final vector = await _vision.embedImage(bytes);
        embeddings.add({
          'image_url': file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : file.path,
          'embedding': vector,
        });
        detectedBarcode ??= _decodeBarcode(bytes);
      }

      if (embeddings.isEmpty) {
        productsSkipped++;
        continue;
      }

      final escapedId = product.id.replaceAll("'", "''");
      await _db.execute(
        "DELETE FROM product_embeddings WHERE product_id = '$escapedId'",
      );
      for (final embedding in embeddings) {
        final imageUrl = (embedding['image_url'] ?? '').toString();
        final vector = embedding['embedding'] as List<double>;
        await _db.execute(
          "INSERT INTO product_embeddings (product_id, image_url, embedding) VALUES (${_sqlString(product.id)}, ${_sqlString(imageUrl)}, ${_sqlString(jsonEncode(vector))})",
        );
      }

      if (cleanupTrainingImages) {
        await _deleteTrainingVariants(root, product.sku);
      }

      if (detectedBarcode != null &&
          detectedBarcode.trim().isNotEmpty &&
          detectedBarcode.trim() != product.barcode.trim()) {
        await _db.execute(
          "UPDATE products SET barcode = ${_sqlString(detectedBarcode.trim())} WHERE id = ${_sqlString(product.id)}",
        );
        barcodeUpdates++;
      }

      productsIndexed++;
      imagesIndexed += embeddings.length;
    }

    _invalidateCache();
    return EmbeddingRefreshSummary(
      productsIndexed: productsIndexed,
      imagesIndexed: imagesIndexed,
      barcodeUpdates: barcodeUpdates,
      productsSkipped: productsSkipped,
    );
  }

  Future<ImageSearchMatch?> findBestMatchFromImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return findBestMatchFromImageBytes(bytes);
  }

  Future<String?> decodeBarcodeFromImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return _decodeBarcode(bytes);
  }

  Future<ImageSearchMatch?> findBestMatchFromImageBytes(
    List<int> bytes,
  ) async {
    final queryVector = await _vision.embedImage(Uint8List.fromList(bytes));
    final embeddings = await _loadEmbeddings();
    if (embeddings.isEmpty) return null;

    final products = await _loadProducts();
    ImageSearchMatch? best;

    final bestByProduct = <String, ImageSearchMatch>{};
    for (final embedding in embeddings) {
      final product = products[embedding.productId];
      if (product == null) continue;
      final score = _cosineSimilarity(queryVector, embedding.embedding);
      final current = bestByProduct[embedding.productId];
      if (current == null || score > current.similarity) {
        bestByProduct[embedding.productId] = ImageSearchMatch(
          product: product,
          similarity: score,
          imageUrl: embedding.imageUrl,
        );
      }
    }

    for (final candidate in bestByProduct.values) {
      final currentBest = best;
      if (currentBest == null || candidate.similarity > currentBest.similarity) {
        best = candidate;
      }
    }
    return best;
  }

  Future<List<File>?> _collectTrainingImages(Directory root, String sku) async {
    final master = await _findExistingFile(
      root,
      sku,
      const ['master'],
    );
    if (master == null) return null;

    final variants = <File>[master];
    for (final variant in const ['1', '2', '3', '4', '5']) {
      final variantFile = await _findExistingFile(
        root,
        sku,
        [variant],
      );
      if (variantFile != null) {
        variants.add(variantFile);
      }
    }

    if (variants.length < 2) {
      return null;
    }
    return variants;
  }

  Future<File?> _findExistingFile(
    Directory root,
    String sku,
    List<String> variants,
  ) async {
    for (final variant in variants) {
      for (final extension in const ['jpg', 'jpeg', 'png']) {
        final candidate = File(
          _joinPath(
            root.path,
            ItemImagePath.trainingFileNameForSku(
              sku,
              variant,
              extension: extension,
            ),
          ),
        );
        if (await candidate.exists()) {
          return candidate;
        }
      }
    }
    return null;
  }

  Future<void> _deleteTrainingVariants(Directory root, String sku) async {
    for (final variant in const ['1', '2', '3', '4', '5']) {
      for (final extension in const ['jpg', 'jpeg', 'png']) {
        final candidate = File(
          _joinPath(
            root.path,
            ItemImagePath.trainingFileNameForSku(
              sku,
              variant,
              extension: extension,
            ),
          ),
        );
        if (await candidate.exists()) {
          await candidate.delete();
        }
      }
    }
  }

  String _joinPath(String root, String fileName) {
    final normalizedRoot = root.replaceAll(RegExp(r'[\\\/]+$'), '');
    if (normalizedRoot.isEmpty) return fileName;
    if (normalizedRoot.contains(r'\')) return '$normalizedRoot\\$fileName';
    return '$normalizedRoot/$fileName';
  }

  String? _decodeBarcode(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return null;

    final image = YomuImage.rgba(
      bytes: decoded.getBytes(order: img.ChannelOrder.rgba),
      width: decoded.width,
      height: decoded.height,
    );
    try {
      return Yomu.all.decode(image).text.trim();
    } on YomuException {
      return null;
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    if (length == 0) return 0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < length; i++) {
      final av = a[i];
      final bv = b[i];
      dot += av * bv;
      normA += av * av;
      normB += bv * bv;
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    if (denom == 0) return 0;
    return dot / denom;
  }
}

final productEmbeddingRepositoryProvider =
    Provider<ProductEmbeddingRepository>(
  (ref) => ProductEmbeddingRepository(
    ref.watch(dbConnectionProvider),
    VisionEmbeddingService.instance,
  ),
);
