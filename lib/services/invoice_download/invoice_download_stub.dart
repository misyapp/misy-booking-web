import 'dart:typed_data';

/// Stub non-web : jamais appelé en pratique (le bouton facture de l'espace
/// compte n'existe que sur la déclinaison web).
Future<void> downloadPdfBytes(Uint8List bytes, String filename) async {
  throw UnsupportedError(
      'downloadPdfBytes n\'est disponible que sur la version web');
}
