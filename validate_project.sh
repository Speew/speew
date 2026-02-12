#!/bin/bash

echo "==================================="
echo "  SPEEW v2.0 - Validação Completa"
echo "==================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores
ERRORS=0
WARNINGS=0
OK=0

echo "📁 Verificando estrutura de diretórios..."
REQUIRED_DIRS=(
    "lib/core"
    "lib/models"
    "lib/providers"
    "lib/services"
    "lib/ui/screens"
    "lib/ui/widgets"
    "android"
    "assets"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir"
        ((OK++))
    else
        echo -e "${RED}✗${NC} $dir - FALTANDO"
        ((ERRORS++))
    fi
done

echo ""
echo "📄 Verificando arquivos essenciais..."
REQUIRED_FILES=(
    "lib/main.dart"
    "pubspec.yaml"
    "android/app/build.gradle"
    "lib/core/app_config.dart"
    "lib/core/di/injection_container.dart"
    "lib/core/theme/app_theme.dart"
    "lib/core/router/app_router.dart"
    "lib/core/error/error_handler.dart"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
        ((OK++))
    else
        echo -e "${RED}✗${NC} $file - FALTANDO"
        ((ERRORS++))
    fi
done

echo ""
echo "🔍 Verificando código depreciado..."

# WillPopScope (depreciado Flutter 3.12+)
if grep -r "WillPopScope" lib/ >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  WillPopScope depreciado encontrado"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Sem WillPopScope depreciado"
    ((OK++))
fi

# Old button styles
if grep -r "FlatButton\|RaisedButton\|OutlineButton" lib/ >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Botões depreciados encontrados (use TextButton, ElevatedButton, OutlinedButton)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Sem botões depreciados"
    ((OK++))
fi

echo ""
echo "📦 Verificando dependências..."

# Verificar pubspec.yaml
if grep -q "nearby_connections:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} nearby_connections"
    ((OK++))
else
    echo -e "${RED}✗${NC} nearby_connections - FALTANDO"
    ((ERRORS++))
fi

if grep -q "cryptography:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} cryptography"
    ((OK++))
else
    echo -e "${RED}✗${NC} cryptography - FALTANDO"
    ((ERRORS++))
fi

if grep -q "sqflite:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} sqflite"
    ((OK++))
else
    echo -e "${RED}✗${NC} sqflite - FALTANDO"
    ((ERRORS++))
fi

if grep -q "hive:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} hive"
    ((OK++))
else
    echo -e "${RED}✗${NC} hive - FALTANDO"
    ((ERRORS++))
fi

if grep -q "provider:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} provider"
    ((OK++))
else
    echo -e "${RED}✗${NC} provider - FALTANDO"
    ((ERRORS++))
fi

echo ""
echo "🔐 Verificando arquivos de segurança..."

if [ -f "lib/services/crypto_service.dart" ]; then
    echo -e "${GREEN}✓${NC} crypto_service.dart"
    ((OK++))
else
    echo -e "${RED}✗${NC} crypto_service.dart - FALTANDO"
    ((ERRORS++))
fi

if [ -f "lib/services/e2e_encryption.dart" ]; then
    echo -e "${GREEN}✓${NC} e2e_encryption.dart"
    ((OK++))
else
    echo -e "${YELLOW}⚠${NC}  e2e_encryption.dart - AUSENTE (opcional)"
    ((WARNINGS++))
fi

echo ""
echo "📊 Estatísticas do projeto..."
echo "────────────────────────────────"

FILE_COUNT=$(find lib -name "*.dart" -type f 2>/dev/null | wc -l)
LINE_COUNT=$(find lib -name "*.dart" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')

echo "Arquivos Dart: $FILE_COUNT"
echo "Linhas de código: $LINE_COUNT"

echo ""
echo "═══════════════════════════════"
echo "  RESULTADO FINAL"
echo "═══════════════════════════════"
echo -e "${GREEN}OK: $OK${NC}"
echo -e "${YELLOW}Avisos: $WARNINGS${NC}"
echo -e "${RED}Erros: $ERRORS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ PROJETO VALIDADO COM SUCESSO!${NC}"
    exit 0
else
    echo -e "${RED}❌ PROJETO COM ERROS - NECESSITA CORREÇÕES${NC}"
    exit 1
fi
