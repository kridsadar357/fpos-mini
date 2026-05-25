import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Compress and store product photos locally.
class ProductImageUtil {
  ProductImageUtil._();

  static const maxBytes = 200 * 1024;
  static const maxDimension = 512;
  static const minJpegQuality = 50;

  static Future<String?> pickAndCompress({int? productId}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: 85,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final compressed = compressBytes(bytes);
    if (compressed == null) return null;

    return saveBytes(compressed, productId: productId);
  }

  static Uint8List? compressBytes(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return null;

    var image = _fitWithin(decoded, maxDimension);
    var quality = 85;
    var output = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (output.length > maxBytes && quality > minJpegQuality) {
      quality -= 10;
      output = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    var scale = 0.85;
    while (output.length > maxBytes && scale >= 0.35) {
      final w = (image.width * scale).round().clamp(64, maxDimension);
      final h = (image.height * scale).round().clamp(64, maxDimension);
      image = img.copyResize(image, width: w, height: h);
      output = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      scale -= 0.1;
    }

    return output.length <= maxBytes ? output : null;
  }

  static img.Image _fitWithin(img.Image source, int maxSide) {
    if (source.width <= maxSide && source.height <= maxSide) return source;

    final ratio = source.width / source.height;
    final int w;
    final int h;
    if (source.width >= source.height) {
      w = maxSide;
      h = (maxSide / ratio).round();
    } else {
      h = maxSide;
      w = (maxSide * ratio).round();
    }
    return img.copyResize(source, width: w, height: h);
  }

  static Future<String> saveBytes(Uint8List bytes, {int? productId}) async {
    if (kIsWeb) {
      throw UnsupportedError('Product images are stored on device only.');
    }
    final dir = await _imagesDir();
    final name = productId != null
        ? 'product_$productId.jpg'
        : 'product_tmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String?> finalizeTempPath(String tempPath, int productId) async {
    if (kIsWeb) return tempPath;
    final dir = await _imagesDir();
    final dest = File(p.join(dir.path, 'product_$productId.jpg'));
    final src = File(tempPath);
    if (!await src.exists()) return null;

    if (await dest.exists()) await dest.delete();
    if (p.basename(tempPath) == dest.path.split(Platform.pathSeparator).last) {
      return dest.path;
    }
    await src.copy(dest.path);
    if (src.path != dest.path) await src.delete();
    return dest.path;
  }

  static Future<void> deleteIfExists(String? path) async {
    if (kIsWeb || path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'product_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
