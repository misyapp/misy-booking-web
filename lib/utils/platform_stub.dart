import 'dart:typed_data';

/// Stub pour Platform sur le web
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static String get localHostname => '';
  static String get localeName => '';
  static int get numberOfProcessors => 1;
  static String get pathSeparator => '/';
  static Map<String, String> get environment => {};
  static String get executable => '';
  static Uri get script => Uri();
  static List<String> get executableArguments => [];
  static String get packageRoot => '';
  static String get packageConfig => '';
  static String get version => '';
  static String get resolvedExecutable => '';
}

/// Stub Directory pour le web
class Directory {
  final String path;

  Directory(this.path);

  Directory get parent => Directory('');
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Future<Directory> delete({bool recursive = false}) async => this;
}

/// Stub pour File sur le web
class File {
  final String path;

  File(this.path);

  Directory get parent => Directory('');
  Future<bool> exists() async => false;
  Future<File> delete({bool recursive = false}) async => this;
  Future<File> create({bool recursive = false}) async => this;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<String> readAsString() async => '';
  Future<int> length() async => 0;
  Future<void> writeAsBytes(List<int> bytes) async {}
  void writeAsBytesSync(List<int> bytes) {}
  Future<void> writeAsString(String contents) async {}
  void writeAsStringSync(String contents) {}
  Future<File> copy(String newPath) async => File(newPath);
  Future<File> rename(String newPath) async => File(newPath);
  Stream<List<int>> openRead([int? start, int? end]) => Stream.empty();
}

/// Stub pour SocketException sur le web
class SocketException implements Exception {
  final String message;
  final String? osError;
  final String? address;
  final int? port;

  SocketException(this.message, {this.osError, this.address, this.port});

  @override
  String toString() => 'SocketException: $message';
}
