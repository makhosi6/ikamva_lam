import 'dart:io' as io;

bool hfLocalFileExistsSync(String path) => io.File(path).existsSync();

Future<int> hfLocalFileLength(String path) => io.File(path).length();
