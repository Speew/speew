#!/bin/bash

echo "=== ANÁLISE PROFUNDA ==="

echo "Total de linhas: $(find lib -name '*.dart' -exec wc -l {} \; | awk '{sum+=$1} END {print sum}')"
echo "Total de arquivos: $(find lib -name '*.dart' | wc -l)"

echo ""
echo "=== PADRÕES PROBLEMÁTICOS ==="

# Widgets que podem ser const
for widget in "SizedBox" "Divider" "Spacer" "Icon" "Text" "Padding" "Center" "Align" "Column" "Row"; do
    count=$(grep -rn "$widget(" lib/ --include="*.dart" | grep -v "const $widget\|${widget}Button\|${widget}Field\|${widget}Style\|${widget}Controller\|Rich${widget}" | wc -l)
    echo "$widget sem const: $count"
done

echo ""
echo "=== LITERAIS QUE PODEM SER CONST ==="
echo "Duration: $(grep -rn 'Duration(' lib/ --include='*.dart' | grep -v 'const Duration' | wc -l)"
echo "TextStyle: $(grep -rn 'TextStyle(' lib/ --include='*.dart' | grep -v 'const TextStyle' | wc -l)"
echo "BoxDecoration: $(grep -rn 'BoxDecoration(' lib/ --include='*.dart' | grep -v 'const BoxDecoration' | wc -l)"

echo ""
echo "=== PROBLEMAS POTENCIAIS ==="
echo "Campos não final: $(grep -rn '^\s*[A-Z].*\s\+_[a-z].*=' lib/ --include='*.dart' | grep -v 'final\|const\|static' | wc -l)"
echo "Métodos muito longos (>50 linhas): $(awk '/^\s*(void|Future|Stream|bool|int|String|double).*{/{start=NR} /^}$/{if(NR-start>50)print FILENAME":"start}' lib/**/*.dart 2>/dev/null | wc -l)"

