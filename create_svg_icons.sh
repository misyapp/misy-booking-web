#!/bin/bash
# Script alternatif pour créer des SVG simples pour les icônes principales
# Approche LEAN : créer des SVG basiques pour les 5 icônes principales

# Créer le dossier SVG si nécessaire
mkdir -p assets/icons/svg

echo "🎨 Création manuelle des SVG pour les icônes principales"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Icône Home
cat > assets/icons/svg/home.svg << 'EOF'
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <polyline points="9 22 9 12 15 12 15 22" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
echo "✅ Créé: home.svg"

# 2. Icône Menu
cat > assets/icons/svg/menu.svg << 'EOF'
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <line x1="3" y1="12" x2="21" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <line x1="3" y1="18" x2="21" y2="18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
EOF
echo "✅ Créé: menu.svg"

# 3. Icône User
cat > assets/icons/svg/user.svg << 'EOF'
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="12" cy="7" r="4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
echo "✅ Créé: user.svg"

# 4. Icône Location
cat > assets/icons/svg/location.svg << 'EOF'
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="12" cy="10" r="3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
echo "✅ Créé: location.svg"

# 5. Icône Car
cat > assets/icons/svg/car_home_icon.svg << 'EOF'
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 3H8l-3 4v11a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h8v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1V7l-3-4z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="7.5" cy="11.5" r="1.5" fill="currentColor"/>
  <circle cx="16.5" cy="11.5" r="1.5" fill="currentColor"/>
</svg>
EOF
echo "✅ Créé: car_home_icon.svg"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 5 icônes principales créées en SVG"
echo "💡 Ces SVG utilisent 'currentColor' pour s'adapter aux couleurs du thème"
echo "📁 Fichiers créés dans: assets/icons/svg/"