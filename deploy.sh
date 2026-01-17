#!/bin/bash

# Script de déploiement MISY Booking Web
# Déploie l'application web sur le serveur Bluehost

set -e  # Arrêter en cas d'erreur

echo "🚀 Déploiement MISY Booking Web"
echo "================================"

# Vérifier que le build existe
if [ ! -d "build/web" ]; then
    echo "❌ Erreur: Le répertoire build/web n'existe pas"
    echo "Veuillez d'abord exécuter: flutter build web --release"
    exit 1
fi

# Configuration du serveur
SERVER_USER="root"
SERVER_HOST="162.240.145.160"
SSH_KEY="~/.ssh/id_rsa_misy"
REMOTE_PATH="/home/misyapp/booking_web/"

echo ""
echo "📦 Upload des fichiers vers le serveur..."
echo "Serveur: $SERVER_USER@$SERVER_HOST"
echo "Destination: $REMOTE_PATH"
echo ""

# Déploiement via rsync
rsync -avz --delete \
    -e "ssh -i $SSH_KEY" \
    build/web/ \
    $SERVER_USER@$SERVER_HOST:$REMOTE_PATH

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Déploiement réussi!"
    echo "🌐 Application disponible sur: https://book.misy.app"
else
    echo ""
    echo "❌ Erreur lors du déploiement"
    exit 1
fi
