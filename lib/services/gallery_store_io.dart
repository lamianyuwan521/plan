import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

final Map<String, Uint8List> _memory = <String, Uint8List>{};

Future<Directory?> _directory() async {
  try {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}${Platform.pathSeparator}gallery');
  } catch (_) {
    return null;
  }
}

Future<File?> _file(String id) async {
  final dir = await _directory();
  if (dir == null) return null;
  return File('${dir.path}${Platform.pathSeparator}$id.img');
}

Uint8List? peekGalleryBytes(String id) => _memory[id];

Future<bool> saveGalleryBytes(String id, Uint8List bytes) async {
  final copy = Uint8List.fromList(bytes);
  try {
    final file = await _file(id);
    if (file == null) {
      _memory[id] = copy;
      return true;
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(copy, flush: true);
    _memory[id] = copy;
    return true;
  } catch (_) {
    return false;
  }
}

Future<Uint8List?> loadGalleryBytes(String id) async {
  final cached = _memory[id];
  if (cached != null) return cached;
  try {
    final file = await _file(id);
    if (file == null || !await file.exists()) return null;
    final bytes = await file.readAsBytes();
    _memory[id] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> deleteGalleryBytes(String id) async {
  _memory.remove(id);
  try {
    final file = await _file(id);
    if (file != null && await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

Future<void> clearGalleryBytes() async {
  _memory.clear();
  try {
    final dir = await _directory();
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
