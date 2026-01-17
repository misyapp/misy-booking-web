#!/bin/bash

# 🚀 Script de déploiement de la Cloud Function de nettoyage
# Usage: ./deploy-cleanup.sh

echo "🧹 Déploiement de la fonction de nettoyage des courses expirées"
echo ""

# Vérifier qu'on est dans le bon dossier
if [ ! -f "index.js" ]; then
    echo "❌ Erreur: Veuillez exécuter ce script depuis le dossier functions/"
    exit 1
fi

# Vérifier que Firebase CLI est installé
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI n'est pas installé"
    echo "   Installer avec: npm install -g firebase-tools"
    exit 1
fi

# Vérifier les dépendances
echo "📦 Vérification des dépendances..."
if [ ! -d "node_modules" ]; then
    echo "   Installation des dépendances..."
    npm install
fi

# Déployer la fonction
echo ""
echo "🚀 Déploiement de cleanupExpiredScheduledBookings..."
firebase deploy --only functions:cleanupExpiredScheduledBookings

# Vérifier le résultat
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Déploiement réussi!"
    echo ""
    echo "📋 Prochaines étapes:"
    echo "   1. Vérifier les logs: firebase functions:log --only cleanupExpiredScheduledBookings"
    echo "   2. Tester manuellement dans Firebase Console"
    echo "   3. La fonction s'exécutera automatiquement toutes les heures"
    echo ""
    echo "📊 Monitoring:"
    echo "   - Console: https://console.firebase.google.com/project/misy-95336/functions"
    echo "   - Logs temps réel: firebase functions:log --only cleanupExpiredScheduledBookings --follow"
else
    echo ""
    echo "❌ Échec du déploiement"
    echo "   Vérifier les erreurs ci-dessus"
    exit 1
fi
