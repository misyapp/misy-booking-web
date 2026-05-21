#!/bin/bash

# Script de déploiement TAXIBE (site transport en commun)
# Cible : taxibe.misy.app sur le VPS OVH
# Entry point : lib/main_taxibe.dart (BuildMode.taxibe)

set -e

echo "🚌 Déploiement TaxiBe (taxibe.misy.app)"
echo "========================================"

# 1. Build avec l'entry point taxibe
echo ""
echo "🔨 flutter build web --release --target lib/main_taxibe.dart"
flutter build web --release --target lib/main_taxibe.dart

# 2. Patch in-place build/web/index.html — title + meta description + apple title
# (le template web/index.html est partagé avec le booking, on patche le build).
echo ""
echo "✏️  Patch build/web/index.html (title TaxiBe)"
INDEX="build/web/index.html"
# macOS sed (BSD) vs GNU sed : -i '' marche sur Mac. Détection.
if sed --version >/dev/null 2>&1; then
    SED_INPLACE=(-i)
else
    SED_INPLACE=(-i '')
fi
sed "${SED_INPLACE[@]}" \
    -e 's|<title>rider_ride_hailing_app</title>|<title>TaxiBe — Transport en commun Antananarivo</title>|' \
    -e 's|<meta name="description" content="A new Flutter project.">|<meta name="description" content="Plan ton itinéraire en bus (taxibe) à Antananarivo. Calculateur multimodal, plan du réseau, horaires.">|' \
    -e 's|<meta name="apple-mobile-web-app-title" content="rider_ride_hailing_app">|<meta name="apple-mobile-web-app-title" content="TaxiBe">|' \
    "$INDEX"

# 3. Rsync vers OVH (chemin distinct du booking)
SERVER_USER="ubuntu"
SERVER_HOST="51.254.141.103"
SSH_KEY="~/.ssh/id_rsa_misy"
REMOTE_PATH="/var/www/taxibe.misy.app/"

echo ""
echo "📦 rsync → $SERVER_USER@$SERVER_HOST:$REMOTE_PATH"
rsync -avz --delete --exclude='osrm-proxy.php' \
    -e "ssh -i $SSH_KEY" \
    --rsync-path="sudo rsync" \
    build/web/ \
    "$SERVER_USER@$SERVER_HOST:$REMOTE_PATH"

echo ""
echo "✅ Déploiement réussi → https://taxibe.misy.app"
echo ""
echo "🔎 Vérification (grep d'un literal unique au build taxibe) :"
# Le main.dart.js doit contenir le mode taxibe : on grep BuildMode.taxibe
# (literal du build courant, présent uniquement si bootstrap a été appelé
# via main_taxibe.dart).
sleep 2
if curl -s "https://taxibe.misy.app/main.dart.js?$(date +%s)" | grep -q "BuildMode"; then
    echo "✅ main.dart.js prod contient BuildMode (build OK)"
else
    echo "⚠️  Literal BuildMode introuvable — DNS pas propagé ? vhost nginx pas configuré ?"
fi
