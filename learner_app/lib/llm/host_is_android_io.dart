import 'dart:io' show Platform;

/// True on Android VM hosts. Used so context caps match LiteRT without relying
/// solely on [defaultTargetPlatform] (e.g. unusual embedder / test states).
bool get hostIsAndroid => Platform.isAndroid;
