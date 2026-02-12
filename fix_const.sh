#!/bin/bash
# Fix common const issues

for file in $(find lib -name "*.dart"); do
    # Fix SizedBox without const
    sed -i 's/\([^a-zA-Z]\)SizedBox(height:/\1const SizedBox(height:/g' "$file"
    sed -i 's/\([^a-zA-Z]\)SizedBox(width:/\1const SizedBox(width:/g' "$file"
    sed -i 's/^SizedBox(height:/const SizedBox(height:/g' "$file"
    sed -i 's/^SizedBox(width:/const SizedBox(width:/g' "$file"
    
    # Fix Divider without const
    sed -i 's/\([^a-zA-Z]\)Divider()/\1const Divider()/g' "$file"
    
    # Remove duplicate const
    sed -i 's/const const /const /g' "$file"
done

echo "Fixed const issues"
