import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _files = MethodChannel('multimeter_viewer/files');

const _csvTypes = [
  XTypeGroup(label: 'CSV', extensions: ['csv'], mimeTypes: ['text/csv']),
];

/// A text file the user picked.
typedef PickedTextFile = ({String name, String content});

/// Lets the user save [content] as a CSV file. Returns `false` if the user
/// cancelled the save dialog.
///
/// Desktop: native "Save as" dialog. Android: system document picker.
/// Web: browser download.
Future<bool> saveCsvFile(String fileName, String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final file = XFile.fromData(bytes, name: fileName, mimeType: 'text/csv');

  if (kIsWeb) {
    await file.saveTo(fileName);
    return true;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // file_selector cannot save on Android; use the system "save as" dialog.
    return await _files.invokeMethod<bool>('saveDocument', {
          'name': fileName,
          'mimeType': 'text/csv',
          'bytes': bytes,
        }) ??
        false;
  }

  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: _csvTypes,
  );
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}

/// Lets the user pick a CSV file. Returns `null` if cancelled.
Future<PickedTextFile?> pickCsvFile() async {
  final file = await openFile(acceptedTypeGroups: _csvTypes);
  if (file == null) return null;
  return (name: file.name, content: utf8.decode(await file.readAsBytes()));
}
