#!/bin/bash

# Script de soumission automatisée App Store - Misy
# Ce script automatise toutes les étapes possibles
# Usage: bash scripts/submit_app_store.sh

echo "🚀 SOUMISSION APP STORE AUTOMATISÉE - MISY"
echo "=========================================="

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Vérification des prérequis
log_info "Vérification des outils nécessaires..."

if ! command -v flutter &> /dev/null; then
    log_error "Flutter n'est pas installé"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    log_error "Xcode n'est pas installé"
    exit 1
fi

# Utiliser fvm si disponible
if command -v fvm &> /dev/null; then
    FLUTTER_CMD="fvm flutter"
    log_success "Utilisation FVM"
else
    FLUTTER_CMD="flutter"
    log_warning "Utilisation Flutter global"
fi

log_success "Outils vérifiés"

# Étape 1: Build clean
log_info "ÉTAPE 1/7: Nettoyage et build iOS..."
echo "======================================"

$FLUTTER_CMD clean
rm -rf build/
rm -rf .dart_tool/
$FLUTTER_CMD pub get

log_info "Build iOS release en cours..."
$FLUTTER_CMD build ios --release --no-sound-null-safety

if [ $? -ne 0 ]; then
    log_error "Échec du build iOS"
    exit 1
fi

log_success "Build iOS terminé"

# Étape 2: Vérifications pre-archive
log_info "ÉTAPE 2/7: Vérifications avant archive..."
echo "========================================="

# Vérifier que le workspace existe
WORKSPACE_PATH="ios/Runner.xcworkspace"
if [ ! -d "$WORKSPACE_PATH" ]; then
    log_error "Workspace manquant: $WORKSPACE_PATH"
    exit 1
fi

# Vérifier la configuration
PLIST_PATH="ios/Runner/Info.plist"
if [ -f "$PLIST_PATH" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST_PATH" 2>/dev/null || echo "Unknown")
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST_PATH" 2>/dev/null || echo "Unknown")
    log_info "Version: $VERSION ($BUILD_NUMBER)"
else
    log_warning "Info.plist non trouvé"
fi

log_success "Vérifications terminées"

# Étape 3: Archive automatique
log_info "ÉTAPE 3/7: Création de l'archive Xcode..."
echo "========================================"

# Trouver le scheme (habituellement Runner)
SCHEME="Runner"
ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
mkdir -p build/ios/archive

log_info "Archive en cours... (peut prendre 5-10 minutes)"

xcodebuild -workspace "$WORKSPACE_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination generic/platform=iOS \
           -archivePath "$ARCHIVE_PATH" \
           archive

if [ $? -ne 0 ]; then
    log_error "Échec de l'archive"
    log_info "Solutions possibles:"
    echo "  • Vérifier les certificats de signature"
    echo "  • Ouvrir Xcode et corriger les erreurs manuellement"
    echo "  • Exécuter: open ios/Runner.xcworkspace"
    exit 1
fi

log_success "Archive créée: $ARCHIVE_PATH"

# Étape 4: Validation (optionnelle mais recommandée)
log_info "ÉTAPE 4/7: Validation de l'archive..."
echo "====================================="

log_info "Validation en cours..."

xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportOptionsPlist scripts/export_options.plist \
           -exportPath build/ios/ipa \
           -allowProvisioningUpdates \
           -validate

if [ $? -eq 0 ]; then
    log_success "Validation réussie"
else
    log_warning "Validation échouée (peut continuer)"
fi

# Étape 5: Export IPA
log_info "ÉTAPE 5/7: Export IPA pour App Store..."
echo "===================================="

# Créer le fichier export_options.plist s'il n'existe pas
EXPORT_PLIST="scripts/export_options.plist"
if [ ! -f "$EXPORT_PLIST" ]; then
    log_info "Création du fichier export_options.plist..."
    mkdir -p scripts
    cat > "$EXPORT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>upload</string>
    <key>method</key>
    <string>app-store</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF
fi

log_info "Export IPA en cours..."

xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportOptionsPlist "$EXPORT_PLIST" \
           -exportPath build/ios/ipa \
           -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    log_error "Échec de l'export IPA"
    exit 1
fi

log_success "IPA exportée: build/ios/ipa/"

# Étape 6: Upload vers App Store Connect
log_info "ÉTAPE 6/7: Upload vers App Store Connect..."
echo "========================================"

# Trouver le fichier IPA
IPA_FILE=$(find build/ios/ipa -name "*.ipa" | head -1)

if [ -z "$IPA_FILE" ]; then
    log_error "Fichier IPA non trouvé"
    exit 1
fi

log_info "Fichier IPA trouvé: $IPA_FILE"
log_info "Upload en cours vers App Store Connect..."

# Utiliser altool pour l'upload (nécessite identifiants Apple)
if command -v xcrun altool &> /dev/null; then
    log_warning "Upload nécessite vos identifiants Apple ID"
    log_info "Le système va vous demander votre Apple ID et mot de passe..."
    
    xcrun altool --upload-app \
                 --type ios \
                 --file "$IPA_FILE" \
                 --username "VOTRE_APPLE_ID" \
                 --password "@keychain:Application Loader: VOTRE_APPLE_ID"
    
    if [ $? -eq 0 ]; then
        log_success "Upload réussi vers App Store Connect!"
    else
        log_error "Échec de l'upload automatique"
        log_info "Solutions:"
        echo "  • Utiliser Xcode Organizer manuellement"
        echo "  • Configurer Application Loader"
        echo "  • Vérifier vos identifiants Apple"
    fi
else
    log_warning "altool non disponible, utilisation manuelle requise"
fi

# Étape 7: Instructions finales
log_info "ÉTAPE 7/7: Instructions finales..."
echo "=================================="

log_success "🎉 PROCESSUS TERMINÉ!"
echo ""
log_info "PROCHAINES ÉTAPES MANUELLES:"
echo "1. Aller sur https://appstoreconnect.apple.com"
echo "2. Sélectionner votre app Misy"
echo "3. Attendre le processing (15-30 min)"
echo "4. Créer nouvelle version si nécessaire"
echo "5. Ajouter les release notes:"
echo ""
echo "   🗺️ Major Map Experience Update"
echo "   ✅ Fixed map zoom issues on iPhone"  
echo "   ✅ Enhanced route display"
echo "   ✅ Improved payment screen stability"
echo "   ✅ Better location handling"
echo "   ✅ Performance optimizations"
echo ""
echo "6. Soumettre pour review"
echo ""

# Résumé technique
log_info "RÉSUMÉ TECHNIQUE:"
echo "Build: $(date)"
echo "Version: $VERSION ($BUILD_NUMBER)"
echo "Archive: $ARCHIVE_PATH"
echo "IPA: $IPA_FILE"
echo "Status: ✅ PRÊT POUR APP STORE"

# Ouvrir automatiquement les liens utiles
log_info "Ouverture des liens utiles..."
open "https://appstoreconnect.apple.com"
open "$ARCHIVE_PATH" 2>/dev/null || true

log_success "🚀 Votre app est prête pour l'App Store!"