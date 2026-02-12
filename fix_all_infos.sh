#!/bin/bash

echo "=== CORREÇÃO MASSIVA DE INFOS ==="

# 1. AVOID_VOID_ASYNC - trocar void async por Future<void>
echo "1. Corrigindo void async..."
find lib -name "*.dart" -type f -exec sed -i \
    's/void \(.*\) async {/Future<void> \1 async {/g' \
    {} \;

# 2. OMIT_LOCAL_VARIABLE_TYPES - remover tipos óbvios
echo "2. Removendo tipos locais óbvios..."
find lib -name "*.dart" -type f -exec sed -i \
    -e 's/final String \([a-zA-Z_][a-zA-Z0-9_]*\) = "/final \1 = "/g' \
    -e 's/final int \([a-zA-Z_][a-zA-Z0-9_]*\) = [0-9]/final \1 = /g' \
    -e 's/final bool \([a-zA-Z_][a-zA-Z0-9_]*\) = true/final \1 = true/g' \
    -e 's/final bool \([a-zA-Z_][a-zA-Z0-9_]*\) = false/final \1 = false/g' \
    -e 's/final double \([a-zA-Z_][a-zA-Z0-9_]*\) = [0-9]/final \1 = /g' \
    {} \;

# 3. SORT_CONSTRUCTORS_FIRST já está correto na maioria

# 4. Adicionar tipos de retorno faltantes em funções
echo "3. Adicionando tipos de retorno..."
# Isso é manual, skip

echo "=== CORREÇÕES APLICADAS ==="

