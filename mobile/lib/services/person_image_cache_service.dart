import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'person_image_files_stub.dart'
    if (dart.library.io) 'person_image_files_io.dart'
    as files;

class PersonImageCacheService {
  static const _preferenceKey = 'cache_person_photos_offline';
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static final ValueNotifier<int> cacheRevision = ValueNotifier(0);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    enabled.value = !kIsWeb && (preferences.getBool(_preferenceKey) ?? false);
  }

  static Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, value);
    enabled.value = !kIsWeb && value;
    if (!value) await clear();
  }

  static Future<ImageProvider<Object>?> cachedImage(String url) async {
    if (kIsWeb || !enabled.value) return null;
    final path = await DatabaseService.getCachedPersonImagePath(url);
    if (path == null) return null;
    final provider = await files.imageProviderForPath(path);
    if (provider == null) {
      await DatabaseService.removeCachedPersonImage(url);
      cacheRevision.value++;
    }
    return provider;
  }

  static Future<ImageProvider<Object>?> storeImage(
    String url,
    Uint8List bytes,
  ) async {
    if (kIsWeb || !enabled.value) return null;
    final path = await files.savePersonImage(url, bytes);
    if (path == null) return null;
    try {
      await DatabaseService.cachePersonImagePath(url, path);
    } catch (_) {
      await files.deletePersonImageFile(path);
      rethrow;
    }
    cacheRevision.value++;
    return files.imageProviderForPath(path);
  }

  static Future<int> cachedBytes() async {
    if (kIsWeb) return 0;
    final cachedImages = await DatabaseService.getCachedPersonImages();
    var total = 0;
    for (final image in cachedImages) {
      final path = image['local_path'] as String?;
      if (path != null) total += await files.personImageFileLength(path);
    }
    return total;
  }

  static Future<int> cachedCount() async {
    if (kIsWeb) return 0;
    return (await DatabaseService.getCachedPersonImages()).length;
  }

  static Future<void> clear() async {
    if (!kIsWeb) {
      final cachedImages = await DatabaseService.getCachedPersonImages();
      for (final image in cachedImages) {
        final path = image['local_path'] as String?;
        if (path != null) await files.deletePersonImageFile(path);
      }
      await DatabaseService.clearCachedPersonImages();
    }
    cacheRevision.value++;
  }
}
