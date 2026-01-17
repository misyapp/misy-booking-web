#!/bin/bash
#
# 🌐 Script d'installation LibreTranslate sur serveur OVH
# Pour: osrm2.misy.app
#
# Usage:
# 1. Copier ce script sur le serveur : scp scripts/install_libretranslate.sh ubuntu@osrm2.misy.app:~
# 2. Se connecter : ssh -i ~/.ssh/id_rsa_misy ubuntu@osrm2.misy.app
# 3. Exécuter : chmod +x install_libretranslate.sh && ./install_libretranslate.sh
#

set -e

echo "🚀 Installation de LibreTranslate sur osrm2.misy.app"
echo "=================================================="

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "📦 Installation de Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "✅ Docker installé"
else
    echo "✅ Docker déjà installé"
fi

# Vérifier si docker-compose est disponible
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📦 Installation de docker-compose..."
    sudo apt-get install -y docker-compose
fi

# Créer le répertoire pour LibreTranslate
echo "📁 Création du répertoire LibreTranslate..."
mkdir -p ~/libretranslate
cd ~/libretranslate

# Créer le fichier docker-compose
echo "📝 Création du fichier docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  libretranslate:
    image: libretranslate/libretranslate:latest
    container_name: libretranslate
    restart: unless-stopped
    ports:
      - "5050:5000"
    environment:
      # Langues à charger (économise la RAM)
      - LT_LOAD_ONLY=en,fr,it,pl,mg
      # Désactive la limite de caractères
      - LT_CHAR_LIMIT=5000
      # Désactive le rate limiting (optionnel, à activer en production)
      # - LT_REQ_LIMIT=0
      # Cache des modèles
      - LT_UPDATE_MODELS=true
    volumes:
      - lt-models:/home/libretranslate/.local/share/argos-translate
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/languages"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 2G

volumes:
  lt-models:
EOF

# Créer un service systemd pour démarrage automatique
echo "⚙️ Configuration du service systemd..."
sudo tee /etc/systemd/system/libretranslate.service > /dev/null << 'EOF'
[Unit]
Description=LibreTranslate Translation Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/libretranslate
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=ubuntu
Group=docker

[Install]
WantedBy=multi-user.target
EOF

# Activer et démarrer le service
echo "🔄 Activation du service..."
sudo systemctl daemon-reload
sudo systemctl enable libretranslate

# Démarrer LibreTranslate
echo "🚀 Démarrage de LibreTranslate..."
docker compose up -d

echo ""
echo "⏳ Attente du téléchargement des modèles de langue (peut prendre 2-5 min)..."
echo "   Vous pouvez suivre les logs avec: docker logs -f libretranslate"
echo ""

# Attendre que le service soit prêt
attempt=0
max_attempts=60
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:5050/languages > /dev/null 2>&1; then
        echo ""
        echo "✅ LibreTranslate est prêt!"
        break
    fi
    echo -n "."
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo ""
    echo "⚠️ Le service met du temps à démarrer. Vérifiez les logs:"
    echo "   docker logs -f libretranslate"
fi

echo ""
echo "=================================================="
echo "🎉 Installation terminée!"
echo ""
echo "📍 URL du service: http://osrm2.misy.app:5050"
echo ""
echo "📋 Commandes utiles:"
echo "   - Voir les logs: docker logs -f libretranslate"
echo "   - Redémarrer: sudo systemctl restart libretranslate"
echo "   - Statut: sudo systemctl status libretranslate"
echo "   - Tester: curl http://localhost:5050/languages"
echo ""
echo "🔒 N'oubliez pas d'ouvrir le port 5050 dans le firewall OVH!"
echo "   Ou mieux: configurez un reverse proxy nginx avec SSL"
echo "=================================================="
