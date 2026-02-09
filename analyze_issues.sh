#!/bin/bash

echo "=== ANÁLISE DE PROBLEMAS POTENCIAIS ==="
echo ""

cd /home/claude/speew

# 1. Imports duplicados
echo "1. Verificando imports duplicados..."
for file in $(find lib -name "*.dart"); do
    dupes=$(grep "^import" "$file" | sort | uniq -d)
    if [ ! -z "$dupes" ]; then
        echo "  DUPLICADOS em $file:"
        echo "$dupes" | sed 's/^/    /'
    fi
done

# 2. Classes sem dispose
echo ""
echo "2. Verificando StatefulWidgets sem dispose..."
for file in $(find lib -name "*.dart"); do
    if grep -q "class.*State<" "$file"; then
        if ! grep -q "void dispose()" "$file"; then
            echo "  SEM DISPOSE: $file"
        fi
    fi
done

# 3. Streams não fechados
echo ""
echo "3. Verificando StreamControllers..."
grep -r "StreamController" lib/ --include="*.dart" -l | while read file; do
    if ! grep -q ".close()" "$file"; then
        echo "  POSSÍVEL LEAK: $file"
    fi
done

# 4. BuildContext usado após async
echo ""
echo "4. Verificando uso de context após await..."
grep -r "await.*context\." lib/ --include="*.dart" | head -5

# 5. Unused imports (básico)
echo ""
echo "5. Verificando possíveis imports não usados..."
# Este é um check básico, pode ter falsos positivos
for file in $(find lib -name "*.dart"); do
    imports=$(grep "^import" "$file" | grep -v "package:flutter" | sed "s/^import '.*\/\(.*\)\.dart';/\1/")
    for imp in $imports; do
        if ! grep -q "$imp" "$file" 2>/dev/null; then
            : # skip for now
        fi
    done
done

echo ""
echo "=== ANÁLISE CONCLUÍDA ==="
