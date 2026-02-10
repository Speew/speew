#!/bin/bash

echo "=== ANÁLISE COMPLETA DE ISSUES ==="
echo ""

# 1. IMPORTS NÃO USADOS
echo "1. IMPORTS NÃO USADOS:"
for file in $(find lib -name "*.dart"); do
    imports=$(grep "^import " "$file" | sed "s/.*['\"]//; s/['\"].*//; s/\.dart$//" | sed 's/.*\///')
    for imp in $imports; do
        if ! grep -q "$imp" <(grep -v "^import" "$file") 2>/dev/null; then
            echo "  $file: import '$imp' não usado"
        fi
    done
done | head -50

echo ""
echo "2. PREFER_CONST_CONSTRUCTORS:"
# SizedBox
grep -rn "^\s*SizedBox(" lib/ --include="*.dart" | grep -v "const SizedBox" | wc -l
echo "  SizedBox sem const: $(grep -rn 'SizedBox(' lib/ --include='*.dart' | grep -v 'const SizedBox' | wc -l)"

# Text
echo "  Text sem const: $(grep -rn 'Text(' lib/ --include='*.dart' | grep -v 'const Text\|TextButton\|TextField\|TextStyle\|TextEditingController\|RichText' | wc -l)"

# Icon
echo "  Icon sem const: $(grep -rn 'Icon(' lib/ --include='*.dart' | grep -v 'const Icon' | wc -l)"

# Padding
echo "  Padding sem const: $(grep -rn 'Padding(' lib/ --include='*.dart' | grep -v 'const Padding' | wc -l)"

# Container com apenas child
echo "  Container sem const: $(grep -rn 'Container(' lib/ --include='*.dart' | grep -v 'const Container' | wc -l)"

echo ""
echo "3. PREFER_CONST_LITERALS:"
echo "  EdgeInsets sem const: $(grep -rn 'EdgeInsets\.' lib/ --include='*.dart' | grep -v 'const EdgeInsets' | wc -l)"
echo "  BorderRadius sem const: $(grep -rn 'BorderRadius\.' lib/ --include='*.dart' | grep -v 'const BorderRadius' | wc -l)"

echo ""
echo "4. PREFER_FINAL_LOCALS:"
grep -rn "^\s*var " lib/ --include="*.dart" | wc -l
echo "  'var' que pode ser 'final': $(grep -rn '^\s*var ' lib/ --include='*.dart' | wc -l)"

echo ""
echo "5. UNNECESSARY_THIS:"
grep -rn "this\." lib/ --include="*.dart" | grep -v "super.initState\|super.dispose\|super.build\|super.key" | wc -l
echo "  'this.' desnecessário: $(grep -rn 'this\.' lib/ --include='*.dart' | grep -v 'required this\.|super\.' | wc -l)"

echo ""
echo "6. AVOID_PRINT:"
grep -rn "print(" lib/ --include="*.dart" | grep -v "// \|debugPrint" | wc -l
echo "  print() usado: $(grep -rn 'print(' lib/ --include='*.dart' | grep -v '// \|debugPrint\|Fingerprint' | wc -l)"

echo ""
echo "7. PREFER_SINGLE_QUOTES:"
grep -rn '"[^"]*"' lib/ --include="*.dart" | grep -v "import\|part of\|//" | wc -l
echo "  Strings com aspas duplas: $(grep -rn '\"[^\"]*\"' lib/ --include='*.dart' | grep -v 'import\|part of\|//' | wc -l)"

echo ""
echo "8. UNUSED_LOCAL_VARIABLE:"
echo "  (análise manual necessária)"

echo ""
echo "9. PREFER_IS_EMPTY:"
grep -rn "\.length == 0\|\.length > 0" lib/ --include="*.dart" | wc -l
echo "  .length == 0: $(grep -rn '\.length == 0' lib/ --include='*.dart' | wc -l)"
echo "  .length > 0: $(grep -rn '\.length > 0' lib/ --include='*.dart' | wc -l)"

echo ""
echo "10. TIPO INFERENCE:"
grep -rn "List<.*> \w\+ = \[\]" lib/ --include="*.dart" | wc -l
echo "  Tipo explícito desnecessário: $(grep -rn 'List<.*> \w\+ = \[\]' lib/ --include='*.dart' | wc -l)"

