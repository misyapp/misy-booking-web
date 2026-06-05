#!/bin/bash

# Script de déploiement MISY Booking Web
# Déploie l'application web sur le VPS OVH (book.misy.app)

set -e  # Arrêter en cas d'erreur

echo "🚀 Déploiement MISY Booking Web (OVH)"
echo "======================================"

# Vérifier que le build existe
if [ ! -d "build/web" ]; then
    echo "❌ Erreur: Le répertoire build/web n'existe pas"
    echo "Veuillez d'abord exécuter (RASTER_TILE_URL obligatoire, cf. DEPLOYMENT_WEB.md):"
    echo "  flutter build web --release --dart-define=RASTER_TILE_URL='https://tiles.misy.app/styles/misy/{z}/{x}/{y}.png'"
    exit 1
fi

# Configuration du serveur (OVH VPS)
SERVER_USER="ubuntu"
SERVER_HOST="51.254.141.103"
SSH_KEY="~/.ssh/id_rsa_misy"
REMOTE_PATH="/var/www/book.misy.app/"

# ─── Garde anti-collision (05/06/2026, après 2 deploys croisés le même jour) ──
# 1. Fraîcheur : si origin/main a des commits absents d'ici, ce build va
#    ÉCRASER du code déjà en prod (vécu : espace compte ↔ LOOM, 2×).
git fetch origin main --quiet 2>/dev/null || true
BEHIND=$(git log --oneline HEAD..origin/main 2>/dev/null | wc -l | tr -d ' ')
if [ "$BEHIND" != "0" ]; then
    echo "❌ STOP: cette branche est en retard de $BEHIND commit(s) sur origin/main."
    echo "   Déployer écraserait du code déjà en prod. Merger d'abord :"
    git log --oneline HEAD..origin/main | head -5 | sed 's/^/     /'
    if [ "${DEPLOY_FORCE:-0}" != "1" ]; then
        echo "   (forcer en connaissance de cause : DEPLOY_FORCE=1 ./deploy.sh)"
        exit 1
    fi
    echo "⚠️  DEPLOY_FORCE=1 — on continue malgré le retard."
fi

# 2. Verrou serveur : un seul deploy à la fois. mkdir = atomique ;
#    lock périmé (>10 min, deploy planté) repris automatiquement.
LOCK_CMD='if sudo mkdir /var/www/.deploy-book.lock 2>/dev/null; then echo LOCK_OK; else AGE=$(( $(date +%s) - $(sudo stat -c %Y /var/www/.deploy-book.lock 2>/dev/null || echo 0) )); if [ "$AGE" -gt 600 ]; then sudo rm -rf /var/www/.deploy-book.lock && sudo mkdir /var/www/.deploy-book.lock && echo LOCK_STALE_TAKEN; else echo LOCK_BUSY; fi; fi'
LOCK_RESULT=$(ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST "$LOCK_CMD")
if [ "$LOCK_RESULT" = "LOCK_BUSY" ]; then
    echo "❌ STOP: un autre deploy est en cours (lock serveur présent)."
    echo "   Réessaie dans une minute, ou si tu es certain qu'aucun deploy ne tourne :"
    echo "   ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST 'sudo rm -rf /var/www/.deploy-book.lock'"
    exit 1
fi
# Libération du lock quoi qu'il arrive (succès, erreur, Ctrl-C).
trap "ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST 'sudo rm -rf /var/www/.deploy-book.lock' 2>/dev/null" EXIT

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
