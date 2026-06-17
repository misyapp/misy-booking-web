// Publie l'état de connexion rider dans un cookie du domaine parent
// `.misy.app`, pour que le site vitrine misy.app (origine différente, dont
// la session Firebase de book.misy.app est invisible) puisse afficher un
// menu compte au lieu de « Connexion / S'inscrire ».
//
// Web uniquement — no-op sur mobile (l'import `dart:html` est isolé dans la
// variante web via l'export conditionnel ci-dessous).
export 'misy_session_bridge_stub.dart'
    if (dart.library.html) 'misy_session_bridge_web.dart';
