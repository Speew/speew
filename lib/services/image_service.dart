import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/utils.dart';

class ImageService {
  static const int maxImageSize = 800; 
  static const int maxImageSizeBytes = 500 * 1024; 
  static const int jpegQuality = 85;

  Future<String?> processAndSaveImage(File imageFile) async {
    try {
      
      final bytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        DebugUtils.logError('Failed to decode image');
        return null;
      }

      if (image.width > maxImageSize || image.height > maxImageSize) {
        image = _resizeImage(image, maxImageSize);
      }

      final compressed = img.encodeJpg(image, quality: jpegQuality);

      if (compressed.length > maxImageSizeBytes) {
        DebugUtils.log('Image too large after compression', tag: 'IMAGE');
        
        final moreCompressed = img.encodeJpg(image, quality: 70);
        
        if (moreCompressed.length > maxImageSizeBytes) {
          DebugUtils.logError('Image still too large');
          return null;
        }
        
        return await _saveImage(Uint8List.fromList(moreCompressed));
      }

      return await _saveImage(Uint8List.fromList(compressed));
    } catch (e) {
      DebugUtils.logError('Error processing image', error: e);
      return null;
    }
  }

  img.Image _resizeImage(img.Image image, int maxSize) {
    final width = image.width;
    final height = image.height;

    if (width > height) {
      
      final newWidth = maxSize;
      final newHeight = (height * maxSize / width).round();
      return img.copyResize(image, width: newWidth, height: newHeight);
    } else {
      
      final newHeight = maxSize;
      final newWidth = (width * maxSize / height).round();
      return img.copyResize(image, width: newWidth, height: newHeight);
    }
  }

  Future<String> _saveImage(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filepath = path.join(imagesDir.path, filename);
    
    final file = File(filepath);
    await file.writeAsBytes(bytes);

    DebugUtils.log('Image saved: $filepath', tag: 'IMAGE');
    return filepath;
  }

  File? getImageFile(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    final file = File(imagePath);
    return file.existsSync() ? file : null;
  }

  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        DebugUtils.log('Image deleted: $imagePath', tag: 'IMAGE');
        return true;
      }
      return false;
    } catch (e) {
      DebugUtils.logError('Error deleting image', error: e);
      return false;
    }
  }

  Future<void> cleanOldImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/images');
      
      if (!await imagesDir.exists()) return;

      final now = DateTime.now();
      final files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);
          
          if (age.inDays > 30) {
            await file.delete();
            DebugUtils.log('Deleted old image: ${file.path}', tag: 'IMAGE');
          }
        }
      }
    } catch (e) {
      DebugUtils.logError('Error cleaning old images', error: e);
    }
  }

  Future<int> getTotalImagesSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/images');
      
      if (!await imagesDir.exists()) return 0;

      int totalSize = 0;
      final files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}