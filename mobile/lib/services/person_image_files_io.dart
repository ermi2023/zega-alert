import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String?> savePersonImage(String url, Uint8List bytes) async {
  final supportDirectory = await getApplicationSupportDirectory();
  final cacheDirectory = Directory(
    path.join(supportDirectory.path, 'person_photo_cache'),
  );
  await cacheDirectory.create(recursive: true);
  final fileName = '${sha256.convert(utf8.encode(url))}.image';
  final file = File(path.join(cacheDirectory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<ImageProvider<Object>?> imageProviderForPath(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;
  return FileImage(file);
}

Future<void> deletePersonImageFile(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) await file.delete();
}

Future<int> personImageFileLength(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return 0;
  return file.length();
}
