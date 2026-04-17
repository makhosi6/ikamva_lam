import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Opens the on-disk learner database (mobile + desktop). Tests should use
/// [openMemoryDatabase] instead.
LazyDatabase openIkamvaDatabaseFile() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ikamva.db'));
    if (kDebugMode) {
      debugPrint('IkamvaDatabase path: ${file.path}');
    }
    return NativeDatabase.createInBackground(file);
  });
}

IkamvaDatabase openMemoryDatabase() {
  return IkamvaDatabase(NativeDatabase.memory());
}
