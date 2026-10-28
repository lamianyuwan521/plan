import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<String?> saveTextFile({
  required String fileName,
  required String extension,
  required String content,
  required String mimeType,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final type = extension == 'json' ? MimeType.json : MimeType.csv;

  if (Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isWindows) {
    return FileSaver.instance.saveAs(
      name: fileName,
      bytes: bytes,
      fileExtension: extension,
      mimeType: type,
    );
  }

  return FileSaver.instance.saveFile(
    name: fileName,
    bytes: bytes,
    fileExtension: extension,
    mimeType: type,
  );
}
