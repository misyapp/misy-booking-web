#!/bin/bash
# Script de conversion PNG vers SVG pour Misy V2
# Utilise ImageMagick pour convertir les icônes

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Compteurs
CONVERTED=0
FAILED=0

echo "🚀 Début de la conversion des icônes PNG vers SVG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Créer un dossier pour les SVG si nécessaire
if [ ! -d "assets/icons/svg" ]; then
    mkdir -p assets/icons/svg
    echo "📁 Dossier assets/icons/svg créé"
fi

# Conversion des PNG
for file in assets/icons/*.png; do
  if [ -f "$file" ]; then
    filename=$(basename "$file" .png)
    
    # Ignorer certains fichiers qui ne sont pas vraiment des icônes
    if [[ "$filename" == "intro_image" || "$filename" == "splash_logo" ]]; then
        echo -e "${YELLOW}⏩ Ignoré: $filename.png (image, pas une icône)${NC}"
        continue
    fi
    
    # Convertir en SVG avec optimisation pour les icônes
    if convert "$file" -background none -density 300 -resize 512x512 "assets/icons/svg/${filename}.svg" 2>/dev/null; then
        echo -e "${GREEN}✅ Converti: $filename.png -> ${filename}.svg${NC}"
        ((CONVERTED++))
    else
        echo -e "${RED}❌ Échec: $filename.png${NC}"
        ((FAILED++))
    fi
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Résumé de la conversion:"
echo "   ✅ Réussis: $CONVERTED"
echo "   ❌ Échoués: $FAILED"
echo "   📁 SVG créés dans: assets/icons/svg/"
echo ""
echo "💡 Note: Les PNG originaux sont conservés pour compatibilité"
echo "   Les fichiers intro_image et splash_logo ont été ignorés"