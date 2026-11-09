import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const String _dbName = 'xiaoyier-gallery';
const String _storeName = 'photos';

final Map<String, Uint8List> _memory = <String, Uint8List>{};
web.IDBDatabase? _database;
Future<web.IDBDatabase>? _opening;

Uint8List? peekGalleryBytes(String id) => _memory[id];

Future<bool> saveGalleryBytes(String id, Uint8List bytes) async {
  final copy = Uint8List.fromList(bytes);
  try {
    final db = await _openDatabase();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    final done = _complete(tx);
    tx.objectStore(_storeName).put(copy.toJS, id.toJS);
    await done;
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
    final db = await _openDatabase();
    final tx = db.transaction(_storeName.toJS, 'readonly');
    final request = tx.objectStore(_storeName).get(id.toJS);
    final result = await _result(request);
    final bytes = _asBytes(result);
    if (bytes != null) _memory[id] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> deleteGalleryBytes(String id) async {
  _memory.remove(id);
  try {
    final db = await _openDatabase();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    final done = _complete(tx);
    tx.objectStore(_storeName).delete(id.toJS);
    await done;
  } catch (_) {}
}

Future<void> clearGalleryBytes() async {
  _memory.clear();
  try {
    final db = await _openDatabase();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    final done = _complete(tx);
    tx.objectStore(_storeName).clear();
    await done;
  } catch (_) {}
}

Future<web.IDBDatabase> _openDatabase() {
  final existing = _database;
  if (existing != null) return Future<web.IDBDatabase>.value(existing);
  final pending = _opening;
  if (pending != null) return pending;
  final opening = _open();
  _opening = opening;
  opening.then<void>(
    (db) => _database = db,
    onError: (Object _) {
      if (identical(_opening, opening)) _opening = null;
    },
  );
  return opening;
}

Future<web.IDBDatabase> _open() {
  final completer = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(_dbName, 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_storeName)) {
      db.createObjectStore(_storeName);
    }
  }).toJS;
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(request.result as web.IDBDatabase);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('打不开图集存储'));
    }
  }).toJS;
  return completer.future;
}

Future<void> _complete(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  transaction.oncomplete = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  transaction.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('图集存储写入失败'));
    }
  }).toJS;
  transaction.onabort = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('图集存储已中断'));
    }
  }).toJS;
  return completer.future;
}

Future<JSAny?> _result(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('图集存储读取失败'));
    }
  }).toJS;
  return completer.future;
}

Uint8List? _asBytes(JSAny? value) {
  if (value == null) return null;
  if (value.isA<JSUint8Array>()) {
    return Uint8List.fromList((value as JSUint8Array).toDart);
  }
  if (value.isA<JSArrayBuffer>()) {
    final buffer = (value as JSArrayBuffer).toDart;
    return Uint8List.fromList(buffer.asUint8List());
  }
  return null;
}
