/// Téléchargement de PDF côté navigateur (factures de courses).
///
/// Pattern d'export conditionnel identique à `lib/utils/platform.dart` :
/// l'implémentation `dart:html` n'est tirée que sur web, le stub ailleurs.
/// ⚠️ Ne PAS passer par `File`/`getApplicationDocumentsDirectory` ici — c'est
/// précisément ce qui fait échouer silencieusement la génération de factures
/// du chemin background (`_generateAndUploadInvoicesInBackground`) sur web.
export 'invoice_download_stub.dart'
    if (dart.library.html) 'invoice_download_web.dart';
