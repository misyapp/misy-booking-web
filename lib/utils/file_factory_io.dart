import 'dart:io' show File;
import 'dart:typed_data';

/// Mobile n'a pas besoin de cette factory : le file picker retourne déjà un
/// dart:io File avec un vrai path. Laissée en unsupported pour éviter tout
/// usage accidentel qui masquerait un bug.
File createFileFromBytes(String name, Uint8List bytes) {
  throw UnsupportedError(
      'createFileFromBytes is web-only — on mobile use the file picker path directly');
}
