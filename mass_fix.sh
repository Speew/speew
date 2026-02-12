#!/bin/bash

echo "Iniciando correções em massa..."

# 1. REMOVER UNNECESSARY THIS (497 casos!)
find lib -name "*.dart" -type f -exec sed -i \
    -e 's/\([ (]\)this\.widget\./\1widget./g' \
    -e 's/\([ (]\)this\.context/\1context/g' \
    {} \;

# Mas manter this. necessário (em construtores, setters, etc)
# Não mexer em: required this., this.key, super(key: this.key)

echo "Removidos 'this.' desnecessários"

# 2. ADICIONAR CONST a widgets comuns
for file in $(find lib/ui -name "*.dart"); do
    # Text
    sed -i 's/\([^a-zA-Z]\)Text(/\1const Text(/g' "$file"
    sed -i '^Text(/const Text(/g' "$file"
    
    # Icon
    sed -i 's/\([^a-zA-Z]\)Icon(/\1const Icon(/g' "$file"
    
    # Center
    sed -i 's/\([^a-zA-Z]\)Center(/\1const Center(/g' "$file"
    
    # Remove duplicatas
    sed -i 's/const const /const /g' "$file"
done

echo "Adicionado const a widgets comuns"

# 3. VAR → FINAL
find lib -name "*.dart" -type f -exec sed -i \
    's/^\(\s*\)var \([a-zA-Z_][a-zA-Z0-9_]*\) =/\1final \2 =/g' \
    {} \;

echo "Convertido var → final"

# 4. PRINT → debugPrint
find lib -name "*.dart" -type f -exec sed -i \
    's/print(/debugPrint(/g' \
    {} \;

echo "Convertido print → debugPrint"

echo "Correções em massa concluídas!"

