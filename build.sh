#!/bin/bash

# Speew v2.0 - Build Automation Script
# This script automates the entire build process

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     Speew v2.0 - Build Script        ║"
echo "║   Automated Build & Optimization     ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}═══ $1 ═══${NC}"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter não está instalado ou não está no PATH"
    exit 1
fi

print_status "Flutter encontrado: $(flutter --version | head -n 1)"

# Step 1: Validate project structure
print_step "1. Validando estrutura do projeto"

if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml não encontrado!"
    exit 1
fi
print_status "pubspec.yaml encontrado"

if [ ! -d "lib" ]; then
    print_error "Diretório lib/ não encontrado!"
    exit 1
fi
print_status "Diretório lib/ encontrado"

if [ ! -d "android" ]; then
    print_error "Diretório android/ não encontrado!"
    exit 1
fi
print_status "Diretório android/ encontrado"

# Step 2: Clean previous builds
print_step "2. Limpando builds anteriores"

flutter clean
print_status "Build anterior limpo"

# Step 3: Get dependencies
print_step "3. Baixando dependências"

flutter pub get
print_status "Dependências baixadas"

# Step 4: Run validation script
print_step "4. Executando validações"

if [ -f "validate_project.sh" ]; then
    chmod +x validate_project.sh
    ./validate_project.sh
else
    print_warning "Script de validação não encontrado (opcional)"
fi

# Step 5: Analyze code
print_step "5. Analisando código"

flutter analyze --no-fatal-infos
print_status "Análise de código concluída"

# Step 6: Generate launcher icons (if configured)
print_step "6. Gerando ícones (se configurado)"

if grep -q "flutter_launcher_icons" pubspec.yaml; then
    flutter pub run flutter_launcher_icons:main || print_warning "Falha ao gerar ícones (não crítico)"
    print_status "Ícones gerados"
else
    print_warning "flutter_launcher_icons não configurado"
fi

# Step 7: Build options
print_step "7. Opções de Build"

echo ""
echo "Escolha o tipo de build:"
echo "  1) Debug APK (desenvolvimento)"
echo "  2) Release APK (produção)"
echo "  3) App Bundle (Google Play)"
echo "  4) Todos os tipos"
echo "  5) Apenas validar (sem build)"
echo ""
read -p "Opção [1-5]: " BUILD_OPTION

case $BUILD_OPTION in
    1)
        print_step "Buildando Debug APK"
        flutter build apk --debug
        print_status "Debug APK criado em: build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    2)
        print_step "Buildando Release APK"
        flutter build apk --release
        print_status "Release APK criado em: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    3)
        print_step "Buildando App Bundle"
        flutter build appbundle --release
        print_status "App Bundle criado em: build/app/outputs/bundle/release/app-release.aab"
        ;;
    4)
        print_step "Buildando todos os tipos"
        
        flutter build apk --debug
        print_status "Debug APK criado"
        
        flutter build apk --release
        print_status "Release APK criado"
        
        flutter build appbundle --release
        print_status "App Bundle criado"
        ;;
    5)
        print_status "Validação concluída sem build"
        ;;
    *)
        print_error "Opção inválida"
        exit 1
        ;;
esac

# Step 8: Summary
print_step "RESUMO DO BUILD"

echo ""
echo "Projeto: Speew v2.0"
echo "Arquivos Dart: $(find lib -name "*.dart" | wc -l)"
echo "Linhas de código: $(find lib -name "*.dart" -exec wc -l {} + | tail -1 | awk '{print $1}')"
echo ""

if [ $BUILD_OPTION != "5" ]; then
    echo "Builds criados:"
    if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
        SIZE=$(du -h build/app/outputs/flutter-apk/app-debug.apk | cut -f1)
        echo "  • Debug APK: $SIZE"
    fi
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
        echo "  • Release APK: $SIZE"
    fi
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        SIZE=$(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)
        echo "  • App Bundle: $SIZE"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         BUILD CONCLUÍDO! ✅           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Optional: Install on connected device
if [ $BUILD_OPTION != "5" ]; then
    echo ""
    read -p "Instalar em dispositivo conectado? (s/n): " INSTALL
    if [ "$INSTALL" = "s" ] || [ "$INSTALL" = "S" ]; then
        print_step "Instalando no dispositivo"
        flutter install
        print_status "Instalado com sucesso!"
    fi
fi

echo ""
print_status "Script finalizado!"
exit 0
