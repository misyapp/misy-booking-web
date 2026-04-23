#!/bin/bash

# Script de déploiement MISY Booking Web
# Déploie l'application web sur le VPS OVH (book.misy.app)

set -e  # Arrêter en cas d'erreur

echo "🚀 Déploiement MISY Booking Web (OVH)"
echo "======================================"

# Vérifier que le build existe
if [ ! -d "build/web" ]; then
    echo "❌ Erreur: Le répertoire build/web n'existe pas"
    echo "Veuillez d'abord exécuter: flutter build web --release"
    exit 1
fi

# Configuration du serveur (OVH VPS)
SERVER_USER="ubuntu"
SERVER_HOST="51.254.141.103"
SSH_KEY="~/.ssh/id_rsa_misy"
REMOTE_PATH="/var/www/book.misy.app/"

echo ""
echo "📦 Upload des fichiers vers le serveur..."
echo "Serveur: $SERVER_USER@$SERVER_HOST"
echo "Destination: $REMOTE_PATH"
echo ""

# Déploiement via rsync
# --rsync-path="sudo rsync" : DocumentRoot owner = www-data, donc sudo côté serveur.
# --exclude='osrm-proxy.php' : ce fichier est serveur-only (proxy OSRM).
rsync -avz --delete --exclude='osrm-proxy.php' \
    -e "ssh -i $SSH_KEY" \
    --rsync-path="sudo rsync" \
    build/web/ \
    $SERVER_USER@$SERVER_HOST:$REMOTE_PATH

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Déploiement réussi!"
    echo "🌐 Application disponible sur: https://book.misy.app"
    echo ""
    echo "🔎 Vérification (Last-Modified doit être d'aujourd'hui):"
    curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified || true
else
    echo ""
    echo "❌ Erreur lors du déploiement"
    exit 1
fi
