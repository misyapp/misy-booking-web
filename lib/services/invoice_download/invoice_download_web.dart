import 'dart:html' as html;
import 'dart:typed_data';

/// Déclenche le téléchargement navigateur d'un PDF généré en mémoire
/// (Blob → lien `download` éphémère → clic programmatique).
Future<void> downloadPdfBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
